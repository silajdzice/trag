import Foundation
import StatementParsing

/// Plain-Swift numbers about spending. The AI layer only ever reads these, it never does math itself.
public struct SpendingSummary: Sendable {
    public struct Line<Key: Hashable & Sendable>: Sendable, Hashable, Identifiable {
        public var id: Key { key }
        public let key: Key
        public let total: Decimal
        public let count: Int
    }

    public let totalSpent: Decimal
    public let totalIncome: Decimal
    public let fees: Decimal
    public let byCategory: [Line<SpendingCategory>]
    public let byMerchant: [Line<String>]

    public init(transactions: [BankTransaction], categorizer: some TransactionCategorizer = RuleBasedCategorizer()) {
        let expenses = transactions.filter(\.isExpense)
        totalSpent = expenses.reduce(0) { $0 - $1.amount }
        totalIncome = transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
        fees = expenses.filter { $0.kind == .fee }.reduce(0) { $0 - $1.amount }
        byCategory = Self.lines(expenses) { categorizer.category(for: $0) }
        byMerchant = Self.lines(expenses.filter { $0.kind != .fee && $0.kind != .cashWithdrawal }) { $0.counterparty }
    }

    /// Share of total spending, 0...1.
    public func share(of line: Line<SpendingCategory>) -> Double {
        guard totalSpent > 0 else { return 0 }
        return NSDecimalNumber(decimal: line.total / totalSpent).doubleValue
    }

    private static func lines<Key>(_ expenses: [BankTransaction], by key: (BankTransaction) -> Key) -> [Line<Key>] {
        Dictionary(grouping: expenses, by: key)
            .map { Line(key: $0.key, total: $0.value.reduce(0) { $0 - $1.amount }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
    }
}
