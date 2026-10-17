import Foundation

/// A single movement on a bank account, normalised across banks.
public struct BankTransaction: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case cardPurchase
        case cashWithdrawal
        case billPayment
        case transfer
        case income
        case fee
        case other
    }

    public let id: String
    public let bookingDate: Date
    public let valueDate: Date?
    /// Negative for money out, positive for money in. In the statement currency.
    public let amount: Decimal
    public let currency: String
    public let kind: Kind
    /// Best guess at who was paid or who paid (merchant, company, person).
    public let counterparty: String
    public let description: String
    /// Original amount for foreign-currency card payments, e.g. 12.99 EUR.
    public let originalAmount: Money?
    /// Bank reference shared by a payment and its fee rows.
    public let reference: String

    public init(
        id: String,
        bookingDate: Date,
        valueDate: Date?,
        amount: Decimal,
        currency: String,
        kind: Kind,
        counterparty: String,
        description: String,
        originalAmount: Money? = nil,
        reference: String
    ) {
        self.id = id
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.amount = amount
        self.currency = currency
        self.kind = kind
        self.counterparty = counterparty
        self.description = description
        self.originalAmount = originalAmount
        self.reference = reference
    }

    public var isExpense: Bool { amount < 0 }
}

public struct Money: Sendable, Hashable, Codable {
    public let amount: Decimal
    public let currency: String

    public init(amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency
    }
}

public struct ParsedStatement: Sendable {
    public let bankName: String
    public let currency: String
    public let periodStart: Date?
    public let periodEnd: Date?
    public let openingBalance: Decimal?
    public let closingBalance: Decimal?
    public let transactions: [BankTransaction]
    /// Totals printed on the statement, used to validate the parse.
    public let reportedTotals: (debit: Decimal, credit: Decimal)?

    public init(
        bankName: String,
        currency: String,
        periodStart: Date?,
        periodEnd: Date?,
        openingBalance: Decimal?,
        closingBalance: Decimal?,
        transactions: [BankTransaction],
        reportedTotals: (debit: Decimal, credit: Decimal)?
    ) {
        self.bankName = bankName
        self.currency = currency
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
        self.transactions = transactions
        self.reportedTotals = reportedTotals
    }

    public var totalDebit: Decimal { transactions.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount } }
    public var totalCredit: Decimal { transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }

    /// True when our parsed sums match the totals printed on the statement.
    public var matchesReportedTotals: Bool {
        guard let reportedTotals else { return false }
        return reportedTotals.debit == totalDebit && reportedTotals.credit == totalCredit
    }
}

public enum StatementParsingError: Error, Equatable {
    case unreadableDocument
    case unsupportedBank
    case noTransactionsFound
}
