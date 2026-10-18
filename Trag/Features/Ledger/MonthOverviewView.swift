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
                    SpentHeader(summary: summary, change: ledger.changeFromPreviousMonth, currency: currency)
                    AmountRow(Text("Income"), amount: summary.totalIncome, currency: currency)
                } footer: {
                    Text("\(ledger.monthTransactions.count) transactions")
                }
                .id(month)

                Section("Categories") {
                    if ledger.isSuggestingCategories {
                        ProgressView("Categorizing new shops on this iPhone…")
                            .font(.footnote)
                    }
                    CategoryDonutChart(lines: summary.byCategory, total: summary.totalSpent, currency: currency)
                    ForEach(summary.byCategory) { line in
                        CategoryRow(line: line, share: summary.share(of: line), currency: currency)
                    }
                }

                if ledger.history.count > 1 {
                    Section("Spending by month") {
                        MonthlyTrendChart(history: ledger.history, selected: month, currency: currency)
                    }
                }

                if !ledger.recurringPayments.isEmpty {
                    Section {
                        ForEach(ledger.recurringPayments.prefix(3)) { RecurringPaymentRow(payment: $0) }
                        NavigationLink {
                            RecurringPaymentsView(payments: ledger.recurringPayments)
                        } label: {
                            Text("See all")
                        }
                    } header: {
                        Text("Subscriptions & bills")
                    } footer: {
                        Text("\(ledger.recurringMonthlyTotal.moneyFormatted(currency: currency)) per month")
                    }
                }

                if let forecast = ledger.forecast {
                    ForecastSection(forecast: forecast, currency: currency)
                }

                if ledger.canGenerateTips {
                    TipsSection(tips: ledger.tips[month], isLoading: ledger.isLoadingTips) {
                        Task { await ledger.loadTips(for: month) }
                    }
                }

                Section("Top places") {
                    ForEach(summary.byMerchant.prefix(5)) { line in
                        AmountRow(Text(verbatim: line.key), amount: line.total, currency: currency)
                    }
                }

                Section("Transactions") {
                    ForEach(ledger.monthTransactions) { transaction in
                        let row = TransactionRow(
                            transaction: transaction,
                            category: ledger.category(for: transaction),
                            isAISuggested: ledger.categorySource(for: transaction) == .ai)
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

/// The month's total, large, with the change against the previous month.
private struct SpentHeader: View {
    let summary: SpendingSummary
    let change: Double?
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(summary.totalSpent.moneyFormatted(currency: currency))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let change {
                changeLabel(change)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func changeLabel(_ change: Double) -> some View {
        let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
        if abs(change) < 0.005 {
            Label("Same as last month", systemImage: "equal")
                .foregroundStyle(.secondary)
        } else if change > 0 {
            Label("\(percent) more than last month", systemImage: "arrow.up.right")
                .foregroundStyle(.orange)
        } else {
            Label("\(percent) less than last month", systemImage: "arrow.down.right")
                .foregroundStyle(.green)
        }
    }
}

private struct ForecastSection: View {
    let forecast: SpendingForecast
    let currency: String

    var body: some View {
        Section {
            LabeledContent {
                Text(forecast.total.moneyFormatted(currency: currency))
                    .font(.headline)
                    .monospacedDigit()
            } label: {
                Text("Expected spending")
                Text(forecast.month.startDate(), format: .dateTime.month(.wide).year())
            }
            AmountRow(Text("Subscriptions & bills"), amount: forecast.recurring, currency: currency)
            AmountRow(Text("Everything else"), amount: forecast.variable, currency: currency)
        } header: {
            Text("Next month")
        } footer: {
            Text("Estimate based on \(forecast.basedOnMonths) months of history.")
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

private struct TipsSection: View {
    let tips: [SavingTip]?
    let isLoading: Bool
    let onGenerate: () -> Void

    var body: some View {
        Section {
            if let tips, !tips.isEmpty {
                ForEach(tips, id: \.self) { tip in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title).font(.headline)
                        Text(tip.detail).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } else if isLoading {
                ProgressView("Thinking…")
            } else {
                Button(action: onGenerate) {
                    Label("Get 3 tips for this month", systemImage: "sparkles")
                }
                if tips?.isEmpty == true {
                    Text("Couldn't write tips this time. Try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Savings tips")
        } footer: {
            Text("Written by the on-device AI from your numbers.")
        }
    }
}

#Preview {
    NavigationStack {
        MonthOverviewView(ledger: .preview())
    }
}
