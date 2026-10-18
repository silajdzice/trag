import Foundation
import StatementParsing

/// A payment that repeats every month: a subscription paid by card, or a bill.
public struct RecurringPayment: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        case subscription
        case bill
    }

    public var id: String { merchantKey }
    public let merchantKey: String
    /// Name as it appeared on the latest charge.
    public let name: String
    public let kind: Kind
    /// Typical monthly amount, positive, in the account currency.
    public let monthlyAmount: Decimal
    public let currency: String
    /// Price in the merchant's currency when charged abroad (e.g. 8.49 USD).
    public let originalAmount: Money?
    public let months: [Month]
    public let lastCharged: Date
    public let nextExpected: Date
}

public enum RecurringPaymentDetector {
    /// Everyday spending that repeats by habit, not by contract (a toll road, a bakery), is never a subscription.
    static let everydayCategories: Set<SpendingCategory> = [.groceries, .eatingOut, .transport, .shopping, .kids, .pets]

    /// Finds merchants charged in at least `minimumMonths` months, at most twice a month, with no gap longer than one month.
    /// Card payments must also have a stable price (same foreign price, or within 15% in the account currency)
    /// and not be everyday spending; bills may vary, because utility amounts follow usage.
    public static func detect(
        in transactions: [BankTransaction], minimumMonths: Int = 2,
        categorizer: some TransactionCategorizer = RuleBasedCategorizer(), calendar: Calendar = .current
    ) -> [RecurringPayment] {
        let candidates = transactions.filter { transaction in
            guard transaction.isExpense else { return false }
            switch transaction.kind {
            case .billPayment: return true
            case .cardPurchase: return !everydayCategories.contains(categorizer.category(for: transaction))
            default: return false
            }
        }
        let byMerchant = Dictionary(grouping: candidates) { MerchantKey.normalize($0.counterparty) }

        return byMerchant.compactMap { key, charges -> RecurringPayment? in
            let byMonth = charges.groupedByMonth(calendar: calendar)
            let months = byMonth.keys.sorted()
            guard months.count >= minimumMonths,
                byMonth.values.allSatisfy({ $0.count <= 2 }),
                zip(months, months.dropFirst()).allSatisfy({ $1.previous() == $0 || $1.previous().previous() == $0 })
            else { return nil }

            let isBill = charges.allSatisfy { $0.kind == .billPayment }
            guard isBill || hasStablePrice(charges),
                let latest = charges.max(by: { $0.bookingDate < $1.bookingDate })
            else { return nil }

            let monthlyTotals = months.map { month in byMonth[month, default: []].reduce(Decimal.zero) { $0 - $1.amount } }
            return RecurringPayment(
                merchantKey: key,
                name: latest.counterparty,
                kind: isBill ? .bill : .subscription,
                monthlyAmount: median(monthlyTotals),
                currency: latest.currency,
                originalAmount: latest.originalAmount,
                months: months,
                lastCharged: latest.bookingDate,
                nextExpected: calendar.date(byAdding: .month, value: 1, to: latest.bookingDate) ?? latest.bookingDate
            )
        }
        .sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    static func hasStablePrice(_ charges: [BankTransaction]) -> Bool {
        let originals = charges.compactMap(\.originalAmount)
        if originals.count == charges.count {
            return Set(originals).count == 1
        }
        let amounts = charges.map { -$0.amount }
        guard let low = amounts.min(), let high = amounts.max(), low > 0 else { return false }
        return high / low <= Decimal(string: "1.15")!
    }

    static func median(_ values: [Decimal]) -> Decimal {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
