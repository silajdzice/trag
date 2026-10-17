import Foundation
import Insights
import StatementParsing
import Testing

@testable import Trag

@Suite struct TransactionStoreTests {
    let store = TransactionStore.preview(empty: true)

    @Test func savesStatementTransactions() throws {
        let result = try store.save(.preview)
        #expect(result == .init(inserted: ParsedStatement.preview.transactions.count, alreadyImported: 0))
        #expect(try store.transactions().count == ParsedStatement.preview.transactions.count)
    }

    @Test func reimportingSameStatementAddsNothing() throws {
        _ = try store.save(.preview)
        let second = try store.save(.preview)
        #expect(second.inserted == 0)
        #expect(second.alreadyImported == ParsedStatement.preview.transactions.count)
        #expect(try store.transactions().count == ParsedStatement.preview.transactions.count)
    }

    @Test func roundTripKeepsTransactionData() throws {
        _ = try store.save(.preview)
        let saved = try #require(try store.transactions().first { $0.counterparty == "CINEPLEXX BH SARAJEVO" })
        #expect(saved.amount == -66)
        #expect(saved.kind == .cardPurchase)
        #expect(saved.currency == "BAM")
    }

    @Test func categoryOverrideIsUpdatedNotDuplicated() throws {
        try store.setCategory(.eatingOut, forMerchant: "KONZUM BIH")
        try store.setCategory(.shopping, forMerchant: "KONZUM BIH")
        #expect(try store.categoryOverrides() == ["KONZUM BIH": .shopping])
    }
}
