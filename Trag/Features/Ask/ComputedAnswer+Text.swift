import AICoach
import Foundation
import Insights

extension ComputedAnswer {
    /// A sentence in the user's language for an answer Swift computed. No model writes these words.
    var localizedText: String {
        switch self {
        case .monthSummary(let month, let spent, let income, let topCategory, let currency):
            let summary = String(
                localized:
                    "\(month.displayName): you spent \(spent.moneyFormatted(currency: currency)) and received \(income.moneyFormatted(currency: currency))."
            )
            guard let topCategory else { return summary }
            return summary + " " + String(localized: "Biggest category: \(String(localized: topCategory.title)).")
        case .categoryTotal(let category, let month, let total, let count, let currency):
            return String(
                localized: "\(String(localized: category.title)) in \(month.displayName): \(total.moneyFormatted(currency: currency))")
                + " · " + String(localized: "\(count) payments")
        case .merchantTotal(let merchant, let month, let total, let count, let currency):
            let amount = total.moneyFormatted(currency: currency)
            let headline =
                month.map { String(localized: "\(merchant) in \($0.displayName): \(amount)") }
                ?? String(localized: "\(merchant), all imported months: \(amount)")
            return headline + " · " + String(localized: "\(count) payments")
        case .merchantNotFound(let merchant):
            return String(localized: "I couldn't find any payments to “\(merchant)”.")
        case .subscriptions(let names, let total, let currency):
            guard !names.isEmpty else { return String(localized: "No recurring payments yet") }
            return String(
                localized:
                    "You pay \(total.moneyFormatted(currency: currency)) a month for subscriptions and bills: \(names.formatted(.list(type: .and)))."
            )
        case .forecast(let month, let total, let currency):
            return String(localized: "Expected spending in \(month.displayName): about \(total.moneyFormatted(currency: currency)).")
        case .transactionList(let category, let merchant, let month, _, let count, let total, let currency):
            guard count > 0 else { return String(localized: "No payments match.") }
            let subject = [category.map { String(localized: $0.title) }, merchant].compactMap { $0 }.joined(separator: ", ")
            let period = month?.displayName ?? String(localized: "all imported months")
            let headline =
                subject.isEmpty
                ? String(localized: "Payments in \(period): \(total.moneyFormatted(currency: currency))")
                : String(localized: "\(subject) in \(period): \(total.moneyFormatted(currency: currency))")
            return headline + " · " + String(localized: "\(count) payments")
        case .notUnderstood:
            return String(localized: "I couldn't understand that question. Try asking about a category, a shop or a month.")
        }
    }
}

extension Month {
    /// "September 2026" / "septembar 2026."
    var displayName: String { startDate().formatted(.dateTime.month(.wide).year()) }
}
