import Foundation

/// Where money goes. Display names and icons live in the app (localized UI concerns).
public enum SpendingCategory: String, CaseIterable, Sendable, Codable, Hashable, Identifiable {
    case groceries
    case eatingOut
    case utilities
    case telecom
    case housing
    case health
    case personalCare
    case pets
    case kids
    case shopping
    case entertainment
    case subscriptions
    case transport
    case cash
    case fees
    case income
    case other

    public var id: String { rawValue }

    /// Categories that are money coming in rather than spending.
    public var isIncome: Bool { self == .income }
}
