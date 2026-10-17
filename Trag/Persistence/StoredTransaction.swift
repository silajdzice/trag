import Foundation
import StatementParsing
import SwiftData

/// A transaction saved on the device. Mirrors `BankTransaction`; conversion lives here so the package stays storage-free.
@Model
final class StoredTransaction {
    /// Bank name + bank-assigned id, so re-importing a statement never creates duplicates.
    @Attribute(.unique) var uid: String
    var bankName: String
    var bankTransactionID: String
    var bookingDate: Date
    var valueDate: Date?
    var amount: Decimal
    var currency: String
    var kindRawValue: String
    var counterparty: String
    var details: String
    var originalAmount: Decimal?
    var originalCurrency: String?
    var reference: String

    init(_ transaction: BankTransaction, bankName: String) {
        uid = Self.uid(bankName: bankName, transactionID: transaction.id)
        self.bankName = bankName
        bankTransactionID = transaction.id
        bookingDate = transaction.bookingDate
        valueDate = transaction.valueDate
        amount = transaction.amount
        currency = transaction.currency
        kindRawValue = transaction.kind.rawValue
        counterparty = transaction.counterparty
        details = transaction.description
        originalAmount = transaction.originalAmount?.amount
        originalCurrency = transaction.originalAmount?.currency
        reference = transaction.reference
    }

    static func uid(bankName: String, transactionID: String) -> String {
        "\(bankName)|\(transactionID)"
    }

    var bankTransaction: BankTransaction {
        BankTransaction(
            id: uid,
            bookingDate: bookingDate,
            valueDate: valueDate,
            amount: amount,
            currency: currency,
            kind: BankTransaction.Kind(rawValue: kindRawValue) ?? .other,
            counterparty: counterparty,
            description: details,
            originalAmount: originalAmount.flatMap { amount in originalCurrency.map { Money(amount: amount, currency: $0) } },
            reference: reference
        )
    }
}

/// The user's own category for a merchant. Applies to all of that merchant's transactions.
@Model
final class CategoryOverride {
    @Attribute(.unique) var merchantKey: String
    var categoryRawValue: String

    init(merchantKey: String, categoryRawValue: String) {
        self.merchantKey = merchantKey
        self.categoryRawValue = categoryRawValue
    }
}
