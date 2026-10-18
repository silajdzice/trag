import Foundation
import Testing

@testable import AICoach

@Suite struct GroundingCheckTests {
    @Test(arguments: [
        ("You spent 526.75 BAM on groceries.", ["526.75"]),
        ("Ukupno 2.936,39 KM", ["2936.39"]),
        ("That is 1,234.56 BAM", ["1234.56"]),
        ("37% less than August", ["37"]),
        ("In September 2026 on the 21st", []),
        ("You paid 150 KM for heating", ["150"]),
    ])
    func findsMoneyLikeNumbers(text: String, expected: [String]) {
        #expect(GroundingCheck.amounts(in: text) == Set(expected.compactMap { Decimal(string: $0) }))
    }

    @Test func groundedAnswerPasses() {
        let sources = ["Groceries in 2026-09: 526.75 BAM across 31 transactions"]
        #expect(GroundingCheck.ungroundedAmounts(in: "You spent 526.75 BAM on groceries.", sources: sources).isEmpty)
    }

    @Test func inventedAmountIsCaught() {
        let sources = ["Groceries in 2026-09: 526.75 BAM"]
        #expect(GroundingCheck.ungroundedAmounts(in: "You spent 432.50 BAM on snacks.", sources: sources) == [432.5])
    }

    @Test func roundedAmountIsNotTrusted() {
        let sources = ["Groceries in 2026-09: 526.75 BAM"]
        #expect(!GroundingCheck.ungroundedAmounts(in: "About 527 BAM.", sources: sources).isEmpty)
    }

    @Test func answerWithoutAmountsIsGrounded() {
        #expect(GroundingCheck.ungroundedAmounts(in: "I don't know.", sources: []).isEmpty)
    }
}
