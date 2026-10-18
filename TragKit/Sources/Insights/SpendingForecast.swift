import Foundation
import StatementParsing

/// Expected spending for the month after the latest data: known recurring payments plus the average of everything else.
public struct SpendingForecast: Sendable, Hashable {
    public let month: Month
    public let recurring: Decimal
    public let variable: Decimal
    /// How many past months the variable part averages.
    public let basedOnMonths: Int

    public var total: Decimal { recurring + variable }

    /// - Parameter lookback: number of most recent months used for the average (fewer if not available).
    public init?(
        transactions: [BankTransaction], recurringPayments: [RecurringPayment], lookback: Int = 3, calendar: Calendar = .current
    ) {
        let byMonth = transactions.filter(\.isExpense).groupedByMonth(calendar: calendar)
        let recent = byMonth.keys.sorted(by: >).prefix(lookback)
        guard let latest = recent.first else { return nil }

        let recurringKeys = Set(recurringPayments.map(\.merchantKey))
        let variableTotals = recent.map { month in
            byMonth[month, default: []]
                .filter { !recurringKeys.contains(MerchantKey.normalize($0.counterparty)) }
                .reduce(Decimal.zero) { $0 - $1.amount }
        }
        // Only payments seen in the latest month or the one before are still expected.
        let active = recurringPayments.filter { $0.months.contains(latest) || $0.months.contains(latest.previous()) }

        month = latest.next()
        recurring = active.reduce(0) { $0 + $1.monthlyAmount }
        variable = (variableTotals.reduce(0, +) / Decimal(variableTotals.count)).rounded(scale: 2)
        basedOnMonths = variableTotals.count
    }
}

/// Total spending per month, oldest first, for trend charts.
public struct MonthlySpending: Sendable, Hashable, Identifiable {
    public var id: Month { month }
    public let month: Month
    public let spent: Decimal

    public static func history(_ transactions: [BankTransaction], calendar: Calendar = .current) -> [MonthlySpending] {
        transactions.filter(\.isExpense).groupedByMonth(calendar: calendar)
            .map { MonthlySpending(month: $0.key, spent: $0.value.reduce(0) { $0 - $1.amount }) }
            .sorted { $0.month < $1.month }
    }
}

extension Decimal {
    /// Rounded to `scale` decimal places, half up.
    public func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
