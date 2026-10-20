import Foundation
import Insights
import StatementParsing
import Testing

@testable import Trag

@Suite struct DemoDataTests {
    let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20))!

    @Test func threeMonthsEndingLastMonth() {
        let statements = DemoData.statements(endingBefore: now)
        let months = statements.flatMap(\.transactions).groupedByMonth().keys.sorted()
        #expect(months == [Month(year: 2026, month: 7), Month(year: 2026, month: 8), Month(year: 2026, month: 9)])
        let allTotalsMatch = statements.allSatisfy { $0.matchesReportedTotals }
        #expect(allTotalsMatch)
    }

    @Test func showsEveryFeature() {
        let all = DemoData.statements(endingBefore: now).flatMap(\.transactions)
        let summary = SpendingSummary(transactions: all)
        #expect(Set(summary.byCategory.map(\.key)).isSuperset(of: [.groceries, .pets, .utilities, .subscriptions, .cash, .fees]))
        let recurring = RecurringPaymentDetector.detect(in: all)
        #expect(recurring.contains { $0.kind == .subscription })
        #expect(recurring.contains { $0.kind == .bill })
    }

    @Test func importsOnceEvenWhenTappedTwice() throws {
        let store = TransactionStore.preview(empty: true)
        let model = StatementImportModel(store: store)
        model.importDemoData()
        model.importDemoData()
        let expected = DemoData.statements().reduce(0) { $0 + $1.transactions.count }
        #expect(try store.transactions().count == expected)
    }

    @Test func isDeterministic() {
        let first = DemoData.statements(endingBefore: now).flatMap(\.transactions).map(\.amount)
        let second = DemoData.statements(endingBefore: now).flatMap(\.transactions).map(\.amount)
        #expect(first == second)
    }
}
