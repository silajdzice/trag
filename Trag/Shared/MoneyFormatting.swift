import Foundation

extension Decimal {
    /// Formats in the user's locale with the statement currency, e.g. "2.936,39 KM" (bs) or "BAM 2,936.39" (en).
    func moneyFormatted(currency: String) -> String {
        formatted(.currency(code: currency))
    }
}
