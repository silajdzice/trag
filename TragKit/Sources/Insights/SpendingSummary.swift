import Foundation
import StatementParsing

/// Plain-Swift numbers about spending. The AI layer only ever reads these, it never does math itself.
public struct SpendingSummary: Sendable {
    public struct Line: Sendable, Hashable, Identifiable {
        public var id: String { name }
        public let name: String
        public let total: Decimal
        public let count: Int
    }

    public let totalSpent: Decimal
    public let totalIncome: Decimal
    public let byCounterparty: [Line]
    public let byKind: [BankTransaction.Kind: Decimal]
    public let fees: Decimal

    public init(transactions: [BankTransaction]) {
        let expenses = transactions.filter(\.isExpense)
        totalSpent = expenses.reduce(0) { $0 - $1.amount }
        totalIncome = transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
        byCounterparty = Dictionary(grouping: expenses, by: \.counterparty)
            .map { Line(name: $0.key, total: $0.value.reduce(0) { $0 - $1.amount }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
        byKind = Dictionary(grouping: expenses, by: \.kind).mapValues { $0.reduce(0) { $0 - $1.amount } }
        fees = byKind[.fee] ?? 0
    }
}
