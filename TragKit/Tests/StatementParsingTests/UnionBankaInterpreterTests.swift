import Foundation
import Testing
@testable import StatementParsing

/// Sanitized rows: same structure as a real Union banka statement, fake personal data.
private let rows: [UnionBankaRow] = [
    .init(reference: "100000001", bookingDate: "02.09.2026.", valueDate: "31.08.2026.",
          payee: "1029999800001237\nSPARKASSE BANK D.D.",
          description: "Kupovina na POS terminalu van BC, unutar BH\n4860271*****0000 KONZUM BIH P-242",
          debit: "4,00", credit: "0,00"),
    .init(reference: "100000002", bookingDate: "07.09.2026.", valueDate: "02.09.2026.",
          payee: "1029999800001237\nSPARKASSE BANK D.D.",
          description: "Kupovina na POS terminalu van BH 4860271*****0000\nBattle.net (12.99 EUR)",
          debit: "25,41", credit: "0,00"),
    .init(reference: "100000003", bookingDate: "07.09.2026.", valueDate: "02.09.2026.",
          payee: "1000000000000001\nJOHN DOE",
          description: "Naknada za VISA konverziju - Kupovina na POS\nterminalu van BH 4860271*****0000 (12.99 EUR)",
          debit: "0,25", credit: "0,00"),
    .init(reference: "100000004", bookingDate: "02.09.2026.", valueDate: "01.09.2026.",
          payee: "1000000000000001\nJOHN DOE",
          description: "Podizanje gotovine na ATM-u BH mreža\n4860271*****0000 ATM 090101 AMKO KOMERC NC",
          debit: "180,00", credit: "0,00"),
    .init(reference: "100000005", bookingDate: "21.09.2026.", valueDate: "21.09.2026.",
          payee: "1413065320199704\nKJKP VODOVOD I KANALIZACIJA DOO\nSARAJEVO",
          description: "00000000-000000-0 Racun za vodu", debit: "20,30", credit: "0,00"),
    .init(reference: "100000005", bookingDate: "21.09.2026.", valueDate: "21.09.2026.",
          payee: "1413065320199704\nKJKP VODOVOD I KANALIZACIJA DOO\nSARAJEVO",
          description: "00000000-000000-0 Racun za vodu", debit: "0,75", credit: "0,00"),
    .init(reference: "100000006", bookingDate: "30.09.2026.", valueDate: "30.09.2026.",
          payee: "1610000000000001\nACME DOO\nSARAJEVO",
          description: "PLACA ZA 9 2026", debit: "0,00", credit: "2.000,00"),
]

@Suite struct UnionBankaInterpreterTests {
    let transactions = UnionBankaInterpreter.transactions(from: rows, currency: "BAM")

    @Test func parsesAllRows() {
        #expect(transactions.count == 7)
    }

    @Test func domesticCardPurchase() throws {
        let t = try #require(transactions.first)
        #expect(t.kind == .cardPurchase)
        #expect(t.counterparty == "KONZUM BIH P-242")
        #expect(t.amount == -4)
    }

    @Test func foreignCardPurchaseKeepsOriginalAmount() {
        let t = transactions[1]
        #expect(t.counterparty == "Battle.net")
        #expect(t.originalAmount == Money(amount: Decimal(string: "12.99")!, currency: "EUR"))
        #expect(t.amount == Decimal(string: "-25.41"))
    }

    @Test func conversionFeeIsFee() {
        #expect(transactions[2].kind == .fee)
        #expect(transactions[2].originalAmount == nil)
    }

    @Test func atmWithdrawal() {
        #expect(transactions[3].kind == .cashWithdrawal)
        #expect(transactions[3].counterparty == "ATM 090101 AMKO KOMERC NC")
    }

    @Test func billPaymentAndItsFeeShareReference() {
        #expect(transactions[4].kind == .billPayment)
        #expect(transactions[4].counterparty == "KJKP VODOVOD I KANALIZACIJA DOO")
        #expect(transactions[5].kind == .fee)
        #expect(transactions[4].id != transactions[5].id)
    }

    @Test func salaryIsIncome() {
        #expect(transactions[6].kind == .income)
        #expect(transactions[6].amount == 2000)
        #expect(transactions[6].counterparty == "ACME DOO")
    }

    @Test(arguments: [("1.234,56", "1234.56"), ("4,00", "4"), ("0,06", "0.06")])
    func localNumberFormat(input: String, expected: String) {
        #expect(LocalFormat.decimal(input) == Decimal(string: expected))
    }
}
