import CoreGraphics
import Foundation
import Testing

@testable import StatementParsing

/// A page built from positioned text fragments, standing in for a PDF in tests.
struct FakePage: StatementPage {
    let size = CGSize(width: 842, height: 595)
    let lines: [TextLine]

    func lines(in rect: CGRect) -> [TextLine] {
        lines.filter { rect.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
    }

    func text(in rect: CGRect) -> String {
        lines(in: rect).map(\.text).joined(separator: "\n")
    }
}

/// Places text in a Union banka column at a vertical position, like the real layout.
private func cell(_ column: KeyPath<UnionBankaLayout.Columns, Range<Double>>, _ y: Double, _ text: String) -> TextLine {
    let range = UnionBankaLayout.columns[keyPath: column]
    return TextLine(text: text, frame: CGRect(x: range.lowerBound + 2, y: y - 4, width: 40, height: 8))
}

private let header = TextLine(text: "Nalogodavac/Korisnik", frame: CGRect(x: 249, y: 180, width: 80, height: 8))

@Suite struct UnionBankaLayoutTests {
    @Test func tallBillRowDoesNotLeakIntoNeighbours() {
        let page = FakePage(lines: [
            header,
            // Card purchase: 2 lines, centred on y = 210
            cell(\.reference, 210, "100000001"), cell(\.bookingDate, 210, "02.09.2026."),
            cell(\.payee, 205, "1029999800001237"), cell(\.payee, 215, "SPARKASSE BANK D.D."),
            cell(\.description, 205, "Kupovina na POS terminalu van BC, unutar BH"),
            cell(\.description, 215, "4860271*****0000 SHOP A"),
            cell(\.debit, 210, "4,00"), cell(\.credit, 210, "0,00"),
            // Bill payment: 5 payee lines centred on y = 250
            cell(\.reference, 250, "100000002"), cell(\.bookingDate, 250, "21.09.2026."),
            cell(\.payee, 230, "1413065320199704"), cell(\.payee, 240, "WATER COMPANY DOO"),
            cell(\.payee, 250, "SARAJEVO"), cell(\.payee, 260, "SOME STREET 8"), cell(\.payee, 270, "71000 SARAJEVO"),
            cell(\.description, 250, "Racun za vodu"),
            cell(\.debit, 250, "20,30"), cell(\.credit, 250, "0,00"),
        ])

        let rows = UnionBankaLayout.rows(in: StatementDocument(pages: [page]))

        #expect(rows.count == 2)
        #expect(rows[0].description == "Kupovina na POS terminalu van BC, unutar BH\n4860271*****0000 SHOP A")
        #expect(rows[0].payee == "1029999800001237\nSPARKASSE BANK D.D.")
        #expect(rows[1].payee.hasPrefix("1413065320199704\nWATER COMPANY DOO"))
        #expect(rows[1].debit == "20,30")
    }

    @Test func rowSplitAcrossPagesIsJoined() throws {
        let first = FakePage(lines: [
            header,
            cell(\.reference, 560, "100000001"), cell(\.bookingDate, 560, "02.09.2026."),
            cell(\.payee, 555, "1029999800001237"),
            cell(\.description, 555, "Kupovina na POS terminalu van BC, unutar BH"),
            cell(\.debit, 560, "4,00"), cell(\.credit, 560, "0,00"),
        ])
        let second = FakePage(lines: [
            // Continuation of the previous row, printed at the top of the next page
            cell(\.payee, 40, "SPARKASSE BANK D.D."),
            cell(\.description, 40, "4860271*****0000 SHOP A"),
            // Next row
            cell(\.reference, 70, "100000002"), cell(\.bookingDate, 70, "03.09.2026."),
            cell(\.payee, 65, "1029999800001237"), cell(\.payee, 75, "SPARKASSE BANK D.D."),
            cell(\.description, 65, "Kupovina na POS terminalu van BC, unutar BH"),
            cell(\.description, 75, "4860271*****0000 SHOP B"),
            cell(\.debit, 70, "6,00"), cell(\.credit, 70, "0,00"),
        ])

        let rows = UnionBankaLayout.rows(in: StatementDocument(pages: [first, second]))
        let transactions = UnionBankaInterpreter.transactions(from: rows, currency: "BAM")

        #expect(transactions.map(\.counterparty) == ["SHOP A", "SHOP B"])
        #expect(transactions.map(\.amount) == [-4, -6])
    }
}
