import Foundation
import FoundationModels
import Insights
import Synchronization

/// Everything the tools returned in a conversation, so answers can be checked against it.
final class ToolLog: Sendable {
    private let outputs = Mutex<[String]>([])

    func record(_ output: String) -> String {
        outputs.withLock { $0.append(output) }
        return output
    }

    var all: [String] { outputs.withLock { $0 } }
}

struct CategorySpendingTool: Tool {
    let name = "spendingByCategory"
    let description = "Exact total the user spent in one category during one month."
    let queries: SpendingQueries
    let log: ToolLog

    @Generable
    struct Arguments {
        var category: AICategory
        @Guide(description: "Month as YYYY-MM, for example 2026-09. Leave empty for the latest month.")
        var month: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let month = queries.resolveMonth(arguments.month) else { return log.record("No data.") }
        let result = queries.spending(in: arguments.category.spendingCategory, month: month)
        return log.record(
            "\(arguments.category.rawValue) in \(AmountText.month(month)): "
                + "\(AmountText.format(result.total, queries.currency)) across \(result.count) transactions.")
    }
}

struct MerchantSpendingTool: Tool {
    let name = "spendingAtMerchant"
    let description = "Exact spending at shops or companies whose name contains the given text."
    let queries: SpendingQueries
    let log: ToolLog

    @Generable
    struct Arguments {
        @Guide(description: "Part of the merchant name, for example Konzum or Telemach")
        var merchant: String
        @Guide(description: "Month as YYYY-MM. Leave empty for all months.")
        var month: String?
    }

    func call(arguments: Arguments) async throws -> String {
        let month = arguments.month.flatMap { queries.resolveMonth($0) }
        let lines = queries.spending(atMerchant: arguments.merchant, month: month).prefix(5)
        guard !lines.isEmpty else { return log.record("No spending found at \(arguments.merchant).") }
        let period = month.map { "in \(AmountText.month($0))" } ?? "in all imported months"
        return log.record(
            lines.map { "\($0.key) \(period): \(AmountText.format($0.total, queries.currency)) (\($0.count) payments)" }
                .joined(separator: "\n"))
    }
}

struct MonthSummaryTool: Tool {
    let name = "monthSummary"
    let description = "Total spent, income and the biggest categories and places for one month."
    let queries: SpendingQueries
    let log: ToolLog

    @Generable
    struct Arguments {
        @Guide(description: "Month as YYYY-MM. Leave empty for the latest month.")
        var month: String?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let month = queries.resolveMonth(arguments.month) else { return log.record("No data.") }
        let summary = queries.summary(for: month)
        let currency = queries.currency
        let categories = summary.byCategory.prefix(5).map { "\($0.key.rawValue) \(AmountText.format($0.total, currency))" }
        let places = summary.byMerchant.prefix(3).map { "\($0.key) \(AmountText.format($0.total, currency))" }
        return log.record(
            """
            Month \(AmountText.month(month)): spent \(AmountText.format(summary.totalSpent, currency)), \
            income \(AmountText.format(summary.totalIncome, currency)), bank fees \(AmountText.format(summary.fees, currency)).
            Biggest categories: \(categories.joined(separator: ", ")).
            Biggest places: \(places.joined(separator: ", ")).
            Months with data: \(queries.months.map(AmountText.month).joined(separator: ", ")).
            """)
    }
}

struct RecurringPaymentsTool: Tool {
    let name = "subscriptionsAndBills"
    let description = "Subscriptions and bills the user pays every month, with typical amounts."
    let queries: SpendingQueries
    let log: ToolLog

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let payments = queries.recurringPayments
        guard !payments.isEmpty else { return log.record("No recurring payments found yet.") }
        let total = payments.reduce(Decimal.zero) { $0 + $1.monthlyAmount }
        let lines = payments.map { "\($0.name) (\($0.kind.rawValue)): \(AmountText.format($0.monthlyAmount, $0.currency))" }
        return log.record(
            (lines + ["Total per month: \(AmountText.format(total, queries.currency))"]).joined(separator: "\n"))
    }
}

struct ForecastTool: Tool {
    let name = "nextMonthEstimate"
    let description = "Estimated spending for next month, based on recurring payments and recent months."
    let queries: SpendingQueries
    let log: ToolLog

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        guard let forecast = queries.forecast else { return log.record("Not enough data for an estimate.") }
        let currency = queries.currency
        return log.record(
            """
            Estimate for \(AmountText.month(forecast.month)): \(AmountText.format(forecast.total, currency)) \
            (subscriptions and bills \(AmountText.format(forecast.recurring, currency)), \
            everything else \(AmountText.format(forecast.variable, currency)), based on \(forecast.basedOnMonths) months).
            """)
    }
}
