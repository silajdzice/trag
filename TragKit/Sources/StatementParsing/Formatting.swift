import Foundation

enum LocalFormat {
    /// Parses "1.234,56" or "4,00" (dot thousands, comma decimals).
    static func decimal(_ string: String) -> Decimal? {
        let cleaned = string
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Parses "02.09.2026." or "02.09.2026".
    static func date(_ string: String) -> Date? {
        let parts = string.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).split(separator: ".")
        guard parts.count == 3, let d = Int(parts[0]), let m = Int(parts[1]), let y = Int(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sarajevo") ?? .current
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
    }

    static func collapseWhitespace(_ string: String) -> String {
        string.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
