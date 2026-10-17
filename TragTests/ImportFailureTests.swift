import Foundation
import StatementParsing
import Testing

@testable import Trag

@Suite struct ImportFailureTests {
    @Test func unsupportedBankExplainsWhatWorks() {
        let failure = ImportFailure(StatementParsingError.unsupportedBank)
        #expect(failure.title == String(localized: "Bank not supported yet"))
    }

    @Test func unknownErrorsFallBackToGenericTitle() {
        struct Oops: Error {}
        #expect(ImportFailure(Oops()).title == String(localized: "Something went wrong"))
    }
}
