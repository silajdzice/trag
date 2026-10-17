import AICoach
import Insights
import StatementParsing
import SwiftUI

struct MonthOverviewView: View {
    @Bindable var ledger: LedgerModel
    @State private var editingTransaction: BankTransaction?

    var body: some View {
        List {
            if let summary = ledger.summary, let month = ledger.selectedMonth {
                Section {
                    MonthPicker(months: ledger.months, selection: $ledger.selectedMonth)
                    AmountRow(Text("Spent"), amount: summary.totalSpent, currency: currency)
                    AmountRow(Text("Income"), amount: summary.totalIncome, currency: currency)
                } footer: {
                    Text("\(ledger.monthTransactions.count) transactions")
                }
                .id(month)

                Section("Categories") {
                    ForEach(summary.byCategory) { line in
                        CategoryRow(line: line, share: summary.share(of: line), currency: currency)
                    }
                }

                Section("Top places") {
                    ForEach(summary.byMerchant.prefix(5)) { line in
                        AmountRow(Text(verbatim: line.key), amount: line.total, currency: currency)
                    }
                }

                Section("Transactions") {
                    ForEach(ledger.monthTransactions) { transaction in
                        let row = TransactionRow(transaction: transaction, category: ledger.category(for: transaction))
                        if ledger.canChangeCategory(of: transaction) {
                            Button {
                                editingTransaction = transaction
                            } label: {
                                row
                            }
                            .tint(.primary)
                            .accessibilityHint(Text("Change category"))
                        } else {
                            row
                        }
                    }
                }
            }

            Section {
                AIStatusLabel()
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            CategoryPickerView(
                merchant: transaction.counterparty,
                selection: ledger.category(for: transaction)
            ) { category in
                ledger.setCategory(category, for: transaction)
            }
        }
    }

    private var currency: String {
        ledger.monthTransactions.first?.currency ?? "BAM"
    }
}

private struct MonthPicker: View {
    let months: [Month]
    @Binding var selection: Month?

    var body: some View {
        Picker("Month", selection: $selection) {
            ForEach(months) { month in
                Text(month.startDate(), format: .dateTime.month(.wide).year())
                    .tag(Optional(month))
            }
        }
    }
}

private struct CategoryRow: View {
    let line: SpendingSummary.Line<SpendingCategory>
    let share: Double
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: line.key.systemImage)
                .foregroundStyle(line.key.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(line.key.title)
                    Spacer()
                    Text(line.total.moneyFormatted(currency: currency))
                        .monospacedDigit()
                }
                ProgressView(value: share)
                    .tint(line.key.tint)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(share, format: .percent.precision(.fractionLength(0))))
    }
}

struct AmountRow: View {
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

private struct AIStatusLabel: View {
    var body: some View {
        Group {
            switch AIAvailability.current {
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
        MonthOverviewView(ledger: .preview())
    }
}
