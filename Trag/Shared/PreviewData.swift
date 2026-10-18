#if DEBUG
    import Foundation
    import StatementParsing

    extension ParsedStatement {
        /// Fake data for previews and UI development.
        static let preview: ParsedStatement = {
            let calendar = Calendar.current
            func tx(_ id: String, _ month: Int, _ day: Int, _ amount: Decimal, _ who: String, _ kind: BankTransaction.Kind)
                -> BankTransaction
            {
                BankTransaction(
                    id: id,
                    bookingDate: calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .now,
                    valueDate: nil, amount: amount, currency: "BAM", kind: kind,
                    counterparty: who, description: "", reference: id)
            }
            let usd = Money(amount: 8.49, currency: "USD")
            func youtube(_ id: String, _ month: Int, _ amount: Decimal) -> BankTransaction {
                BankTransaction(
                    id: id, bookingDate: calendar.date(from: DateComponents(year: 2026, month: month, day: 15, hour: 12)) ?? .now,
                    valueDate: nil, amount: amount, currency: "BAM", kind: .cardPurchase,
                    counterparty: "GOOGLE *YouTubePremium", description: "", originalAmount: usd, reference: id)
            }
            let transactions = [
                tx("1", 9, 2, -42.30, "KONZUM BIH", .cardPurchase),
                youtube("2", 9, -14.41),
                tx("3", 9, 5, -180, "ATM 090101", .cashWithdrawal),
                tx("4", 9, 5, -1, "Union banka", .fee),
                tx("5", 9, 10, -66, "CINEPLEXX BH SARAJEVO", .cardPurchase),
                tx("6", 9, 12, -80, "VETERINARSKA STANICA", .cardPurchase),
                tx("7", 9, 21, -93.26, "JP ELEKTROPRIVREDA BIH DD SARAJEVO", .billPayment),
                tx("8", 9, 22, -218.33, "UNKNOWN SHOP DOO", .cardPurchase),
                tx("9", 9, 30, 2000, "ACME DOO", .income),
                tx("10", 8, 14, -55.10, "BINGO D.O.O.", .cardPurchase),
                youtube("12", 8, -14.65),
                tx("13", 8, 21, -70.00, "JP ELEKTROPRIVREDA BIH DD SARAJEVO", .billPayment),
                tx("11", 8, 30, 2000, "ACME DOO", .income),
                tx("14", 7, 9, -120.40, "BINGO D.O.O.", .cardPurchase),
                youtube("15", 7, -14.30),
                tx("16", 7, 21, -81.10, "JP ELEKTROPRIVREDA BIH DD SARAJEVO", .billPayment),
            ]
            return ParsedStatement(
                bankName: "Preview Bank", currency: "BAM", periodStart: nil, periodEnd: nil,
                openingBalance: nil, closingBalance: nil, transactions: transactions, reportedTotals: nil)
        }()
    }

    extension TransactionStore {
        /// In-memory store, optionally filled with `ParsedStatement.preview`.
        static func preview(empty: Bool = false) -> TransactionStore {
            do {
                let store = TransactionStore(container: try makeContainer(inMemory: true))
                if !empty { _ = try store.save(.preview) }
                return store
            } catch {
                fatalError("Preview store failed: \(error)")
            }
        }
    }

    extension LedgerModel {
        static func preview() -> LedgerModel {
            let ledger = LedgerModel(store: .preview())
            ledger.reload()
            return ledger
        }
    }
#endif
