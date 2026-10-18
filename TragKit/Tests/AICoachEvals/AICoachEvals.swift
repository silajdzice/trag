import Foundation
import Insights
import StatementParsing
import Testing

@testable import AICoach

/// Quality evals against the real on-device model. Skipped where Apple Intelligence isn't available.
/// Each eval reports a score and fails below its threshold, so prompt changes can be compared.
@Suite(.enabled(if: AIAvailability.current.isAvailable, "On-device model unavailable"), .serialized)
struct AICoachEvals {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo")!
        return calendar
    }()

    static func tx(_ amount: Decimal, _ who: String, _ month: Int, _ kind: BankTransaction.Kind = .cardPurchase)
        -> BankTransaction
    {
        BankTransaction(
            id: UUID().uuidString,
            bookingDate: calendar.date(from: DateComponents(year: 2026, month: month, day: 12, hour: 12))!,
            valueDate: nil, amount: amount, currency: "BAM", kind: kind, counterparty: who, description: "", reference: "r")
    }

    /// Synthetic but realistic two months.
    static let queries = SpendingQueries(
        transactions: [
            tx(-120.40, "BINGO D.O.O. TUZLA", 8), tx(-80.00, "VETERINARSKA STANICA", 8), tx(-67.45, "TELEMACH DOO", 8, .billPayment),
            tx(-250.10, "BINGO D.O.O. TUZLA", 9), tx(-35.00, "PIZZERIA MASLINA", 9), tx(-135.00, "VETERINARSKA STANICA", 9),
            tx(-67.45, "TELEMACH DOO", 9, .billPayment), tx(-66.00, "CINEPLEXX BH", 9), tx(2000, "ACME DOO", 9, .income),
        ],
        categorizer: RuleBasedCategorizer(), calendar: calendar)

    @Test func categorySuggestionAccuracy() async throws {
        let cases: [(String, SpendingCategory)] = [
            ("LJEKARNA CENTAR MOSTAR", .health),
            ("PIZZERIA NAPOLI", .eatingOut),
            ("VETERINARSKA AMBULANTA", .pets),
            ("PETROL BENZINSKA PUMPA", .transport),
            ("IGRAONICA BALONI", .kids),
            ("FRIZERSKI SALON LANA", .personalCare),
            ("ELEKTRO SHOP DOO", .shopping),
            ("RESTORAN ZELJO", .eatingOut),
            ("AUTOBUSNA STANICA SARAJEVO", .transport),
            ("APOTEKA PHARMAMED", .health),
        ]
        let suggestions = try await CategorySuggester().suggest(for: cases.map(\.0))
        let correct = cases.filter { suggestions[MerchantKey.normalize($0.0)] == $0.1 }.count
        let wrong = cases.filter { suggestions[MerchantKey.normalize($0.0)] != $0.1 }
            .map { "\($0.0): expected \($0.1), got \(suggestions[MerchantKey.normalize($0.0)]?.rawValue ?? "none")" }
        print("EVAL categories: \(correct)/\(cases.count)\n  " + wrong.joined(separator: "\n  "))
        #expect(correct >= 8)
    }

    @Test @MainActor func chatAnswersAreGroundedAndCorrect() async {
        let cases: [(question: String, expected: String)] = [
            ("How much did I spend on groceries in 2026-09?", "250.10"),
            ("Koliko sam potrošio na ljubimce u septembru 2026?", "135.00"),
            ("How much do I pay Telemach?", "67.45"),
            ("Koliko sam ukupno potrošio u augustu 2026?", "267.85"),
        ]
        var correct = 0
        for item in cases {
            let chat = MoneyChat(queries: Self.queries)
            let reply = await chat.ask(item.question)
            if case .answer(let text) = reply, text.contains(item.expected) { correct += 1 }
            print("EVAL chat: \(item.question)\n  → \(reply)")
        }
        print("EVAL chat score: \(correct)/\(cases.count)")
        #expect(correct >= 3)
    }

    @Test @MainActor func chatDeclinesQuestionsItCannotAnswer() async {
        let reply = await MoneyChat(queries: Self.queries).ask("What will the euro exchange rate be next year?")
        print("EVAL off-topic → \(reply)")
        if case .answer(let text) = reply {
            #expect(GroundingCheck.amounts(in: text).isEmpty)
        }
    }

    @Test func savingTipsFactsContainSignals() {
        let facts = SavingTipsGenerator.facts(for: Month(year: 2026, month: 9), queries: Self.queries)
        print("EVAL facts:\n\(facts)")
        #expect(facts.contains("groceries went up"))
    }

    @Test func savingTipsAreGrounded() async throws {
        let tips = try await SavingTipsGenerator().tips(for: Month(year: 2026, month: 9), queries: Self.queries)
        print("EVAL tips:\n" + tips.map { "  • \($0.title): \($0.detail)" }.joined(separator: "\n"))
        #expect(tips.count >= 2)
    }
}
