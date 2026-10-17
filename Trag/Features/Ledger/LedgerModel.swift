import Foundation
import Insights
import Observation
import StatementParsing

/// Saved transactions, the selected month and everything the overview shows for it.
@Observable
final class LedgerModel {
    private(set) var months: [Month] = []
    var selectedMonth: Month? {
        didSet { updateSelection() }
    }
    private(set) var summary: SpendingSummary?
    private(set) var monthTransactions: [BankTransaction] = []
    private(set) var categorizer = RuleBasedCategorizer()
    private(set) var loadError: String?

    private let store: TransactionStore
    private var byMonth: [Month: [BankTransaction]] = [:]

    init(store: TransactionStore) {
        self.store = store
    }

    var isEmpty: Bool { months.isEmpty }

    func reload() {
        do {
            categorizer = RuleBasedCategorizer(overrides: try store.categoryOverrides())
            byMonth = try store.transactions().groupedByMonth()
            months = byMonth.keys.sorted(by: >)
            loadError = nil
        } catch {
            Log.storage.error("Loading transactions failed: \(String(describing: error), privacy: .public)")
            loadError = String(localized: "Couldn't load your saved transactions.")
        }
        if let selectedMonth, months.contains(selectedMonth) {
            updateSelection()
        } else {
            selectedMonth = months.first
        }
    }

    func category(for transaction: BankTransaction) -> SpendingCategory {
        categorizer.category(for: transaction)
    }

    /// Cash, fees and income are categorised by transaction type, so only purchases and bills can be changed.
    func canChangeCategory(of transaction: BankTransaction) -> Bool {
        transaction.isExpense && ![.fee, .cashWithdrawal].contains(transaction.kind)
    }

    /// Remembers the user's choice for this merchant and re-categorises everything from it.
    func setCategory(_ category: SpendingCategory, for transaction: BankTransaction) {
        do {
            try store.setCategory(category, forMerchant: MerchantKey.normalize(transaction.counterparty))
            reload()
        } catch {
            Log.storage.error("Saving category failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func updateSelection() {
        monthTransactions = selectedMonth.flatMap { byMonth[$0] } ?? []
        summary = selectedMonth == nil ? nil : SpendingSummary(transactions: monthTransactions, categorizer: categorizer)
    }
}
