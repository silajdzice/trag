import AICoach
import Foundation
import Insights
import Testing

@testable import Trag

@Suite struct AISettingsTests {
    func defaults() -> UserDefaults {
        let name = "AISettingsTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func defaultsToAppleIntelligenceWhereAvailable() {
        let settings = AISettings(defaults: defaults(), appleIntelligence: .available)
        #expect(settings.selectedEngine == .appleIntelligence)
    }

    @Test func olderPhonesStartWithAIOff() {
        let settings = AISettings(defaults: defaults(), appleIntelligence: .unavailable(.deviceNotEligible))
        #expect(settings.isOff)
        #expect(settings.selectedEngine == nil)
    }

    @Test func anyoneCanChooseADownloadedModelAndItIsRemembered() throws {
        let store = defaults()
        let model = try #require(LocalModel.catalog.first { $0.tier == .recommended })
        AISettings(defaults: store, appleIntelligence: .available).select(.local(model))
        let reopened = AISettings(defaults: store, appleIntelligence: .available)
        #expect(reopened.selectedEngine == .local(model))
    }

    @Test func appleSelectionIsIgnoredWhenItBecomesUnavailable() {
        let store = defaults()
        AISettings(defaults: store, appleIntelligence: .available).select(.appleIntelligence)
        let later = AISettings(defaults: store, appleIntelligence: .unavailable(.appleIntelligenceNotEnabled))
        #expect(later.selectedEngine == nil)
    }

    @Test func catalogIsSaneAndOrderedBySize() {
        let catalog = LocalModel.catalog
        #expect(Set(catalog.map(\.id)).count == catalog.count)
        #expect(catalog.map(\.downloadBytes) == catalog.map(\.downloadBytes).sorted())
        #expect(catalog.filter { $0.tier == .recommended }.count == 1)
    }

    @Test func enginesRoundTripThroughTheirIDs() {
        for engine in [AIEngine.appleIntelligence] + LocalModel.catalog.map(AIEngine.local) {
            #expect(AIEngine(id: engine.id) == engine)
        }
        #expect(AIEngine(id: "unknown") == nil)
    }
}

@Suite struct ComputedAnswerTextTests {
    let september = Month(year: 2026, month: 9)

    @Test func categoryAnswerShowsAmountMonthAndCount() {
        let text = ComputedAnswer.categoryTotal(category: .groceries, month: september, total: 250.1, count: 3, currency: "BAM")
            .localizedText
        #expect(text.contains(Decimal(250.1).moneyFormatted(currency: "BAM")))
        #expect(text.contains(september.displayName))
        #expect(text.contains("3"))
    }

    @Test func notUnderstoodNeverInventsANumber() {
        #expect(ComputedAnswer.notUnderstood.localizedText.allSatisfy { !$0.isNumber })
    }

    @Test func subscriptionsListEveryName() {
        let text = ComputedAnswer.subscriptions(names: ["YouTube", "Apple"], monthlyTotal: 20, currency: "BAM").localizedText
        #expect(text.contains("YouTube") && text.contains("Apple"))
    }
}
