import Foundation

/// Guards against invented numbers: every amount in a model's text must appear in the data it was given.
public enum GroundingCheck {
    /// Money-like numbers in `text`: numbers with two decimals ("526.75", "1.234,56") or followed by a currency or "%".
    /// Plain integers such as years ("2026") or days are ignored.
    public static func amounts(in text: String) -> Set<Decimal> {
        let pattern = /(\d+(?:[.,]\d{3})*(?:[.,]\d{1,2})?)\s*(BAM|KM|EUR|USD|%)?/
        var found: Set<Decimal> = []
        for match in text.matches(of: pattern) {
            let number = String(match.output.1)
            let hasUnit = match.output.2 != nil
            let hasCents = number.firstMatch(of: /[.,]\d{2}$/) != nil
            guard hasUnit || hasCents, let value = normalize(number) else { continue }
            found.insert(value)
        }
        return found
    }

    /// Amounts in `answer` that none of `sources` contains. Empty means the answer is grounded.
    public static func ungroundedAmounts(in answer: String, sources: [String]) -> Set<Decimal> {
        let known = sources.reduce(into: Set<Decimal>()) { $0.formUnion(amounts(in: $1)) }
        return amounts(in: answer).subtracting(known)
    }

    /// "1.234,56" / "1,234.56" / "526.75" / "526" → Decimal. The last separator followed by 1–2 digits is the decimal point.
    static func normalize(_ number: String) -> Decimal? {
        var digits = number
        var fraction = ""
        if let match = number.firstMatch(of: /[.,](\d{1,2})$/) {
            fraction = String(match.output.1)
            digits = String(number[..<match.range.lowerBound])
        }
        let whole = digits.filter(\.isNumber)
        return Decimal(string: fraction.isEmpty ? whole : "\(whole).\(fraction)", locale: Locale(identifier: "en_US_POSIX"))
    }
}
