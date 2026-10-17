import Foundation
import StatementParsing

public protocol TransactionCategorizer: Sendable {
    func category(for transaction: BankTransaction) -> SpendingCategory
}

/// Deterministic categorisation: transaction kind, then the user's own choices, then keyword rules.
/// The on-device model only helps with merchants this returns `.other` for.
public struct RuleBasedCategorizer: TransactionCategorizer {
    public struct Rule: Sendable {
        public enum Match: Sendable { case contains, word }
        public let keyword: String
        public let match: Match
        public let category: SpendingCategory

        public init(_ keyword: String, _ category: SpendingCategory, match: Match = .contains) {
            self.keyword = MerchantKey.normalize(keyword)
            self.match = match
            self.category = category
        }

        func matches(_ key: String) -> Bool {
            switch match {
            case .contains: key.contains(keyword)
            case .word: " \(key) ".contains(" \(keyword) ")
            }
        }
    }

    public let rules: [Rule]
    /// User choices keyed by `MerchantKey.normalize(counterparty)`. Always win over rules.
    public let overrides: [String: SpendingCategory]

    public init(rules: [Rule] = RuleBasedCategorizer.defaultRules, overrides: [String: SpendingCategory] = [:]) {
        self.rules = rules
        self.overrides = overrides
    }

    public func category(for transaction: BankTransaction) -> SpendingCategory {
        switch transaction.kind {
        case .fee: return .fees
        case .cashWithdrawal: return .cash
        case .income: return .income
        default: break
        }
        let key = MerchantKey.normalize(transaction.counterparty)
        if let override = overrides[key] { return override }
        if transaction.amount > 0 { return .income }
        return rules.first { $0.matches(key) }?.category ?? .other
    }
}

extension RuleBasedCategorizer {
    /// Well-known merchants and payees in Bosnia and Herzegovina and the region. Order matters: specific first.
    public static let defaultRules: [Rule] = [
        // Kids before groceries ("MARKET TOYS" must not become groceries)
        Rule("TOYS", .kids), Rule("KID ZONE", .kids), Rule("KIDS", .kids), Rule("PLAYLAND", .kids), Rule("IGRAONICA", .kids),
        // Groceries
        Rule("AMKO KOMERC", .groceries), Rule("KONZUM", .groceries), Rule("BINGO", .groceries), Rule("PENNY", .groceries),
        Rule("TROPIC", .groceries), Rule("ROBOT", .groceries), Rule("MERCATOR", .groceries), Rule("SPAR", .groceries, match: .word),
        Rule("INTERSPAR", .groceries), Rule("LIDL", .groceries), Rule("HOSE KOMERC", .groceries), Rule("PLODINE", .groceries),
        Rule("STUDENAC", .groceries), Rule("TOMMY", .groceries, match: .word), Rule("PEKARA", .groceries),
        // Eating out and food delivery
        Rule("PIZZ", .eatingOut), Rule("FAST FOOD", .eatingOut), Rule("RESTORAN", .eatingOut), Rule("CEVABDZINICA", .eatingOut),
        Rule("BURGER", .eatingOut), Rule("MCDONALD", .eatingOut), Rule("CAFE", .eatingOut), Rule("CAFFE", .eatingOut),
        Rule("KORPA", .eatingOut), Rule("GLOVO", .eatingOut), Rule("WOLT", .eatingOut),
        // Utilities and housing
        Rule("ELEKTROPRIVREDA", .utilities), Rule("TOPLANE", .utilities), Rule("VODOVOD", .utilities), Rule("KJKP RAD", .utilities),
        Rule("SARAJEVOGAS", .utilities), Rule("ELEKTRODISTRIBUCIJA", .utilities),
        Rule("UPRAVITELJ", .housing),
        // Telecom
        Rule("BH TELECOM", .telecom), Rule("BHT", .telecom, match: .word), Rule("TELEMACH", .telecom), Rule("MTEL", .telecom),
        Rule("ERONET", .telecom),
        // Health
        Rule("APOTEKA", .health), Rule("PZU", .health, match: .word), Rule("ZDRAV", .health), Rule("POLIKLINIKA", .health),
        Rule("BOLNICA", .health),
        // Personal care
        Rule("DM", .personalCare, match: .word), Rule("MULLER", .personalCare), Rule("LUSH", .personalCare),
        Rule("FRIZER", .personalCare), Rule("WELLNESS", .personalCare), Rule("KOZMETIK", .personalCare),
        // Pets
        Rule("ZOO", .pets, match: .word), Rule("VETERINAR", .pets), Rule("PET CENTAR", .pets),
        // Subscriptions
        Rule("APPLE COM", .subscriptions), Rule("YOUTUBEPREMIUM", .subscriptions), Rule("NETFLIX", .subscriptions),
        Rule("SPOTIFY", .subscriptions), Rule("DISNEY", .subscriptions), Rule("OPENAI", .subscriptions),
        Rule("ANTHROPIC", .subscriptions), Rule("ICLOUD", .subscriptions),
        // Entertainment and games
        Rule("CINEPLEXX", .entertainment), Rule("KINO", .entertainment), Rule("BATTLE NET", .entertainment),
        Rule("BLIZZARD", .entertainment), Rule("STEAM", .entertainment, match: .word), Rule("PLAYSTATION", .entertainment),
        Rule("G2G", .entertainment, match: .word),
        // Transport
        Rule("PARKING", .transport), Rule("AUTOCEST", .transport), Rule("PUMPA", .transport), Rule("PETROL", .transport),
        Rule("ENERGOPETROL", .transport), Rule("HIFA", .transport), Rule("TAXI", .transport), Rule("CENTROTRANS", .transport),
        Rule("GRAS", .transport, match: .word),
        // Shopping
        Rule("DEICHMANN", .shopping), Rule("OFFICE SHOES", .shopping), Rule("JYSK", .shopping), Rule("ANANAS", .shopping),
        Rule("TEMU", .shopping), Rule("ZARA", .shopping, match: .word), Rule("H M", .shopping, match: .word),
        Rule("IKEA", .shopping), Rule("EMMEZETA", .shopping),
    ]
}
