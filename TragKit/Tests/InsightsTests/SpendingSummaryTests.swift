import Foundation
import Testing
import StatementParsing
@testable import Insights

@Suite struct SpendingSummaryTests {
    private func tx(_ amount: Decimal, _ who: String, _ kind: Transaction.Kind = .cardPurchase) -> Transaction {
        Transaction(id: UUID().uuidString, bookingDate: .now, valueDate: nil, amount: amount, currency: "BAM",
                    kind: kind, counterparty: who, description: "", reference: "r")
    }

    @Test func totalsAndTopCounterparty() {
        let summary = SpendingSummary(transactions: [
            tx(-10, "Shop A"), tx(-30, "Shop B"), tx(-5, "Shop A"), tx(-1, "Union banka", .fee), tx(100, "Employer", .income),
        ])
        #expect(summary.totalSpent == 46)
        #expect(summary.totalIncome == 100)
        #expect(summary.byCounterparty.first?.name == "Shop B")
        #expect(summary.byCounterparty.first { $0.name == "Shop A" }?.total == 15)
        #expect(summary.fees == 1)
    }
}
