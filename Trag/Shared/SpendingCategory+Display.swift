import Insights
import SwiftUI

extension SpendingCategory {
    var title: LocalizedStringResource {
        switch self {
        case .groceries: "Groceries"
        case .eatingOut: "Eating out"
        case .utilities: "Utilities"
        case .telecom: "Phone & internet"
        case .housing: "Housing"
        case .health: "Health"
        case .personalCare: "Personal care"
        case .pets: "Pets"
        case .kids: "Kids"
        case .shopping: "Shopping"
        case .entertainment: "Entertainment"
        case .subscriptions: "Subscriptions"
        case .transport: "Transport"
        case .cash: "Cash"
        case .fees: "Bank fees"
        case .income: "Income"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .groceries: "cart"
        case .eatingOut: "fork.knife"
        case .utilities: "bolt"
        case .telecom: "antenna.radiowaves.left.and.right"
        case .housing: "house"
        case .health: "cross.case"
        case .personalCare: "sparkles"
        case .pets: "pawprint"
        case .kids: "figure.and.child.holdinghands"
        case .shopping: "bag"
        case .entertainment: "popcorn"
        case .subscriptions: "repeat"
        case .transport: "car"
        case .cash: "banknote"
        case .fees: "building.columns"
        case .income: "arrow.down.circle"
        case .other: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .groceries: .green
        case .eatingOut: .orange
        case .utilities: .yellow
        case .telecom: .cyan
        case .housing: .brown
        case .health: .red
        case .personalCare: .pink
        case .pets: .mint
        case .kids: .purple
        case .shopping: .indigo
        case .entertainment: .teal
        case .subscriptions: .blue
        case .transport: .gray
        case .cash: .green
        case .fees: .secondary
        case .income: .green
        case .other: .secondary
        }
    }

    /// Categories a user can pick for a merchant (cash, fees and income come from the transaction type).
    static var assignable: [SpendingCategory] {
        allCases.filter { ![.cash, .fees, .income].contains($0) }
    }
}
