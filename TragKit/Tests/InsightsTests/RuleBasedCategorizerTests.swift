import Foundation
import StatementParsing
import Testing

@testable import Insights

@Suite struct RuleBasedCategorizerTests {
    let categorizer = RuleBasedCategorizer()

    @Test(arguments: [
        ("AMKO KOMERC D.O.O. SAR", SpendingCategory.groceries),
        ("POS PJ TROPIC 61", .groceries),
        ("MARKET TOYS AND FUN", .kids),
        ("POS 0035 DM SA", .personalCare),
        ("ZOO CENTAR D.O.O. ALTA", .pets),
        ("VETERINARSKA STANICA T", .pets),
        ("MONIS PRIVATNA APOTEKA", .health),
        ("PRIVATNA ZDRAV.USTANOV", .health),
        ("GOOGLE *YouTubePremium", .subscriptions),
        ("APPLE.COM/BILL", .subscriptions),
        ("Battle.net", .entertainment),
        ("CINEPLEXX BH SARAJEVO", .entertainment),
        ("JP AUTOCESTE FBIH DOO", .transport),
        ("EL TARIK OIL- PUMPA", .transport),
        ("FAST FOOD VAGABUNDO ZI", .eatingOut),
        ("Pizzeria Maslina", .eatingOut),
        ("JP ELEKTROPRIVREDA BIH DD SARAJEVO", .utilities),
        ("BH Telecom dd Sarajevo", .telecom),
        ("BHT- DIREKCIJA SARAJEVO", .telecom),
        ("OKI UPRAVITELJ D.O.O SARAJEVO", .housing),
        ("Temu.com", .shopping),
        ("SOME UNKNOWN SHOP", .other),
    ])
    func keywordRules(merchant: String, expected: SpendingCategory) {
        #expect(categorizer.category(for: makeTransaction(-1, merchant)) == expected)
    }

    @Test func dmDoesNotMatchInsideWords() {
        #expect(categorizer.category(for: makeTransaction(-1, "ADMIRAL BET")) == .other)
    }

    @Test func kindWinsOverName() {
        #expect(categorizer.category(for: makeTransaction(-180, "ATM AMKO KOMERC", .cashWithdrawal)) == .cash)
        #expect(categorizer.category(for: makeTransaction(-1, "Union banka", .fee)) == .fees)
        #expect(categorizer.category(for: makeTransaction(100, "AMKO KOMERC", .income)) == .income)
    }

    @Test func refundsAreIncome() {
        #expect(categorizer.category(for: makeTransaction(20, "KONZUM BIH")) == .income)
    }

    @Test func userOverrideWins() {
        let custom = RuleBasedCategorizer(overrides: [MerchantKey.normalize("AMKO KOMERC D.O.O. SAR"): .eatingOut])
        #expect(custom.category(for: makeTransaction(-5, "AMKO KOMERC D.O.O. SAR")) == .eatingOut)
    }

    @Test func precedenceUserThenRuleThenAI() {
        let categorizer = RuleBasedCategorizer(
            overrides: ["KONZUM BIH": .shopping],
            suggestions: ["KONZUM BIH": .health, "BINGO D O O": .kids, "SOLIDEX DOO": .health])
        #expect(categorizer.categorization(for: makeTransaction(-1, "KONZUM BIH")) == (.shopping, .user))
        #expect(categorizer.categorization(for: makeTransaction(-1, "BINGO D.O.O.")) == (.groceries, .rule))
        #expect(categorizer.categorization(for: makeTransaction(-1, "SOLIDEX DOO")) == (.health, .ai))
        #expect(categorizer.categorization(for: makeTransaction(-1, "UNKNOWN")) == (.other, .none))
        #expect(categorizer.categorization(for: makeTransaction(-1, "Union banka", .fee)) == (.fees, .transactionKind))
    }

    @Test func merchantKeyNormalisation() {
        #expect(MerchantKey.normalize("GOOGLE *YouTubePremium") == "GOOGLE YOUTUBEPREMIUM")
        #expect(MerchantKey.normalize("Čevabdžinica Željo") == "CEVABDZINICA ZELJO")
        #expect(MerchantKey.normalize("  POS  0035 DM-SA ") == "POS 0035 DM SA")
    }
}
