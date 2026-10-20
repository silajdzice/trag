import Foundation
import StatementParsing

/// Three made-up months of a Sarajevo household, so anyone can try Trag without a real bank statement.
/// Deterministic: the same data every time, so screenshots and demos are reproducible.
enum DemoData {
    static let bankName = "Demo Bank"

    /// One statement per month, ending with the month before `now`.
    static func statements(endingBefore now: Date = .now, calendar: Calendar = .current) -> [ParsedStatement] {
        let lastMonthStart =
            calendar.date(byAdding: .month, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now)
            ?? now
        return (0..<3).reversed().map { offset in
            let monthStart = calendar.date(byAdding: .month, value: -offset, to: lastMonthStart) ?? lastMonthStart
            return statement(for: monthStart, index: 2 - offset, calendar: calendar)
        }
    }

    private struct Entry {
        let day: Int
        let amount: Decimal
        let counterparty: String
        let kind: BankTransaction.Kind
        var original: Money? = nil
    }

    private static func statement(for monthStart: Date, index: Int, calendar: Calendar) -> ParsedStatement {
        // Small, deterministic month-to-month variation so trends and comparisons are visible.
        let factor = [Decimal(1.12), Decimal(1.05), Decimal(0.86)][index]
        func vary(_ amount: Decimal) -> Decimal { (amount * factor).rounded(scale: 2) }

        var entries: [Entry] = [
            Entry(day: 1, amount: 2850, counterparty: "ACME SOFTWARE DOO", kind: .income),
            Entry(day: 3, amount: -vary(64.20), counterparty: "BINGO D.O.O. SARAJEVO", kind: .cardPurchase),
            Entry(day: 5, amount: -150, counterparty: "KJKP TOPLANE - SARAJEVO D.O.O.", kind: .billPayment),
            Entry(day: 5, amount: -0.75, counterparty: "Demo Bank", kind: .fee),
            Entry(day: 6, amount: -vary(87.40), counterparty: "JP ELEKTROPRIVREDA BIH DD SARAJEVO", kind: .billPayment),
            Entry(day: 6, amount: -0.75, counterparty: "Demo Bank", kind: .fee),
            Entry(day: 6, amount: -67.45, counterparty: "TELEMACH DOO SARAJEVO", kind: .billPayment),
            Entry(day: 7, amount: -vary(23.10), counterparty: "KJKP VODOVOD I KANALIZACIJA DOO", kind: .billPayment),
            Entry(day: 8, amount: -200, counterparty: "ATM SARAJEVO CENTAR", kind: .cashWithdrawal),
            Entry(day: 8, amount: -1, counterparty: "Demo Bank", kind: .fee),
            Entry(day: 9, amount: -vary(41.85), counterparty: "KONZUM BIH K001", kind: .cardPurchase),
            Entry(
                day: 10, amount: -14.41, counterparty: "GOOGLE *YouTubePremium", kind: .cardPurchase,
                original: Money(amount: 8.49, currency: "USD")),
            Entry(day: 11, amount: -vary(32.50), counterparty: "PIZZERIA MASLINA", kind: .cardPurchase),
            Entry(day: 12, amount: -vary(55.00), counterparty: "ZOO CENTAR D.O.O.", kind: .cardPurchase),
            Entry(day: 13, amount: -vary(48.30), counterparty: "POS 0035 DM SA", kind: .cardPurchase),
            Entry(day: 14, amount: -vary(118.65), counterparty: "BINGO D.O.O. SARAJEVO", kind: .cardPurchase),
            Entry(
                day: 15, amount: -5.85, counterparty: "APPLE.COM/BILL", kind: .cardPurchase,
                original: Money(amount: 2.99, currency: "EUR")),
            Entry(day: 16, amount: -vary(60.00), counterparty: "CINEPLEXX BH SARAJEVO", kind: .cardPurchase),
            Entry(day: 17, amount: -vary(75.00), counterparty: "PETROL BENZINSKA PUMPA", kind: .cardPurchase),
            Entry(day: 18, amount: -36.45, counterparty: "BH Telecom dd Sarajevo", kind: .billPayment),
            Entry(day: 19, amount: -vary(27.80), counterparty: "FAST FOOD SAC", kind: .cardPurchase),
            Entry(day: 20, amount: -vary(94.20), counterparty: "MONIS APOTEKA", kind: .cardPurchase),
            Entry(day: 21, amount: -vary(133.40), counterparty: "AMKO KOMERC D.O.O.", kind: .cardPurchase),
            Entry(day: 22, amount: -vary(69.90), counterparty: "DEICHMANN OBUCA", kind: .cardPurchase),
            Entry(day: 23, amount: -vary(35.00), counterparty: "IGRAONICA BALONI", kind: .cardPurchase),
            Entry(day: 24, amount: -vary(120.00), counterparty: "VETERINARSKA STANICA", kind: .cardPurchase),
            Entry(day: 25, amount: -vary(22.60), counterparty: "PEKARA SAC", kind: .cardPurchase),
            Entry(day: 26, amount: -2.50, counterparty: "MOJ PARKING SA", kind: .cardPurchase),
            Entry(day: 27, amount: -vary(58.75), counterparty: "SOLIDEX D.O.O.", kind: .cardPurchase),
            Entry(day: 28, amount: -vary(46.10), counterparty: "BINGO D.O.O. SARAJEVO", kind: .cardPurchase),
            Entry(day: 28, amount: -8.99, counterparty: "Demo Bank", kind: .fee),
        ]
        if index == 1 {
            entries.append(Entry(day: 18, amount: -219.00, counterparty: "JYSK SARAJEVO", kind: .cardPurchase))
        }

        let components = calendar.dateComponents([.year, .month], from: monthStart)
        let transactions = entries.enumerated().map { offset, entry in
            BankTransaction(
                id: String(format: "demo-%04d%02d-%03d", components.year ?? 0, components.month ?? 0, offset),
                bookingDate: calendar.date(
                    from: DateComponents(year: components.year, month: components.month, day: entry.day, hour: 12)) ?? monthStart,
                valueDate: nil, amount: entry.amount, currency: "BAM", kind: entry.kind,
                counterparty: entry.counterparty, description: "", originalAmount: entry.original,
                reference: String(format: "demo-%04d%02d-%03d", components.year ?? 0, components.month ?? 0, offset))
        }
        let debit = transactions.filter(\.isExpense).reduce(Decimal.zero) { $0 - $1.amount }
        let credit = transactions.filter { !$0.isExpense }.reduce(Decimal.zero) { $0 + $1.amount }
        return ParsedStatement(
            bankName: bankName, currency: "BAM", periodStart: monthStart, periodEnd: nil,
            openingBalance: nil, closingBalance: nil, transactions: transactions, reportedTotals: (debit, credit))
    }
}
