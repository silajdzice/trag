#if canImport(PDFKit)
    import Foundation
    import PDFKit

    /// Reads a PDF's text layer with positions. Handles rotated pages.
    public enum PDFStatementLoader {
        public static func load(url: URL) throws -> StatementDocument {
            guard let pdf = PDFDocument(url: url) else { throw StatementParsingError.unreadableDocument }
            return load(pdf)
        }

        public static func load(data: Data) throws -> StatementDocument {
            guard let pdf = PDFDocument(data: data) else { throw StatementParsingError.unreadableDocument }
            return load(pdf)
        }

        static func load(_ pdf: PDFDocument) -> StatementDocument {
            let pages = (0..<pdf.pageCount).compactMap { pdf.page(at: $0) }.map(PDFStatementPage.init)
            return StatementDocument(pages: pages)
        }
    }

    /// `@unchecked Sendable`: PDFPage is a non-Sendable class. Each page is created and read by one import task
    /// at a time and never mutated after `init`, so sharing it across that task's executors is safe.
    struct PDFStatementPage: StatementPage, @unchecked Sendable {
        private let page: PDFPage
        let size: CGSize
        let lines: [TextLine]
        private let pageToDisplay: CGAffineTransform

        init(page: PDFPage) {
            self.page = page
            let media = page.bounds(for: .mediaBox)
            let rotated = page.rotation % 180 != 0
            size = rotated ? CGSize(width: media.height, height: media.width) : media.size
            // PDFKit's transform maps page space to display space with origin bottom-left; flip to top-left.
            let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
            pageToDisplay = page.transform(for: .mediaBox).concatenating(flip)

            let transform = pageToDisplay
            lines = (page.selection(for: media)?.selectionsByLine() ?? []).compactMap { selection in
                guard let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return TextLine(text: text, frame: selection.bounds(for: page).applying(transform))
            }
        }

        func text(in rect: CGRect) -> String {
            let pageRect = rect.applying(pageToDisplay.inverted())
            let raw = page.selection(for: pageRect)?.string ?? ""
            return
                raw
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }
#endif
