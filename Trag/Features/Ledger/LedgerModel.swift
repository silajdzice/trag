import AICoach
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
    /// Spending in the month before the selected one, for comparison.
    private(set) var previousMonthSpent: Decimal?
    private(set) var history: [MonthlySpending] = []
    private(set) var recurringPayments: [RecurringPayment] = []
    private(set) var forecast: SpendingForecast?
    private(set) var tips: [Month: [SavingTip]] = [:]
    private(set) var isLoadingTips = false
    /// True while the on-device model is categorising unknown merchants.
    private(set) var isSuggestingCategories = false
    /// Exact data access for the AI features.
    private(set) var queries = SpendingQueries(transactions: [], categorizer: RuleBasedCategorizer())
    private(set) var categorizer = RuleBasedCategorizer()
    private(set) var loadError: String?

    private let store: TransactionStore
    private var suggester: (any CategorySuggesting)?
    private var tipsGenerator: SavingTipsGenerator?
    private var byMonth: [Month: [BankTransaction]] = [:]
    private var allTransactions: [BankTransaction] = []
    private var askedMerchants: Set<String> = []

    /// - Parameters:
    ///   - suggester: the on-device model for categories, or nil where it isn't available.
    ///   - tipsGenerator: the on-device model for saving tips, or nil where it isn't available.
    init(store: TransactionStore, suggester: (any CategorySuggesting)? = nil, tipsGenerator: SavingTipsGenerator? = nil) {
        self.store = store
        self.suggester = suggester
        self.tipsGenerator = tipsGenerator
    }

    var canGenerateTips: Bool { tipsGenerator != nil }

    /// Switches the AI engine for categories and tips (nil turns AI off). Cached tips came from the old engine.
    func useEngine(_ engine: AIEngine?) {
        suggester = engine.map { CategorySuggester(engine: $0) }
        tipsGenerator = engine.map { SavingTipsGenerator(engine: $0) }
        tips = [:]
    }

    func loadTips(for month: Month) async {
        guard let tipsGenerator, !isLoadingTips else { return }
        isLoadingTips = true
        defer { isLoadingTips = false }
        do {
            tips[month] = try await tipsGenerator.tips(for: month, queries: queries)
        } catch {
            Log.ai.error("Tips failed: \(String(describing: error), privacy: .public)")
            tips[month] = []
        }
    }

    var isEmpty: Bool { months.isEmpty }

    func reload() {
        do {
            let suggestions = try store.categorySuggestions()
            askedMerchants = Set(suggestions.keys)
            categorizer = RuleBasedCategorizer(overrides: try store.categoryOverrides(), suggestions: suggestions)
            let transactions = try store.transactions()
            allTransactions = transactions
            queries = SpendingQueries(transactions: transactions, categorizer: categorizer)
            tips = [:]
            byMonth = transactions.groupedByMonth()
            months = byMonth.keys.sorted(by: >)
            history = MonthlySpending.history(transactions)
            recurringPayments = RecurringPaymentDetector.detect(in: transactions, categorizer: categorizer)
            forecast = SpendingForecast(transactions: transactions, recurringPayments: recurringPayments)
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

    func categorySource(for transaction: BankTransaction) -> CategorySource {
        categorizer.categorization(for: transaction).source
    }

    /// Asks the on-device model about merchants nothing else recognised. Each merchant is asked once, ever.
    func suggestCategories() async {
        guard let suggester, !isSuggestingCategories else { return }
        let unknown = Set(
            allTransactions
                .filter { canChangeCategory(of: $0) && categorizer.categorization(for: $0).source == .none }
                .map(\.counterparty)
        )
        .filter { !askedMerchants.contains(MerchantKey.normalize($0)) }
        guard !unknown.isEmpty else { return }

        isSuggestingCategories = true
        defer { isSuggestingCategories = false }
        do {
            let suggestions = try await suggester.suggest(for: unknown.sorted())
            try store.saveSuggestions(suggestions)
            Log.ai.info("Model suggested categories for \(suggestions.count) merchants")
            reload()
        } catch {
            Log.ai.error("Category suggestions failed: \(String(describing: error), privacy: .public)")
        }
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

    /// Change in spending against the previous month, e.g. 0.12 for 12% more. Nil without a previous month.
    var changeFromPreviousMonth: Double? {
        guard let previous = previousMonthSpent, previous > 0, let spent = summary?.totalSpent else { return nil }
        return ((spent - previous) / previous).doubleValue
    }

    var recurringMonthlyTotal: Decimal {
        recurringPayments.reduce(0) { $0 + $1.monthlyAmount }
    }

    private func updateSelection() {
        monthTransactions = selectedMonth.flatMap { byMonth[$0] } ?? []
        summary = selectedMonth == nil ? nil : SpendingSummary(transactions: monthTransactions, categorizer: categorizer)
        previousMonthSpent = selectedMonth.flatMap { month in history.first { $0.month == month.previous() }?.spent }
    }
}
