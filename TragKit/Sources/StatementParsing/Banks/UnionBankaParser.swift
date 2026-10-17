import CoreGraphics
import Foundation

/// Union banka d.d. Sarajevo, monthly account statement ("Izvod") PDF.
/// Format notes: docs/union-banka-format.md
public struct UnionBankaParser: StatementParser {
    public let bankName = "Union banka"

    public init() {}

    public func canParse(_ document: StatementDocument) -> Bool {
        let text = document.pages.first?.lines.prefix(30).map(\.text).joined(separator: " ") ?? ""
        return text.localizedCaseInsensitiveContains("Union banka")
            && text.localizedCaseInsensitiveContains("Iznos duguje")
    }

    public func parse(_ document: StatementDocument) throws -> ParsedStatement {
        let rows = UnionBankaLayout.rows(in: document)
        guard !rows.isEmpty else { throw StatementParsingError.noTransactionsFound }
        let header = UnionBankaLayout.header(in: document)
        let currency = header.currency
        return ParsedStatement(
            bankName: bankName,
            currency: currency,
            periodStart: header.periodStart,
            periodEnd: header.periodEnd,
            openingBalance: header.openingBalance,
            closingBalance: header.closingBalance,
            transactions: UnionBankaInterpreter.transactions(from: rows, currency: currency),
            reportedTotals: header.totals
        )
    }
}

/// One table row as printed, before interpretation.
public struct UnionBankaRow: Sendable, Hashable {
    public var reference: String
    public var bookingDate: String
    public var valueDate: String
    public var payee: String
    public var description: String
    public var debit: String
    public var credit: String

    public init(reference: String, bookingDate: String, valueDate: String, payee: String, description: String, debit: String, credit: String) {
        self.reference = reference
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.payee = payee
        self.description = description
        self.debit = debit
        self.credit = credit
    }
}

// MARK: - Layout: positions → rows

enum UnionBankaLayout {
    /// Column x-ranges in display points (landscape A4, 842 pt wide).
    struct Columns {
        let reference = 80.0..<138.0
        let bookingDate = 138.0..<195.0
        let valueDate = 195.0..<247.0
        let payee = 247.0..<392.0
        let description = 392.0..<598.0
        let debit = 598.0..<668.0
        let credit = 668.0..<842.0
    }

    static let columns = Columns()
    private static var referencePattern: Regex<Substring> { /^\d{6,12}\b/ }

    static func rows(in document: StatementDocument) -> [UnionBankaRow] {
        var rows: [UnionBankaRow] = []
        for page in document.pages {
            let anchors = page.lines
                .filter { $0.frame.minX < columns.reference.upperBound && $0.text.firstMatch(of: referencePattern) != nil }
                .map(\.frame.midY)
                .sorted()
            guard !anchors.isEmpty else { continue }

            let headerBottom = page.lines.first { $0.text.contains("Nalogodavac") }.map { $0.frame.maxY + 8 } ?? 40
            let footerTop = page.lines.first { $0.text.hasPrefix("Ukupno") }?.frame.minY ?? page.size.height - 25

            for (index, y) in anchors.enumerated() {
                let previous = index > 0 ? (anchors[index - 1] + y) / 2 : max(headerBottom, y - 30)
                let next = index < anchors.count - 1 ? (anchors[index + 1] + y) / 2 : min(footerTop - 1, y + 25)
                let band = previous..<next

                func cell(_ x: Range<Double>) -> String {
                    page.text(in: CGRect(x: x.lowerBound, y: band.lowerBound, width: x.upperBound - x.lowerBound, height: band.upperBound - band.lowerBound))
                }

                let reference = cell(columns.reference).firstMatch(of: referencePattern).map { String($0.output) } ?? ""
                rows.append(UnionBankaRow(
                    reference: reference,
                    bookingDate: cell(columns.bookingDate),
                    valueDate: cell(columns.valueDate),
                    payee: cell(columns.payee),
                    description: cell(columns.description),
                    debit: cell(columns.debit),
                    credit: cell(columns.credit)
                ))
            }
        }
        return rows
    }

    struct Header {
        var currency = "BAM"
        var openingBalance: Decimal?
        var closingBalance: Decimal?
        var periodStart: Date?
        var periodEnd: Date?
        var totals: (debit: Decimal, credit: Decimal)?
    }

