import Foundation
import Testing

@testable import Insights

@Suite struct MonthTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo")!
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func groupsByBookingMonth() {
        let groups = [
            makeTransaction(-1, "A", on: date(2026, 7, 31)),
            makeTransaction(-2, "B", on: date(2026, 8, 1)),
            makeTransaction(-3, "C", on: date(2026, 8, 20)),
        ].groupedByMonth(calendar: calendar)

        #expect(groups.keys.sorted() == [Month(year: 2026, month: 7), Month(year: 2026, month: 8)])
        #expect(groups[Month(year: 2026, month: 8)]?.count == 2)
    }

    @Test func previousMonthWrapsYear() {
        #expect(Month(year: 2026, month: 1).previous() == Month(year: 2025, month: 12))
        #expect(Month(year: 2026, month: 9).previous() == Month(year: 2026, month: 8))
    }

    @Test func ordering() {
        #expect(Month(year: 2025, month: 12) < Month(year: 2026, month: 1))
    }
}
