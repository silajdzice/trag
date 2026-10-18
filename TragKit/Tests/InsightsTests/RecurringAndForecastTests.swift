import Foundation
import StatementParsing
import Testing

@testable import Insights

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo")!
    return calendar
}()

private func on(_ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
}

private func charge(
    _ amount: Decimal, _ who: String, _ month: Int, _ day: Int = 15, kind: BankTransaction.Kind = .cardPurchase,
    original: Money? = nil
) -> BankTransaction {
    BankTransaction(
        id: UUID().uuidString, bookingDate: on(month, day), valueDate: nil, amount: amount, currency: "BAM",
        kind: kind, counterparty: who, description: "", originalAmount: original, reference: "r")
}

@Suite struct RecurringPaymentDetectorTests {
    let usd = Money(amount: Decimal(string: "8.49")!, currency: "USD")

    @Test func foreignSubscriptionWithSamePriceIsDetectedDespiteExchangeRate() throws {
        let found = RecurringPaymentDetector.detect(
            in: [
                charge(-14.41, "GOOGLE *YouTubePremium", 7, original: usd),
                charge(-14.65, "GOOGLE*YOUTUBEPREMIUM", 8, original: usd),
                charge(-14.30, "GOOGLE *YouTubePremium", 9, original: usd),
            ], calendar: calendar)
        let youtube = try #require(found.first)
        #expect(found.count == 1)
        #expect(youtube.kind == .subscription)
        #expect(youtube.monthlyAmount == Decimal(string: "14.41"))
        #expect(youtube.originalAmount == usd)
        #expect(youtube.months.count == 3)
        #expect(calendar.dateComponents([.month, .day], from: youtube.nextExpected) == DateComponents(month: 10, day: 15))
    }

    @Test func billsMayVaryInAmount() {
        let found = RecurringPaymentDetector.detect(
            in: [
                charge(-70, "JP ELEKTROPRIVREDA BIH", 7, 21, kind: .billPayment),
                charge(-93.26, "JP ELEKTROPRIVREDA BIH", 8, 21, kind: .billPayment),
            ], calendar: calendar)
        #expect(found.map(\.kind) == [.bill])
    }

    @Test func frequentShopsAreNotRecurring() {
        let groceries = (7...9).flatMap { month in (1...6).map { charge(-Decimal($0 * 7), "AMKO KOMERC", month, $0 * 4) } }
        #expect(RecurringPaymentDetector.detect(in: groceries, calendar: calendar).isEmpty)
    }

    @Test func varyingCardAmountsAreNotSubscriptions() {
        let cinema = [charge(-66, "CINEPLEXX", 7), charge(-38, "CINEPLEXX", 8), charge(-104, "CINEPLEXX", 9)]
        #expect(RecurringPaymentDetector.detect(in: cinema, calendar: calendar).isEmpty)
    }

    @Test func everydaySpendingIsNeverASubscription() {
        let tolls = [charge(-2.2, "JP AUTOCESTE FBIH DOO", 7), charge(-2.2, "JP AUTOCESTE FBIH DOO", 8)]
        #expect(RecurringPaymentDetector.detect(in: tolls, calendar: calendar).isEmpty)
    }

    @Test func forecastIsRoundedToCents() throws {
        let transactions = [charge(-10, "SHOP", 7), charge(-10, "SHOP", 8), charge(-11, "SHOP", 9)]
        let forecast = try #require(SpendingForecast(transactions: transactions, recurringPayments: [], calendar: calendar))
        #expect(forecast.variable == Decimal(string: "10.33"))
    }

    @Test func singleMonthIsNotEnough() {
        #expect(RecurringPaymentDetector.detect(in: [charge(-5.85, "APPLE.COM/BILL", 9)], calendar: calendar).isEmpty)
    }

    @Test func longGapBreaksTheSeries() {
        let sporadic = [charge(-9.99, "SOME APP", 3), charge(-9.99, "SOME APP", 9)]
        #expect(RecurringPaymentDetector.detect(in: sporadic, calendar: calendar).isEmpty)
    }
}

@Suite struct SpendingForecastTests {
    @Test func recurringPlusAverageOfTheRest() throws {
        let transactions = [
            charge(-10, "NETFLIX", 8), charge(-10, "NETFLIX", 9),
            charge(-100, "SHOP", 8), charge(-300, "SHOP", 9),
        ]
        let recurring = RecurringPaymentDetector.detect(in: transactions, calendar: calendar)
        let forecast = try #require(SpendingForecast(transactions: transactions, recurringPayments: recurring, calendar: calendar))
        #expect(forecast.month == Month(year: 2026, month: 10))
        #expect(forecast.recurring == 10)
        #expect(forecast.variable == 200)
        #expect(forecast.total == 210)
        #expect(forecast.basedOnMonths == 2)
    }

    @Test func noDataNoForecast() {
        #expect(SpendingForecast(transactions: [], recurringPayments: [], calendar: calendar) == nil)
    }

    @Test func monthlyHistoryIsOldestFirst() {
        let history = MonthlySpending.history(
            [charge(-5, "A", 9), charge(-7, "B", 8), charge(-3, "C", 9), charge(100, "Salary", 9, kind: .income)],
            calendar: calendar)
        #expect(history.map(\.month.month) == [8, 9])
        #expect(history.map(\.spent) == [7, 8])
    }
}
