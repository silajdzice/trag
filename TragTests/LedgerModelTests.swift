import Foundation
import Insights
import StatementParsing
import Testing

@testable import Trag

@Suite struct LedgerModelTests {
    @Test func emptyStoreHasNoMonths() {
        let ledger = LedgerModel(store: .preview(empty: true))
        ledger.reload()
        #expect(ledger.isEmpty)
        #expect(ledger.selectedMonth == nil)
        #expect(ledger.summary == nil)
    }

    @Test func selectsLatestMonthByDefault() {
        let ledger = LedgerModel.preview()
        #expect(ledger.months == [Month(year: 2026, month: 9), Month(year: 2026, month: 8), Month(year: 2026, month: 7)])
        #expect(ledger.selectedMonth == Month(year: 2026, month: 9))
        #expect(ledger.monthTransactions.count == 9)
    }

    @Test func changingMonthUpdatesSummary() throws {
        let ledger = LedgerModel.preview()
        ledger.selectedMonth = Month(year: 2026, month: 8)
        let summary = try #require(ledger.summary)
        #expect(summary.totalSpent == Decimal(string: "139.75"))
        #expect(summary.byCategory.map(\.key) == [.utilities, .groceries, .subscriptions])
    }

    @Test func userCategoryAppliesToAllTransactionsFromMerchant() throws {
        let ledger = LedgerModel.preview()
        let unknown = try #require(ledger.monthTransactions.first { $0.counterparty == "UNKNOWN SHOP DOO" })
        #expect(ledger.category(for: unknown) == .other)

        ledger.setCategory(.shopping, for: unknown)

        #expect(ledger.category(for: unknown) == .shopping)
        #expect(ledger.summary?.byCategory.contains { $0.key == .shopping } == true)
    }

    @Test func onlyPurchasesAndBillsCanBeRecategorised() {
        let ledger = LedgerModel.preview()
        let byName = Dictionary(uniqueKeysWithValues: ledger.monthTransactions.map { ($0.counterparty, $0) })
        #expect(ledger.canChangeCategory(of: byName["KONZUM BIH"]!))
        #expect(ledger.canChangeCategory(of: byName["JP ELEKTROPRIVREDA BIH DD SARAJEVO"]!))
        #expect(!ledger.canChangeCategory(of: byName["ATM 090101"]!))
        #expect(!ledger.canChangeCategory(of: byName["Union banka"]!))
        #expect(!ledger.canChangeCategory(of: byName["ACME DOO"]!))
    }

    @Test func comparesWithPreviousMonth() throws {
        let ledger = LedgerModel.preview()
        ledger.selectedMonth = Month(year: 2026, month: 8)
        let change = try #require(ledger.changeFromPreviousMonth)
        // July 215.80 → August 139.75
        #expect(abs(change - (139.75 - 215.80) / 215.80) < 0.0001)

        ledger.selectedMonth = Month(year: 2026, month: 7)
        #expect(ledger.changeFromPreviousMonth == nil)
    }

    @Test func detectsRecurringPaymentsAndForecasts() throws {
        let ledger = LedgerModel.preview()
        #expect(Set(ledger.recurringPayments.map(\.kind)) == [.subscription, .bill])
        #expect(ledger.recurringPayments.contains { $0.name == "GOOGLE *YouTubePremium" })
        let forecast = try #require(ledger.forecast)
        #expect(forecast.month == Month(year: 2026, month: 10))
        #expect(forecast.basedOnMonths == 3)
    }
}
