import Foundation
import FoundationModels
import Insights

@Generable
public struct SavingTip: Sendable, Hashable {
    @Guide(description: "Short title, at most six words")
    public var title: String
    @Guide(description: "One or two friendly sentences. Use only amounts from the facts, quoted exactly.")
    public var detail: String
}

/// Three practical saving tips for a month, phrased by the model from numbers Trag computed.
public struct SavingTipsGenerator: Sendable {
    @Generable
    struct Tips {
        @Guide(description: "Three different, specific tips", .count(3))
        var tips: [SavingTip]
    }

    public let engine: AIEngine

    public init(engine: AIEngine) {
        self.engine = engine
    }

    public func tips(for month: Month, queries: SpendingQueries) async throws -> [SavingTip] {
        let facts = Self.facts(for: month, queries: queries)
        let session = engine.session(
            instructions: """
                You are a kind, practical money coach. Below are facts and signals about the user's spending, \
                computed by the app. Write three tips for next month. Reply in English.
                Rules:
                - Each tip recommends one concrete action the user can take (for example: pay by card instead of \
                withdrawing cash to avoid ATM fees, plan one big grocery trip a week, cancel an unused subscription, \
                set a monthly limit for a category).
                - Base each tip on a different signal. Never suggest cutting a category that went down.
                - Mention amounts only if they appear in the facts, exactly as written.
                - Don't judge the user. Don't suggest loans, credit or investments.
                """)
        let tips = try await session.respond(to: facts, generating: Tips.self).content.tips
        // Drop any tip that mentions an amount the facts don't contain.
        return tips.filter { GroundingCheck.ungroundedAmounts(in: "\($0.title) \($0.detail)", sources: [facts]).isEmpty }
    }

    /// The numbers and signals the model may use, all computed in Swift.
    static func facts(for month: Month, queries: SpendingQueries) -> String {
        let currency = queries.currency
        let summary = queries.summary(for: month)
        let previous = queries.summary(for: month.previous())
        let transactions = queries.transactions.filter { Month(containing: $0.bookingDate, calendar: queries.calendar) == month }
        func money(_ amount: Decimal) -> String { AmountText.format(amount, currency) }

        var lines = ["FACTS for \(AmountText.month(month)):", "Total spent: \(money(summary.totalSpent))."]
        if previous.totalSpent > 0 { lines.append("Total spent the month before: \(money(previous.totalSpent)).") }
        for line in summary.byCategory.prefix(6) {
            lines.append("\(line.key.rawValue): \(money(line.total)) in \(line.count) payments.")
        }

        var signals: [String] = []
        for line in summary.byCategory where line.key != .fees {
            guard let before = previous.byCategory.first(where: { $0.key == line.key }), before.total > 0,
                line.total > before.total * Decimal(string: "1.15")!
            else { continue }
            signals.append("\(line.key.rawValue) went up: \(money(line.total)) vs \(money(before.total)) the month before.")
        }
        if let frequent = summary.byMerchant.first(where: { $0.count >= 8 }) {
            signals.append(
                "Many small purchases: \(frequent.count) payments at \(frequent.key), \(money(frequent.total)) in total.")
        }
        let withdrawals = transactions.filter { $0.kind == .cashWithdrawal }
        if !withdrawals.isEmpty {
            signals.append(
                "Cash withdrawals: \(withdrawals.count), \(money(withdrawals.reduce(0) { $0 - $1.amount })) in total; "
                    + "the app can't see what cash was spent on.")
        }
        if summary.fees > 0 {
            let feeCount = transactions.filter { $0.kind == .fee }.count
            signals.append("Bank fees: \(money(summary.fees)) in \(feeCount) separate charges.")
        }
        let foreign = transactions.filter { $0.originalAmount != nil }
        if !foreign.isEmpty {
            signals.append("Card payments in foreign currency: \(foreign.count); each adds a currency conversion fee.")
        }
        let recurring = queries.recurringPayments.filter { $0.kind == .subscription }
        if !recurring.isEmpty {
            signals.append(
                "Subscriptions: "
                    + recurring.map { "\($0.name) \(AmountText.format($0.monthlyAmount, $0.currency))" }.joined(separator: ", ")
                    + ".")
        }
        if !signals.isEmpty { lines += ["SIGNALS:"] + signals }
        return lines.joined(separator: "\n")
    }
}
