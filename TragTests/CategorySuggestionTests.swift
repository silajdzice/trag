import AICoach
import Foundation
import Insights
import StatementParsing
import Synchronization
import Testing

@testable import Trag

/// Stands in for the on-device model and records what it was asked.
final class StubSuggester: CategorySuggesting {
    let answers: [String: SpendingCategory]
    private let asked = Mutex<[[String]]>([])

    init(_ answers: [String: SpendingCategory]) {
        self.answers = answers
    }

    var calls: [[String]] { asked.withLock { $0 } }

    func suggest(for merchants: [String]) async throws -> [String: SpendingCategory] {
        asked.withLock { $0.append(merchants) }
        return Dictionary(uniqueKeysWithValues: merchants.map { (MerchantKey.normalize($0), answers[$0] ?? .other) })
    }
}

@Suite struct CategorySuggestionTests {
    @Test func suggestionsFillInUnknownMerchantsOnly() async throws {
        let stub = StubSuggester(["UNKNOWN SHOP DOO": .shopping])
        let ledger = LedgerModel(store: .preview(), suggester: stub)
        ledger.reload()

        await ledger.suggestCategories()

        #expect(stub.calls == [["UNKNOWN SHOP DOO"]])
        let shop = try #require(ledger.monthTransactions.first { $0.counterparty == "UNKNOWN SHOP DOO" })
        #expect(ledger.category(for: shop) == .shopping)
        #expect(ledger.categorySource(for: shop) == .ai)
    }

    @Test func eachMerchantIsAskedOnlyOnceEvenWhenUnsure() async {
        let stub = StubSuggester([:])
        let store = TransactionStore.preview()
        let ledger = LedgerModel(store: store, suggester: stub)
        ledger.reload()

        await ledger.suggestCategories()
        await ledger.suggestCategories()
        let relaunched = LedgerModel(store: store, suggester: stub)
        relaunched.reload()
        await relaunched.suggestCategories()

        #expect(stub.calls.count == 1)
    }

    @Test func suggestionNeverReplacesUserChoice() throws {
        let store = TransactionStore.preview()
        try store.setCategory(.kids, forMerchant: "UNKNOWN SHOP DOO")
        try store.saveSuggestions(["UNKNOWN SHOP DOO": .shopping])
        #expect(try store.categoryOverrides()["UNKNOWN SHOP DOO"] == .kids)
        #expect(try store.categorySuggestions().isEmpty)
    }

    @Test func userChoiceReplacesSuggestion() throws {
        let store = TransactionStore.preview()
        try store.saveSuggestions(["UNKNOWN SHOP DOO": .shopping])
        try store.setCategory(.kids, forMerchant: "UNKNOWN SHOP DOO")
        #expect(try store.categoryOverrides()["UNKNOWN SHOP DOO"] == .kids)
        #expect(try store.categorySuggestions().isEmpty)
    }

    @Test func noModelMeansNoSuggestions() async {
        let ledger = LedgerModel(store: .preview(), suggester: nil)
        ledger.reload()
        await ledger.suggestCategories()
        #expect(!ledger.isSuggestingCategories)
        #expect(!ledger.canGenerateTips)
    }
}
