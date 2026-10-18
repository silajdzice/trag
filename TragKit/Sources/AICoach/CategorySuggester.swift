import Foundation
import FoundationModels
import Insights

/// Something that can suggest categories for merchant names (the on-device model, or a stub in tests).
public protocol CategorySuggesting: Sendable {
    /// Keyed by `MerchantKey.normalize(name)`. `.other` means "unsure".
    func suggest(for merchants: [String]) async throws -> [String: SpendingCategory]
}

/// Suggests categories for merchants the rules don't recognise. Suggestions never override the user.
public struct CategorySuggester: CategorySuggesting {
    @Generable
    struct Suggestion {
        @Guide(description: "The best category, or other if unsure")
        var category: AICategory
    }

    public let engine: AIEngine

    public init(engine: AIEngine) {
        self.engine = engine
    }

    /// Returns a suggestion for every merchant, keyed by `MerchantKey.normalize(name)`; `.other` when the model is unsure,
    /// so callers can remember that it was already asked.
    public func suggest(for merchants: [String]) async throws -> [String: SpendingCategory] {
        var result: [String: SpendingCategory] = [:]
        for merchant in merchants {
            // A fresh session per merchant keeps answers independent and the context small.
            let session = engine.session(
                instructions: """
                    You categorise card payments from bank statements in Bosnia and Herzegovina. \
                    Merchant names are uppercase and often cut short; D.O.O./DOO means a company, PJ a branch, \
                    SA/SAR/SARAJEV the city Sarajevo. Choose one category:
                    \(AICategory.promptGuide)
                    """)
            let suggestion = try await session.respond(
                to: "Merchant: \(merchant)", generating: Suggestion.self, options: GenerationOptions(samplingMode: .greedy)
            ).content
            result[MerchantKey.normalize(merchant)] = suggestion.category.spendingCategory
        }
        return result
    }
}
