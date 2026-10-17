#if DEBUG
    import Foundation
    import StatementParsing

    extension ParsedStatement {
        /// Fake data for SwiftUI previews.
        static let preview: ParsedStatement = {
            func tx(_ id: String, _ day: Int, _ amount: Decimal, _ who: String, _ kind: BankTransaction.Kind) -> BankTransaction {
                BankTransaction(
                    id: id,
                    bookingDate: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day)) ?? .now,
                    valueDate: nil,
                    amount: amount,
                    currency: "BAM",
                    kind: kind,
                    counterparty: who,
                    description: "",
                    reference: id
                )
            }
            let transactions = [
                tx("1", 2, -42.30, "KONZUM BIH", .cardPurchase),
                tx("2", 3, -14.41, "YouTube Premium", .cardPurchase),
                tx("3", 5, -180, "ATM", .cashWithdrawal),
                tx("4", 5, -1, "Union banka", .fee),
                tx("5", 21, -93.26, "Elektroprivreda BiH", .billPayment),
                tx("6", 30, 2000, "ACME DOO", .income),
            ]
            return ParsedStatement(
                bankName: "Union banka",
                currency: "BAM",
                periodStart: nil,
                periodEnd: nil,
                openingBalance: 1000,
                closingBalance: 2668.03,
                transactions: transactions,
                reportedTotals: (debit: 330.97, credit: 2000)
            )
        }()
    }
#endif
