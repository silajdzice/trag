import Foundation
import FoundationModels
import Insights

/// What the user asked, filled in by the model with grammar-constrained output. It contains no amounts.
/// Fields are ordered so the model reads out the month, category and shop before deciding the kind of question.
@Generable(description: "What the user wants to know about their spending")
struct QueryIntent {
    @Generable
    enum Kind {
        case monthSummary
        case categoryTotal
        case merchantTotal
        case subscriptions
        case forecast
        case unknown
    }

    // Every field is required: with constrained decoding, models tend to skip optional fields entirely.
    @Guide(description: "Month as YYYY-MM if the user names or implies a month, otherwise the word latest")
    var month: String
    @Guide(description: "Spending category the user asks about (groceries, pets, eatingOut...), or other if none")
    var category: AICategory
    @Guide(description: "Shop or company name the user asks about (Konzum, Bingo, Telemach...), or an empty string if none")
    var merchant: String
    @Guide(
        description: """
            categoryTotal: spending in a category. merchantTotal: spending at a shop or company. \
            monthSummary: total spending or overview of a month. subscriptions: subscriptions or monthly bills. \
            forecast: expected spending next month. unknown: anything else.
            """)
    var kind: Kind

    init(kind: Kind, category: AICategory = .other, merchant: String = "", month: String = "latest") {
        self.kind = kind
        self.category = category
        self.merchant = merchant
        self.month = month
    }

    var hasMerchant: Bool { !merchant.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Drops a shop name the user never wrote. Models sometimes copy names from the prompt's examples
    /// ("Konzum" for a question about eating out). Bosnian case endings are allowed: "Konzumu" mentions "Konzum".
    func verified(against question: String) -> QueryIntent {
        guard hasMerchant else { return self }
        let questionKey = MerchantKey.normalize(question)
        let merchantKey = MerchantKey.normalize(merchant)
        let stem = String(merchantKey.prefix(max(3, merchantKey.count - 2)))
        var copy = self
        if !questionKey.contains(stem) { copy.merchant = "" }
        return copy
    }

    /// The kind to answer, from the details the model filled in rather than its label alone.
    /// Call on a `verified(against:)` intent, so a shop name is known to come from the question.
    /// - A shop the user named means spending at that shop (except a forecast).
    /// - A category means spending in that category, whatever general kind the model chose.
    /// - "Spending at a shop" with no shop left falls back to the category, or is not understood. Never a guess.
    var resolvedKind: Kind {
        if hasMerchant, kind != .forecast { return .merchantTotal }
        switch kind {
        case .monthSummary, .unknown, .merchantTotal:
            if category != .other { return .categoryTotal }
            return kind == .merchantTotal ? .unknown : kind
        default:
            return kind
        }
    }
}

/// An answer computed entirely in Swift from a `QueryIntent`. The app turns it into a localized sentence.
public enum ComputedAnswer: Sendable, Equatable {
    case monthSummary(month: Month, spent: Decimal, income: Decimal, topCategory: SpendingCategory?, currency: String)
    case categoryTotal(category: SpendingCategory, month: Month, total: Decimal, count: Int, currency: String)
    case merchantTotal(merchant: String, month: Month?, total: Decimal, count: Int, currency: String)
    case merchantNotFound(String)
    case subscriptions(names: [String], monthlyTotal: Decimal, currency: String)
    case forecast(month: Month, total: Decimal, currency: String)
    case notUnderstood
}

enum IntentAnswerer {
    static func answer(_ intent: QueryIntent, to question: String, queries: SpendingQueries) -> ComputedAnswer {
        answer(intent.verified(against: question), queries: queries)
    }

    static func answer(_ intent: QueryIntent, queries: SpendingQueries) -> ComputedAnswer {
        let currency = queries.currency
        switch intent.resolvedKind {
        case .monthSummary:
            guard let month = queries.resolveMonth(intent.month) else { return .notUnderstood }
            let summary = queries.summary(for: month)
            return .monthSummary(
                month: month, spent: summary.totalSpent, income: summary.totalIncome,
                topCategory: summary.byCategory.first?.key, currency: currency)
        case .categoryTotal:
            guard intent.category != .other, let month = queries.resolveMonth(intent.month) else { return .notUnderstood }
            let category = intent.category.spendingCategory
            let result = queries.spending(in: category, month: month)
            return .categoryTotal(category: category, month: month, total: result.total, count: result.count, currency: currency)
        case .merchantTotal:
            guard intent.hasMerchant else { return .notUnderstood }
            let merchant = intent.merchant.trimmingCharacters(in: .whitespaces)
            // A shop question without a month covers all imported months.
            let month = intent.month.firstMatch(of: /\d{4}-\d{1,2}/) == nil ? nil : queries.resolveMonth(intent.month)
            let lines = queries.spending(atMerchant: merchant, month: month)
            guard !lines.isEmpty else { return .merchantNotFound(merchant) }
            return .merchantTotal(
                merchant: lines.count == 1 ? lines[0].key : merchant, month: month,
                total: lines.reduce(0) { $0 + $1.total }, count: lines.reduce(0) { $0 + $1.count }, currency: currency)
        case .subscriptions:
            let payments = queries.recurringPayments
            return .subscriptions(
                names: payments.map(\.name), monthlyTotal: payments.reduce(0) { $0 + $1.monthlyAmount }, currency: currency)
        case .forecast:
            guard let forecast = queries.forecast else { return .notUnderstood }
            return .forecast(month: forecast.month, total: forecast.total, currency: currency)
        case .unknown:
            return .notUnderstood
        }
    }
}