    static func header(in document: StatementDocument) -> Header {
        var header = Header()
        let numberPattern = /\d{1,3}(?:\.\d{3})*,\d{2}/

        if let first = document.pages.first {
            if let line = first.lines.first(where: { $0.text.hasPrefix("Prethodno stanje") }) {
                let text = first.text(in: CGRect(x: line.frame.minX, y: line.frame.minY - 2, width: first.size.width - line.frame.minX, height: line.frame.height + 4))
                header.openingBalance = text.firstMatch(of: numberPattern).flatMap { LocalFormat.decimal(String($0.output)) }
            }
            if first.lines.contains(where: { $0.text.contains("EUR") && $0.text.hasPrefix("VALUTA") }) { header.currency = "EUR" }
        }

        for page in document.pages {
            if let line = page.lines.first(where: { $0.text.hasPrefix("Ukupno") }) {
                let band = CGRect(x: 0, y: line.frame.minY - 3, width: page.size.width, height: line.frame.height + 6)
                let debit = page.text(in: band.intersection(rect(columns.debit, page))).firstMatch(of: numberPattern)
                let credit = page.text(in: band.intersection(rect(columns.credit, page))).firstMatch(of: numberPattern)
                if let debit = debit.flatMap({ LocalFormat.decimal(String($0.output)) }),
                   let credit = credit.flatMap({ LocalFormat.decimal(String($0.output)) }) {
                    header.totals = (debit, credit)
                }
            }
            if let line = page.lines.first(where: { $0.text.hasPrefix("Saldo") }) {
                let text = page.text(in: CGRect(x: line.frame.minX, y: line.frame.minY - 2, width: page.size.width - line.frame.minX, height: line.frame.height + 4))
                header.closingBalance = text.firstMatch(of: numberPattern).flatMap { LocalFormat.decimal(String($0.output)) }
            }
            let allText = page.lines.map(\.text).joined(separator: " ")
            if let match = allText.firstMatch(of: /period od (\d{2}\.\d{2}\.\d{4})\.? do (\d{2}\.\d{2}\.\d{4})/) {
                header.periodStart = LocalFormat.date(String(match.output.1))
                header.periodEnd = LocalFormat.date(String(match.output.2))
            }
        }
        return header
    }

    private static func rect(_ x: Range<Double>, _ page: any StatementPage) -> CGRect {
        CGRect(x: x.lowerBound, y: 0, width: x.upperBound - x.lowerBound, height: page.size.height)
    }
}

// MARK: - Interpretation: rows → transactions (pure, unit-tested)

public enum UnionBankaInterpreter {
    private static var maskedCard: Regex<Substring> { /\d{4,6}\*+\d{2,4}/ }
    private static var originalAmount: Regex<(Substring, Substring, Substring)> { /\((\d+(?:\.\d+)?) ([A-Z]{3})\)/ }
    private static var accountNumber: Regex<Substring> { /^\d{13,16}$/ }

    public static func transactions(from rows: [UnionBankaRow], currency: String) -> [Transaction] {
        var seen: [String: Int] = [:]
        let referenceCounts = Dictionary(grouping: rows, by: \.reference).mapValues(\.count)

        return rows.compactMap { row in
            let debit = firstAmount(in: row.debit) ?? 0
            let credit = firstAmount(in: row.credit) ?? 0
            guard debit != 0 || credit != 0, let bookingDate = LocalFormat.date(row.bookingDate) else { return nil }

            let description = LocalFormat.collapseWhitespace(row.description.replacingOccurrences(of: "\n", with: " "))
            let payeeLines = row.payee.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let payeeName = payeeLines.firstIndex(where: { $0.firstMatch(of: accountNumber) != nil })
                .flatMap { payeeLines.indices.contains($0 + 1) ? payeeLines[$0 + 1] : nil }
                ?? payeeLines.first ?? ""

            var kind = kind(description: description, credit: credit)
            // Bill payments come with a second, small row under the same reference: the bank's fee.
            if kind == .billPayment, (referenceCounts[row.reference] ?? 0) > 1, debit <= 1 { kind = .fee }

            let counterparty: String = switch kind {
            case .cardPurchase, .cashWithdrawal: merchant(from: description) ?? payeeName
            case .fee: "Union banka"
            default: payeeName
            }

            let original = description.firstMatch(of: originalAmount).flatMap { match -> Money? in
                guard let amount = Decimal(string: String(match.output.1), locale: Locale(identifier: "en_US_POSIX")) else { return nil }
                return Money(amount: amount, currency: String(match.output.2))
            }

            let occurrence = seen[row.reference, default: 0]
            seen[row.reference] = occurrence + 1

            return Transaction(
                id: occurrence == 0 ? row.reference : "\(row.reference)-\(occurrence)",
                bookingDate: bookingDate,
                valueDate: LocalFormat.date(row.valueDate),
                amount: credit - debit,
                currency: currency,
                kind: kind,
                counterparty: counterparty,
                description: description,
                originalAmount: kind == .fee ? nil : original,
                reference: row.reference
            )
        }
    }

    static func kind(description: String, credit: Decimal) -> Transaction.Kind {
        if description.hasPrefix("Naknada") { return .fee }
        if description.contains("Podizanje gotovine") { return .cashWithdrawal }
        if description.contains("Kupovina na POS") { return .cardPurchase }
        if credit > 0 { return .income }
        return .billPayment
    }

    /// "Kupovina na POS terminalu van BH 4860271*****0000 Battle.net (12.99 EUR)" → "Battle.net"
    static func merchant(from description: String) -> String? {
        guard let card = description.firstMatch(of: maskedCard) else { return nil }
        var rest = String(description[card.range.upperBound...])
        if let amount = rest.firstMatch(of: originalAmount) { rest.removeSubrange(amount.range) }
        let name = rest.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func firstAmount(in text: String) -> Decimal? {
        text.firstMatch(of: /\d{1,3}(?:\.\d{3})*,\d{2}/).flatMap { LocalFormat.decimal(String($0.output)) }
    }
}
