import Foundation
import Insights
import StatementParsing
import Testing

@testable import AICoach

@Suite struct SavingTipsFactsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo")!
        return calendar
    }()

    func tx(_ amount: Decimal, _ who: String, _ month: Int, _ kind: BankTransaction.Kind = .cardPurchase, original: Money? = nil)
        -> BankTransaction
    {
        BankTransaction(
            id: UUID().uuidString,
            bookingDate: calendar.date(from: DateComponents(year: 2026, month: month, day: 10, hour: 12))!,
            valueDate: nil, amount: amount, currency: "BAM", kind: kind, counterparty: who, description: "",
            originalAmount: original, reference: "r")
    }

    @Test func signalsOnlyForThingsWorthActingOn() {
        let small = (0..<9).map { _ in tx(-5, "AMKO KOMERC", 9) }
        let queries = SpendingQueries(
            transactions: small + [
                tx(-60, "KONZUM", 8), tx(-40, "KONZUM", 9),  // groceries: 85 (incl. AMKO) vs 60 → up
                tx(-50, "CINEPLEXX", 8), tx(-20, "CINEPLEXX", 9),  // entertainment went down: no signal
                tx(-180, "ATM", 9, .cashWithdrawal), tx(-1, "Union banka", 9, .fee),
                tx(-14.41, "YOUTUBE", 9, original: Money(amount: 8.49, currency: "USD")),
            ],
            categorizer: RuleBasedCategorizer(), calendar: calendar)

        let facts = SavingTipsGenerator.facts(for: Month(year: 2026, month: 9), queries: queries)

        #expect(facts.contains("groceries went up: 85.00 BAM vs 60.00 BAM"))
        #expect(facts.contains("Many small purchases: 9 payments at AMKO KOMERC, 45.00 BAM"))
        #expect(facts.contains("Cash withdrawals: 1, 180.00 BAM"))
        #expect(facts.contains("Bank fees: 1.00 BAM in 1 separate charges"))
        #expect(facts.contains("Card payments in foreign currency: 1"))
        #expect(!facts.contains("entertainment went up"))
    }
}
