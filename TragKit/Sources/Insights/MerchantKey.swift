import Foundation

/// Normalised form of a merchant name used for rules and user overrides:
/// uppercase, no diacritics, only letters, digits and single spaces.
/// "GOOGLE *YouTubePremium" → "GOOGLE YOUTUBEPREMIUM", "Čevabdžinica Željo" → "CEVABDZINICA ZELJO".
public enum MerchantKey {
    public static func normalize(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "đ", with: "dj")
            .uppercased()
        let cleaned = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }
}
