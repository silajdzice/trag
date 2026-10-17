import CoreGraphics
import Foundation

/// A line of text on a page, in display coordinates (origin top-left, y grows down).
public struct TextLine: Sendable, Hashable {
    public let text: String
    public let frame: CGRect

    public init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
    }
}

/// A page of a statement, independent of where it came from (PDF text layer, OCR, test fixture).
public protocol StatementPage: Sendable {
    /// Page size in display orientation.
    var size: CGSize { get }
    var lines: [TextLine] { get }
    /// Exact text inside a rectangle in display coordinates.
    func text(in rect: CGRect) -> String
}

public struct StatementDocument: Sendable {
    public let pages: [any StatementPage]

    public init(pages: [any StatementPage]) {
        self.pages = pages
    }

    public var allText: String {
        pages.flatMap(\.lines).map(\.text).joined(separator: "\n")
    }
}

/// One bank's statement format.
public protocol StatementParser: Sendable {
    var bankName: String { get }
    func canParse(_ document: StatementDocument) -> Bool
    func parse(_ document: StatementDocument) throws -> ParsedStatement
}

/// Picks the right parser for a document. Add new banks here.
public struct StatementParserRegistry: Sendable {
    public let parsers: [any StatementParser]

    public init(parsers: [any StatementParser] = [UnionBankaParser()]) {
        self.parsers = parsers
    }

    public func parser(for document: StatementDocument) -> (any StatementParser)? {
        parsers.first { $0.canParse(document) }
    }

    public func parse(_ document: StatementDocument) throws -> ParsedStatement {
        guard let parser = parser(for: document) else { throw StatementParsingError.unsupportedBank }
        return try parser.parse(document)
    }
}
