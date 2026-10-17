import Foundation
import StatementParsing
import Testing

@testable import Insights

func makeTransaction(
    _ amount: Decimal, _ counterparty: String, _ kind: BankTransaction.Kind = .cardPurchase, on date: Date = .now
) -> BankTransaction {
    BankTransaction(
        id: UUID().uuidString, bookingDate: date, valueDate: nil, amount: amount, currency: "BAM",
        kind: kind, counterparty: counterparty, description: "", reference: "r")
}

@Suite struct SpendingSummaryTests {
    let summary = SpendingSummary(transactions: [
        makeTransaction(-10, "KONZUM BIH K001"),
        makeTransaction(-30, "CINEPLEXX BH SARAJEVO"),
        makeTransaction(-5, "BINGO D.O.O. TUZLA SM"),
        makeTransaction(-100, "ATM 090101", .cashWithdrawal),
        makeTransaction(-1, "Union banka", .fee),
        makeTransaction(500, "ACME DOO", .income),
    ])

    @Test func totals() {
        #expect(summary.totalSpent == 146)
        #expect(summary.totalIncome == 500)
        #expect(summary.fees == 1)
    }

    @Test func byCategoryIsSortedByTotal() {
        #expect(summary.byCategory.map(\.key) == [.cash, .entertainment, .groceries, .fees])
        #expect(summary.byCategory.first { $0.key == .groceries }?.total == 15)
        #expect(summary.byCategory.first { $0.key == .groceries }?.count == 2)
    }

    @Test func merchantsExcludeCashAndFees() {
        #expect(summary.byMerchant.map(\.key) == ["CINEPLEXX BH SARAJEVO", "KONZUM BIH K001", "BINGO D.O.O. TUZLA SM"])
    }

    @Test func shareOfSpending() throws {
        let cash = try #require(summary.byCategory.first)
        #expect(abs(summary.share(of: cash) - 100.0 / 146.0) < 0.0001)
    }
}
