import Foundation
import StatementParsing

/// A calendar month, used to group and navigate transactions.
public struct Month: Hashable, Comparable, Sendable, Identifiable {
    public let year: Int
    public let month: Int

    public var id: String { String(format: "%04d-%02d", year, month) }

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(containing date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 0)
    }

    /// First moment of the month, for display formatting.
    public func startDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    public func previous() -> Month {
        month == 1 ? Month(year: year - 1, month: 12) : Month(year: year, month: month - 1)
    }

    public static func < (lhs: Month, rhs: Month) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

extension Sequence where Element == BankTransaction {
    /// Transactions grouped by the month of their booking date.
    public func groupedByMonth(calendar: Calendar = .current) -> [Month: [BankTransaction]] {
        Dictionary(grouping: self) { Month(containing: $0.bookingDate, calendar: calendar) }
    }
}
