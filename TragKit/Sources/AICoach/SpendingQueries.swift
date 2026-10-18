import Foundation
import Insights
import StatementParsing

/// Exact answers about the user's spending. This is the only way the model sees data:
/// every number it may mention is produced here, in plain Swift.
public struct SpendingQueries: Sendable {
    public let transactions: [BankTransaction]
    public let categorizer: RuleBasedCategorizer
    public let calendar: Calendar
    private let byMonth: [Month: [BankTransaction]]

    public init(transactions: [BankTransaction], categorizer: RuleBasedCategorizer, calendar: Calendar = .current) {
        self.transactions = transactions
        self.categorizer = categorizer
        self.calendar = calendar
        byMonth = transactions.groupedByMonth(calendar: calendar)
    }

    /// Newest first.
    public var months: [Month] { byMonth.keys.sorted(by: >) }

    public var currency: String { transactions.first?.currency ?? "BAM" }

    /// Accepts "2026-09" or "2026-9"; nil or unknown text means the latest month with data.
    public func resolveMonth(_ text: String?) -> Month? {
        if let text, let match = text.firstMatch(of: /(\d{4})-(\d{1,2})/),
            let year = Int(match.output.1), let month = Int(match.output.2), (1...12).contains(month)
        {
            return Month(year: year, month: month)
        }
        return months.first
    }

    public func summary(for month: Month) -> SpendingSummary {
        SpendingSummary(transactions: byMonth[month] ?? [], categorizer: categorizer)
    }

    public func spending(in category: SpendingCategory, month: Month) -> (total: Decimal, count: Int) {
        let matching = (byMonth[month] ?? []).filter { $0.isExpense && categorizer.category(for: $0) == category }
        return (matching.reduce(0) { $0 - $1.amount }, matching.count)
    }

    /// Spending at merchants whose name contains `query` (case and diacritics insensitive). Nil month means all months.
    /// Bosnian changes word endings ("u Bingu", "Konzumu"), so if nothing matches, up to two final letters are dropped.
    public func spending(atMerchant query: String, month: Month?) -> [SpendingSummary.Line<String>] {
        let key = MerchantKey.normalize(query)
        guard !key.isEmpty else { return [] }
        let pool = month.map { byMonth[$0] ?? [] } ?? transactions
        guard let match = matchingMerchantKey(key, in: pool) else { return [] }
        return SpendingSummary(transactions: pool.filter { MerchantKey.normalize($0.counterparty).contains(match) }).byMerchant
    }

    /// Individual payments (newest first) matching every given filter; nil filters match everything.
    public func expenses(category: SpendingCategory? = nil, merchant: String? = nil, month: Month? = nil) -> [BankTransaction] {
        var pool = month.map { byMonth[$0] ?? [] } ?? transactions
        pool = pool.filter(\.isExpense)
        if let category {
            pool = pool.filter { categorizer.category(for: $0) == category }
        }
        if let merchant, let key = matchingMerchantKey(merchant, in: pool) {
            pool = pool.filter { MerchantKey.normalize($0.counterparty).contains(key) }
        } else if merchant != nil {
            return []
        }
        return pool.sorted { $0.bookingDate > $1.bookingDate }
    }

    /// The form of `query` (full, or without one or two Bosnian case-ending letters) that matches a merchant in `pool`.
    private func matchingMerchantKey(_ query: String, in pool: [BankTransaction]) -> String? {
        let key = MerchantKey.normalize(query)
        guard !key.isEmpty else { return nil }
        return [key, String(key.dropLast()), String(key.dropLast(2))].first { candidate in
            candidate.count >= 3 && pool.contains { MerchantKey.normalize($0.counterparty).contains(candidate) }
        }
    }

    public var recurringPayments: [RecurringPayment] {
        RecurringPaymentDetector.detect(in: transactions, categorizer: categorizer, calendar: calendar)
    }

    public var forecast: SpendingForecast? {
        SpendingForecast(transactions: transactions, recurringPayments: recurringPayments, calendar: calendar)
    }
}

/// Fixed, locale-independent amount text for the model: "1234.56 BAM". The grounding check parses the same format.
enum AmountText {
    static func format(_ amount: Decimal, _ currency: String) -> String {
        "\(amount.rounded(scale: 2).formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))) \(currency)"
    }

    /// "2026-09-12"
    static func day(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    static func month(_ month: Month) -> String {
        String(format: "%04d-%02d", month.year, month.month)
    }
}
