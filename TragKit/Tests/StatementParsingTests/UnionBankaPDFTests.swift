import Foundation
import Testing
@testable import StatementParsing

/// Runs only on a developer machine that has real statements in test-data/private (never committed).
@Suite struct UnionBankaPDFTests {
    static let privateDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("test-data/private")

    static var statements: [URL] {
        (try? FileManager.default.contentsOfDirectory(at: privateDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "pdf" } ?? []
    }

    @Test(.enabled(if: !statements.isEmpty, "No private statements available"), arguments: statements)
    func parsedTotalsMatchStatementFooter(url: URL) throws {
        let document = try PDFStatementLoader.load(url: url)
        let registry = StatementParserRegistry()
        #expect(registry.parser(for: document)?.bankName == "Union banka")
        let statement = try registry.parse(document)
        let totals = try #require(statement.reportedTotals)
        #expect(statement.totalDebit == totals.debit)
        #expect(statement.totalCredit == totals.credit)
        if let opening = statement.openingBalance, let closing = statement.closingBalance {
            #expect(opening + statement.totalCredit - statement.totalDebit == closing)
        }
    }
}
