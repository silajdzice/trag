import AICoach
import Insights
import StatementParsing
import SwiftUI

struct StatementView: View {
    let statement: ParsedStatement
    private let summary: SpendingSummary

    init(statement: ParsedStatement) {
        self.statement = statement
        summary = SpendingSummary(transactions: statement.transactions)
    }

    var body: some View {
        List {
            Section {
                AmountRow(Text("Spent"), amount: summary.totalSpent, currency: statement.currency)
                AmountRow(Text("Income"), amount: summary.totalIncome, currency: statement.currency)
                AmountRow(Text("Bank fees"), amount: summary.fees, currency: statement.currency)
                if !statement.matchesReportedTotals {
                    Label("Totals don't match the statement. Some rows may be missing.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("\(statement.bankName) · \(statement.transactions.count) transactions")
            }

            Section("Where your money went") {
                ForEach(summary.byCounterparty.prefix(8)) { line in
                    AmountRow(Text(verbatim: line.name), amount: line.total, currency: statement.currency)
                }
            }

            Section("Transactions") {
                ForEach(statement.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }

            Section {
                AIStatusLabel(availability: .current)
            }
        }
    }
}

private struct AmountRow: View {
    let title: Text
    let amount: Decimal
    let currency: String

    init(_ title: Text, amount: Decimal, currency: String) {
        self.title = title
        self.amount = amount
        self.currency = currency
    }

    var body: some View {
        LabeledContent {
            Text(amount.moneyFormatted(currency: currency)).monospacedDigit()
        } label: {
            title
        }
    }
}

private struct TransactionRow: View {
    let transaction: BankTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.counterparty).lineLimit(1)
                Text(transaction.bookingDate, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transaction.amount.moneyFormatted(currency: transaction.currency))
                .monospacedDigit()
                .foregroundStyle(transaction.isExpense ? Color.primary : Color.green)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(transaction.counterparty), \(transaction.isExpense ? "spent" : "received") \(transaction.amount.magnitude.moneyFormatted(currency: transaction.currency))"
        )
    }
}

private struct AIStatusLabel: View {
    let availability: AIAvailability

    var body: some View {
        Group {
            switch availability {
            case .available:
                Label("On-device AI available", systemImage: "sparkles")
            case .unavailable:
                Label("On-device AI unavailable. Insights still work.", systemImage: "sparkles.slash")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        StatementView(statement: .preview)
            .navigationTitle("Trag")
    }
}
