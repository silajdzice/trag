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
        for candidate in [key, String(key.dropLast()), String(key.dropLast(2))] where candidate.count >= 3 {
            let matching = pool.filter { MerchantKey.normalize($0.counterparty).contains(candidate) }
            if !matching.isEmpty { return SpendingSummary(transactions: matching).byMerchant }
        }
        return []
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

    static func month(_ month: Month) -> String {
        String(format: "%04d-%02d", month.year, month.month)
    }
}
