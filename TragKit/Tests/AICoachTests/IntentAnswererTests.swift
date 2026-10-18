import Foundation
import Insights
import Testing

@testable import AICoach

@Suite struct IntentAnswererTests {
    let queries = EvalSuite.queries
    let september = Month(year: 2026, month: 9)

    @Test func categoryTotalIsComputedInSwift() {
        let intent = QueryIntent(kind: .categoryTotal, category: .groceries, month: "2026-09")
        #expect(
            IntentAnswerer.answer(intent, queries: queries)
                == .categoryTotal(category: .groceries, month: september, total: Decimal(string: "250.10")!, count: 1, currency: "BAM"))
    }

    @Test func missingMonthMeansLatest() {
        let intent = QueryIntent(kind: .categoryTotal, category: .pets)
        #expect(
            IntentAnswerer.answer(intent, queries: queries)
                == .categoryTotal(category: .pets, month: september, total: 135, count: 1, currency: "BAM"))
    }

    @Test func merchantAcrossAllMonths() {
        let intent = QueryIntent(kind: .merchantTotal, merchant: "telemach")
        guard case .merchantTotal(let name, let month, let total, let count, _) = IntentAnswerer.answer(intent, queries: queries)
        else {
            Issue.record("expected a merchant total")
            return
        }
        #expect(name == "TELEMACH DOO")
        #expect(month == nil)
        #expect(total == Decimal(string: "134.90"))
        #expect(count == 2)
    }

    @Test func unknownMerchantIsReported() {
        let intent = QueryIntent(kind: .merchantTotal, merchant: "Zara")
        #expect(IntentAnswerer.answer(intent, queries: queries) == .merchantNotFound("Zara"))
    }

    @Test func monthSummary() {
        let intent = QueryIntent(kind: .monthSummary, month: "2026-08")
        #expect(
            IntentAnswerer.answer(intent, queries: queries)
                == .monthSummary(
                    month: Month(year: 2026, month: 8), spent: Decimal(string: "267.85")!, income: 0,
                    topCategory: .groceries, currency: "BAM"))
    }

    @Test func unknownAndIncompleteIntentsAreNotGuessed() {
        #expect(
            IntentAnswerer.answer(QueryIntent(kind: .unknown), queries: queries)
                == .notUnderstood)
        #expect(
            IntentAnswerer.answer(QueryIntent(kind: .categoryTotal), queries: queries)
                == .notUnderstood)
    }

    @Test func specificDetailWinsOverGeneralKind() {
        #expect(QueryIntent(kind: .monthSummary, category: .pets).resolvedKind == .categoryTotal)
        #expect(QueryIntent(kind: .unknown, merchant: "Telemach").resolvedKind == .merchantTotal)
        #expect(QueryIntent(kind: .monthSummary, category: .other).resolvedKind == .monthSummary)
        #expect(QueryIntent(kind: .subscriptions, merchant: "Apple").resolvedKind == .subscriptions)
    }

    @Test func bosnianCaseEndingsStillFindTheMerchant() {
        #expect(queries.spending(atMerchant: "Bingu", month: Month(year: 2026, month: 8)).map(\.total) == [Decimal(string: "120.40")!])
        #expect(queries.spending(atMerchant: "ab", month: nil).isEmpty)
    }

    @Test func evalMatchingUsesExactAmounts() {
        #expect(EvalSuite.matches(.answer("You spent 250.10 BAM."), expected: Decimal(string: "250.10")!))
        #expect(!EvalSuite.matches(.answer("About 250 BAM."), expected: Decimal(string: "250.10")!))
        #expect(!EvalSuite.matches(.notGrounded, expected: 1))
    }

    @Test @MainActor func reasoningTraceIsRemoved() {
        #expect(MoneyChat.removingReasoning("<think>let me see\nhmm</think>\nYou spent 5 BAM.") == "You spent 5 BAM.")
    }
}
