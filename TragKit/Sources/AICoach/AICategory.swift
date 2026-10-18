import FoundationModels
import Insights

/// The categories the model may choose for a merchant. Cash, fees and income come from the transaction type instead.
@Generable(description: "Spending category for a shop or company")
enum AICategory: String, CaseIterable {
    case groceries, eatingOut, utilities, telecom, housing, health, personalCare, pets, kids, shopping, entertainment,
        subscriptions, transport, other

    var spendingCategory: SpendingCategory { SpendingCategory(rawValue: rawValue) ?? .other }

    /// One line per category for prompts, with local words that hint at it.
    static var promptGuide: String {
        """
        groceries: supermarkets, markets, bakeries (market, pekara, Bingo, Konzum)
        eatingOut: restaurants, cafes, fast food, food delivery (restoran, caffe, pizzeria, ćevabdžinica)
        utilities: electricity, water, heating, gas, waste
        telecom: mobile, internet, TV
        housing: rent, building management (upravitelj)
        health: pharmacies, clinics, doctors, medical supplies (apoteka, ljekarna, poliklinika, ZU, PZU, medical)
        personalCare: drugstores, cosmetics, hairdressers, wellness (frizer, kozmetika, drogerija)
        pets: pet shops, veterinarians (veterinar, zoo)
        kids: toys, children's play areas (igraonica, igračke)
        shopping: clothes, shoes, electronics, home goods, online shops, general stores (trgovina, trgovačka radnja)
        entertainment: cinema, games, events, tobacco and vape shops
        subscriptions: recurring digital services
        transport: fuel, tolls, parking, taxi, bus tickets (pumpa, autocesta, parking, autobusna stanica)
        other: anything you are not sure about
        """
    }
}
