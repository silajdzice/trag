import Foundation
import FoundationModels
import OSLog

/// "Ask your money" on any engine. Two strategies, one guarantee: amounts shown to the user come from Swift.
@MainActor
public final class MoneyChat {
    public enum Reply: Equatable, Sendable {
        /// Model-written text whose amounts all came from tool output (tool-calling strategy).
        case answer(String)
        /// An answer Swift computed from the model's understanding of the question (structured-intent strategy).
        case computed(ComputedAnswer)
        /// The model mentioned an amount it didn't get from the data.
        case notGrounded
        case failed(String)
    }

    public let engine: AIEngine
    public let strategy: ChatStrategy
    private let queries: SpendingQueries
    private let log = ToolLog()
    private var session: LanguageModelSession
    private static let logger = Logger(subsystem: "dev.edhem.trag", category: "ai")

    public init(queries: SpendingQueries, engine: AIEngine, strategy: ChatStrategy? = nil) {
        self.queries = queries
        self.engine = engine
        self.strategy = strategy ?? engine.recommendedChatStrategy
        session = Self.makeSession(queries: queries, engine: engine, strategy: self.strategy, log: log)
    }

    public func ask(_ question: String) async -> Reply {
        do {
            return try await answer(question)
        } catch LanguageModelError.contextSizeExceeded {
            // Long conversation: start fresh and try once more.
            session = Self.makeSession(queries: queries, engine: engine, strategy: strategy, log: log)
            do {
                return try await answer(question)
            } catch {
                return .failed(String(describing: error))
            }
        } catch {
            Self.logger.error("Chat failed: \(String(describing: error), privacy: .public)")
            return .failed(String(describing: error))
        }
    }

    private func answer(_ question: String) async throws -> Reply {
        switch strategy {
        case .structuredIntent:
            // Each question stands alone, so the small context of open models never fills up.
            let intent = try await session.respond(to: question, generating: QueryIntent.self).content
            return .computed(IntentAnswerer.answer(intent, queries: queries))
        case .toolCalling:
            let text = Self.removingReasoning(try await session.respond(to: question).content)
            let ungrounded = GroundingCheck.ungroundedAmounts(in: text, sources: log.all + [question])
            guard ungrounded.isEmpty else {
                Self.logger.notice("Withheld an answer with \(ungrounded.count) ungrounded amounts")
                return .notGrounded
            }
            return .answer(text)
        }
    }

    /// Reasoning models may prefix answers with a <think>…</think> trace; users only see the answer.
    static func removingReasoning(_ text: String) -> String {
        text.replacing(/<think>[\s\S]*?<\/think>/, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeSession(
        queries: SpendingQueries, engine: AIEngine, strategy: ChatStrategy, log: ToolLog
    ) -> LanguageModelSession {
        let months = queries.months.map(AmountText.month).joined(separator: ", ")
        let latest = queries.months.first.map(AmountText.month) ?? "none"
        let context = """
            Months with data: \(months). The latest month is \(latest); "this month" or "ovaj mjesec" means the latest month, \
            "last month" or "prošli mjesec" the one before it. Currency: \(queries.currency) (KM).
            Category words: namirnice = groceries, hrana vani/restorani = eatingOut, režije = utilities, ljubimci = pets, \
            djeca = kids, zdravlje = health, zabava = entertainment, pretplate = subscriptions, prevoz/gorivo = transport, \
            kupovina = shopping.
            """
        switch strategy {
        case .structuredIntent:
            return engine.session(
                instructions: """
                    Work out what the user wants to know about their own bank spending. The user may write in Bosnian, \
                    Croatian, Serbian or English. Fill in the request; never answer it yourself.
                    \(context)
                    Examples:
                    "How much did I spend on groceries in 2026-09?" → month 2026-09, category groceries, kind categoryTotal
                    "Koliko sam potrošio na ljubimce?" → category pets, kind categoryTotal
                    "Koliko plaćam Telemach?" → merchant Telemach, kind merchantTotal
                    "Koliko sam potrošio u Konzumu u augustu?" → month of August, merchant Konzum, kind merchantTotal
                    "Koliko sam ukupno potrošio prošli mjesec?" → the month before the latest, kind monthSummary
                    "Koje pretplate imam?" → kind subscriptions
                    """)
        case .toolCalling:
            let tools: [any Tool] = [
                MonthSummaryTool(queries: queries, log: log),
                CategorySpendingTool(queries: queries, log: log),
                MerchantSpendingTool(queries: queries, log: log),
                RecurringPaymentsTool(queries: queries, log: log),
                ForecastTool(queries: queries, log: log),
            ]
            return engine.session(
                tools: tools,
                instructions: """
                    You answer questions about the user's own bank spending in a privacy-first budgeting app. \
                    The user may write in Bosnian, Croatian, Serbian or English; understand the question and always reply in English.
                    Rules:
                    - Every amount you mention must come from a tool result in this conversation. Call a tool before answering.
                    - Quote amounts exactly as the tool returned them. Never round, add, estimate or invent numbers.
                    - If no tool can answer, say you don't know. Keep answers to two or three sentences.
                    \(context)
                    """)
        }
    }
}
