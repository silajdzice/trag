import Foundation
import Insights
import StatementParsing

/// Scored checks of the AI features on synthetic data. Runs in tests on a Mac and in the app's AI lab on a phone,
/// so every engine and strategy is measured the same way.
public enum EvalSuite {
    public struct TaskResult: Sendable, Identifiable {
        public var id: String { name }
        public let name: String
        public let passed: Int
        public let total: Int
        public let averageSeconds: Double
        public let failures: [String]

        public var score: Double { total == 0 ? 0 : Double(passed) / Double(total) }
    }

    public struct Report: Sendable {
        public let engine: AIEngine
        public let strategy: ChatStrategy
        public let tasks: [TaskResult]
    }

    struct ChatCase {
        let question: String
        let expected: Decimal
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo") ?? .current
        return calendar
    }()

    private static func tx(_ amount: Decimal, _ who: String, _ month: Int, _ kind: BankTransaction.Kind = .cardPurchase)
        -> BankTransaction
    {
        BankTransaction(
            id: UUID().uuidString,
            bookingDate: calendar.date(from: DateComponents(year: 2026, month: month, day: 12, hour: 12)) ?? .distantPast,
            valueDate: nil, amount: amount, currency: "BAM", kind: kind, counterparty: who, description: "", reference: "r")
    }

    /// Two realistic months of fake data.
    public static let queries = SpendingQueries(
        transactions: [
            tx(-120.40, "BINGO D.O.O. TUZLA", 8), tx(-80.00, "VETERINARSKA STANICA", 8),
            tx(-67.45, "TELEMACH DOO", 8, .billPayment),
            tx(-250.10, "BINGO D.O.O. TUZLA", 9), tx(-35.00, "PIZZERIA MASLINA", 9), tx(-135.00, "VETERINARSKA STANICA", 9),
            tx(-67.45, "TELEMACH DOO", 9, .billPayment), tx(-66.00, "CINEPLEXX BH", 9), tx(2000, "ACME DOO", 9, .income),
        ],
        categorizer: RuleBasedCategorizer(), calendar: calendar)

    static let categoryCases: [(String, SpendingCategory)] = [
        ("LJEKARNA CENTAR MOSTAR", .health), ("PIZZERIA NAPOLI", .eatingOut), ("VETERINARSKA AMBULANTA", .pets),
        ("PETROL BENZINSKA PUMPA", .transport), ("IGRAONICA BALONI", .kids), ("FRIZERSKI SALON LANA", .personalCare),
        ("ELEKTRO SHOP DOO", .shopping), ("RESTORAN ZELJO", .eatingOut), ("AUTOBUSNA STANICA SARAJEVO", .transport),
        ("APOTEKA PHARMAMED", .health),
    ]

    static let chatCases: [ChatCase] = [
        ChatCase(question: "How much did I spend on groceries in 2026-09?", expected: Decimal(string: "250.10")!),
        ChatCase(question: "Koliko sam potrošio na ljubimce u septembru 2026?", expected: 135),
        ChatCase(question: "How much do I pay Telemach in 2026-09?", expected: Decimal(string: "67.45")!),
        ChatCase(question: "Koliko sam ukupno potrošio u augustu 2026?", expected: Decimal(string: "267.85")!),
        ChatCase(question: "Koliko sam potrošio u Bingu u augustu 2026?", expected: Decimal(string: "120.40")!),
        ChatCase(question: "What did I spend on eating out this month?", expected: 35),
    ]

    @MainActor
    public static func run(
        engine: AIEngine, strategy: ChatStrategy, onProgress: @MainActor (String) -> Void = { _ in }
    ) async -> Report {
        var tasks: [TaskResult] = []

        onProgress("Categories")
        tasks.append(await categories(engine: engine))

        onProgress("Chat")
        tasks.append(await chat(engine: engine, strategy: strategy))

        onProgress("Tips")
        tasks.append(await tips(engine: engine))

        return Report(engine: engine, strategy: strategy, tasks: tasks)
    }

    static func categories(engine: AIEngine) async -> TaskResult {
        let start = ContinuousClock.now
        let suggestions = (try? await CategorySuggester(engine: engine).suggest(for: categoryCases.map(\.0))) ?? [:]
        let failures = categoryCases.compactMap { merchant, expected -> String? in
            let got = suggestions[MerchantKey.normalize(merchant)]
            return got == expected ? nil : "\(merchant): expected \(expected.rawValue), got \(got?.rawValue ?? "nothing")"
        }
        return TaskResult(
            name: "Categories", passed: categoryCases.count - failures.count, total: categoryCases.count,
            averageSeconds: seconds(since: start) / Double(categoryCases.count), failures: failures)
    }

    @MainActor
    static func chat(engine: AIEngine, strategy: ChatStrategy) async -> TaskResult {
        let start = ContinuousClock.now
        var failures: [String] = []
        for item in chatCases {
            // A fresh chat per question, so one mistake doesn't leak into the next case.
            let reply = await MoneyChat(queries: queries, engine: engine, strategy: strategy).ask(item.question)
            if !matches(reply, expected: item.expected) { failures.append("\(item.question) → \(reply)") }
        }
        return TaskResult(
            name: "Chat (\(strategy.rawValue))", passed: chatCases.count - failures.count, total: chatCases.count,
            averageSeconds: seconds(since: start) / Double(chatCases.count), failures: failures)
    }

    static func tips(engine: AIEngine) async -> TaskResult {
        let start = ContinuousClock.now
        let tips = (try? await SavingTipsGenerator(engine: engine).tips(for: Month(year: 2026, month: 9), queries: queries)) ?? []
        // Tips are filtered by the grounding check, so every tip returned is grounded; we want all three to survive.
        return TaskResult(
            name: "Tips", passed: tips.count, total: 3, averageSeconds: seconds(since: start),
            failures: tips.count < 3 ? ["\(3 - tips.count) tips dropped or missing"] : [])
    }

    static func matches(_ reply: MoneyChat.Reply, expected: Decimal) -> Bool {
        switch reply {
        case .answer(let text):
            return GroundingCheck.amounts(in: text).contains(expected)
        case .computed(let answer):
            switch answer {
            case .categoryTotal(_, _, let total, _, _), .merchantTotal(_, _, let total, _, _):
                return total == expected
            case .monthSummary(_, let spent, _, _, _):
                return spent == expected
            case .forecast(_, let total, _):
                return total == expected
            case .subscriptions(_, let total, _):
                return total == expected
            case .merchantNotFound, .notUnderstood:
                return false
            }
        case .notGrounded, .failed:
            return false
        }
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }
}
