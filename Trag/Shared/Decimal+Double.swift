import Foundation

extension Decimal {
    /// For charts and percentages only; money math stays in `Decimal`.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
