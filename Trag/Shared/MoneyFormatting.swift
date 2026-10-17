import Foundation

extension Decimal {
    /// "2.936,39 KM" for BAM; the statement currency drives the symbol.
    func moneyFormatted(currency: String) -> String {
        formatted(.currency(code: currency).locale(Locale(identifier: "bs_BA")))
    }
}
