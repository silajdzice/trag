import Foundation
import Insights
import StatementParsing
import SwiftData

/// All reads and writes of saved data. Views and feature models never touch `ModelContext` directly.
final class TransactionStore {
    struct ImportResult: Hashable {
        let inserted: Int
        let alreadyImported: Int
    }

    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([StoredTransaction.self, CategoryOverride.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory))
    }

    func save(_ statement: ParsedStatement) throws -> ImportResult {
        let existing = Set(try context.fetch(FetchDescriptor<StoredTransaction>()).map(\.uid))
        var inserted = 0
        for transaction in statement.transactions
        where !existing.contains(StoredTransaction.uid(bankName: statement.bankName, transactionID: transaction.id)) {
            context.insert(StoredTransaction(transaction, bankName: statement.bankName))
            inserted += 1
        }
        try context.save()
        return ImportResult(inserted: inserted, alreadyImported: statement.transactions.count - inserted)
    }

    func transactions() throws -> [BankTransaction] {
        let descriptor = FetchDescriptor<StoredTransaction>(sortBy: [SortDescriptor(\.bookingDate, order: .reverse)])
        return try context.fetch(descriptor).map(\.bankTransaction)
    }

    func categoryOverrides() throws -> [String: SpendingCategory] {
        try context.fetch(FetchDescriptor<CategoryOverride>()).reduce(into: [:]) { result, override in
            result[override.merchantKey] = SpendingCategory(rawValue: override.categoryRawValue)
        }
    }

    func setCategory(_ category: SpendingCategory, forMerchant merchantKey: String) throws {
        let descriptor = FetchDescriptor<CategoryOverride>(predicate: #Predicate { $0.merchantKey == merchantKey })
        if let override = try context.fetch(descriptor).first {
            override.categoryRawValue = category.rawValue
        } else {
            context.insert(CategoryOverride(merchantKey: merchantKey, categoryRawValue: category.rawValue))
        }
        try context.save()
    }
}
