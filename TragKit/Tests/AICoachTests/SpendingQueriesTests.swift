import Foundation
import Insights
import StatementParsing
import Testing

@testable import AICoach

@Suite struct SpendingQueriesTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo")!
        return calendar
    }()

    func tx(_ amount: Decimal, _ who: String, month: Int, kind: BankTransaction.Kind = .cardPurchase) -> BankTransaction {
        BankTransaction(
            id: UUID().uuidString,
            bookingDate: calendar.date(from: DateComponents(year: 2026, month: month, day: 10, hour: 12))!,
            valueDate: nil, amount: amount, currency: "BAM", kind: kind, counterparty: who, description: "", reference: "r")
    }

    var queries: SpendingQueries {
        SpendingQueries(
            transactions: [
                tx(-10, "KONZUM BIH", month: 8), tx(-20.5, "BINGO D.O.O.", month: 9), tx(-30, "KONZUM BIH", month: 9),
                tx(-66, "CINEPLEXX BH", month: 9), tx(2000, "ACME", month: 9, kind: .income),
            ],
            categorizer: RuleBasedCategorizer(), calendar: calendar)
    }

    @Test func monthResolution() {
        #expect(queries.resolveMonth("2026-08") == Month(year: 2026, month: 8))
        #expect(queries.resolveMonth("2026-8") == Month(year: 2026, month: 8))
        #expect(queries.resolveMonth(nil) == Month(year: 2026, month: 9))
        #expect(queries.resolveMonth("last month please") == Month(year: 2026, month: 9))
    }

    @Test func categoryTotals() {
        let result = queries.spending(in: .groceries, month: Month(year: 2026, month: 9))
        #expect(result.total == Decimal(string: "50.5"))
        #expect(result.count == 2)
    }

    @Test func merchantSearchIgnoresCaseAndPunctuation() {
        let all = queries.spending(atMerchant: "konzum", month: nil)
        #expect(all.map(\.total) == [40])
        #expect(queries.spending(atMerchant: "Konzum", month: Month(year: 2026, month: 8)).map(\.total) == [10])
        #expect(queries.spending(atMerchant: "  ", month: nil).isEmpty)
    }

    @Test func expensesFilterByCategoryShopAndMonth() {
        let groceries = queries.expenses(category: .groceries)
        #expect(groceries.count == 3)
        #expect(groceries.last?.amount == -10)  // August, the oldest, comes last
        #expect(queries.expenses(category: .groceries, month: Month(year: 2026, month: 9)).count == 2)
        #expect(queries.expenses(merchant: "Konzumu").count == 2)
        #expect(queries.expenses(merchant: "Zara").isEmpty)
        #expect(queries.expenses(category: .entertainment, merchant: "Konzum").isEmpty)
    }

    @Test func amountTextIsStableForTheModel() {
        #expect(AmountText.format(Decimal(string: "2936.391")!, "BAM") == "2936.39 BAM")
        #expect(AmountText.format(5, "EUR") == "5.00 EUR")
        #expect(AmountText.month(Month(year: 2026, month: 9)) == "2026-09")
    }
}
