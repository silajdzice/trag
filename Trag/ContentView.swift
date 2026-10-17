import AICoach
import Insights
import StatementParsing
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var statement: ParsedStatement?
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let statement {
                    StatementView(statement: statement)
                } else {
                    ContentUnavailableView {
                        Label("No statement yet", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Import a bank statement PDF. Everything stays on this iPhone.")
                    } actions: {
                        Button("Import statement") { isImporting = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Trag")
            .toolbar {
                if statement != nil {
                    Button("Import", systemImage: "square.and.arrow.down") { isImporting = true }
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf]) { result in
                importStatement(result)
            }
            .alert("Couldn't read statement", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importStatement(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let document = try PDFStatementLoader.load(url: url)
            statement = try StatementParserRegistry().parse(document)
        } catch StatementParsingError.unsupportedBank {
            errorMessage = "This bank isn't supported yet. Union banka statements work today."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct StatementView: View {
    let statement: ParsedStatement
    private var summary: SpendingSummary { SpendingSummary(transactions: statement.transactions) }

    var body: some View {
        List {
            Section {
                LabeledContent("Spent", value: format(summary.totalSpent))
                LabeledContent("Income", value: format(summary.totalIncome))
                LabeledContent("Bank fees", value: format(summary.fees))
                if !statement.matchesReportedTotals {
                    Label("Totals don't match the statement. Some rows may be missing.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("\(statement.bankName) · \(statement.transactions.count) transactions")
            }

            Section("Where your money went") {
                ForEach(summary.byCounterparty.prefix(8)) { line in
                    LabeledContent(line.name, value: format(line.total))
                }
            }

            Section("Transactions") {
                ForEach(statement.transactions) { transaction in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(transaction.counterparty).lineLimit(1)
                            Text(transaction.bookingDate, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(format(transaction.amount))
                            .monospacedDigit()
                            .foregroundStyle(transaction.isExpense ? Color.primary : Color.green)
                    }
                }
            }

            Section {
                switch AIAvailability.current {
                case .available: Label("On-device AI available", systemImage: "sparkles")
                case .unavailable: Label("On-device AI unavailable: insights still work", systemImage: "sparkles.slash")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func format(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: statement.currency).locale(Locale(identifier: "bs_BA")))
    }
}

#Preview {
    ContentView()
}
