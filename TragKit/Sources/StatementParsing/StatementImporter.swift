import Foundation

/// Loads a statement file and parses it with the matching bank parser, off the main actor.
public struct StatementImporter: Sendable {
    private let registry: StatementParserRegistry

    public init(registry: StatementParserRegistry = StatementParserRegistry()) {
        self.registry = registry
    }

    @concurrent
    public func importStatement(from url: URL) async throws -> ParsedStatement {
        #if canImport(PDFKit)
            let document = try PDFStatementLoader.load(url: url)
            return try registry.parse(document)
        #else
            throw StatementParsingError.unreadableDocument
        #endif
    }
}
