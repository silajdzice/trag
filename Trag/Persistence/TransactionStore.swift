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

    /// The user's own choices.
    func categoryOverrides() throws -> [String: SpendingCategory] {
        try categories(from: .user)
    }

    /// On-device model suggestions, including `.other` for merchants it was unsure about.
    func categorySuggestions() throws -> [String: SpendingCategory] {
        try categories(from: .ai)
    }

    func setCategory(_ category: SpendingCategory, forMerchant merchantKey: String) throws {
        if let existing = try override(for: merchantKey) {
            existing.categoryRawValue = category.rawValue
            existing.sourceRawValue = CategoryOverride.Source.user.rawValue
        } else {
            context.insert(CategoryOverride(merchantKey: merchantKey, categoryRawValue: category.rawValue, source: .user))
        }
        try context.save()
    }

    /// Saves model suggestions without ever replacing a choice the user made.
    func saveSuggestions(_ suggestions: [String: SpendingCategory]) throws {
        for (merchantKey, category) in suggestions {
            if let existing = try override(for: merchantKey) {
                guard existing.source == .ai else { continue }
                existing.categoryRawValue = category.rawValue
            } else {
                context.insert(CategoryOverride(merchantKey: merchantKey, categoryRawValue: category.rawValue, source: .ai))
            }
        }
        try context.save()
    }

    private func override(for merchantKey: String) throws -> CategoryOverride? {
        try context.fetch(FetchDescriptor<CategoryOverride>(predicate: #Predicate { $0.merchantKey == merchantKey })).first
    }

    private func categories(from source: CategoryOverride.Source) throws -> [String: SpendingCategory] {
        let raw = source.rawValue
        let descriptor = FetchDescriptor<CategoryOverride>(predicate: #Predicate { $0.sourceRawValue == raw })
        return try context.fetch(descriptor).reduce(into: [:]) { result, override in
            result[override.merchantKey] = SpendingCategory(rawValue: override.categoryRawValue)
        }
    }
}
