import Foundation
import FoundationModels
import OSLog

/// "Ask your money": a conversation where the model can only learn numbers through Trag's tools,
/// and any answer containing an amount the tools didn't return is withheld.
@MainActor
public final class MoneyChat {
    public enum Reply: Equatable, Sendable {
        case answer(String)
        /// The model mentioned an amount it didn't get from the data.
        case notGrounded
        case failed(String)
    }

    private let queries: SpendingQueries
    private let log = ToolLog()
    private var session: LanguageModelSession
    private static let logger = Logger(subsystem: "dev.edhem.trag", category: "ai")

    public init(queries: SpendingQueries) {
        self.queries = queries
        session = Self.makeSession(queries: queries, log: log)
    }

    public func ask(_ question: String) async -> Reply {
        do {
            return try await answer(question)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Long conversation: start fresh and try once more.
            session = Self.makeSession(queries: queries, log: log)
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
        let text = try await session.respond(to: question).content
        let ungrounded = GroundingCheck.ungroundedAmounts(in: text, sources: log.all + [question])
        guard ungrounded.isEmpty else {
            Self.logger.notice("Withheld an answer with \(ungrounded.count) ungrounded amounts")
            return .notGrounded
        }
        return .answer(text)
    }

    private static func makeSession(queries: SpendingQueries, log: ToolLog) -> LanguageModelSession {
        let tools: [any Tool] = [
            MonthSummaryTool(queries: queries, log: log),
            CategorySpendingTool(queries: queries, log: log),
            MerchantSpendingTool(queries: queries, log: log),
            RecurringPaymentsTool(queries: queries, log: log),
            ForecastTool(queries: queries, log: log),
        ]
        let months = queries.months.map(AmountText.month).joined(separator: ", ")
        return LanguageModelSession(
            tools: tools,
            instructions: """
                You answer questions about the user's own bank spending in a privacy-first budgeting app. \
                The user may write in Bosnian, Croatian, Serbian or English; understand the question and always reply in English.
                Rules:
                - Every amount you mention must come from a tool result in this conversation. Call a tool before answering.
                - Quote amounts exactly as the tool returned them. Never round, add, estimate or invent numbers.
                - If no tool can answer, say you don't know. Keep answers to two or three sentences.
                Months with data: \(months). The latest month is \(queries.months.first.map(AmountText.month) ?? "none"); \
                "this month" or "ovaj mjesec" means the latest month, "last month" or "prošli mjesec" the one before it. \
                Currency: \(queries.currency) (KM).
                Category words: namirnice = groceries, hrana vani/restorani = eatingOut, režije = utilities, \
                ljubimci = pets, djeca = kids, zdravlje = health, zabava = entertainment, pretplate = subscriptions, \
                prevoz/gorivo = transport, kupovina = shopping.
                """)
    }
}
