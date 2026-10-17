import SwiftUI

struct RootView: View {
    @State private var ledger: LedgerModel
    @State private var importModel: StatementImportModel

    init(store: TransactionStore) {
        _ledger = State(initialValue: LedgerModel(store: store))
        _importModel = State(initialValue: StatementImportModel(store: store))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text(verbatim: "Trag"))
                .toolbar {
                    if !ledger.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Import statement", systemImage: "square.and.arrow.down") {
                                importModel.isPickerPresented = true
                            }
                        }
                    }
                }
        }
        .fileImporter(isPresented: $importModel.isPickerPresented, allowedContentTypes: [.pdf]) { result in
            Task {
                await importModel.importFile(result)
                ledger.reload()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if case .finished(let outcome) = importModel.state {
                ImportOutcomeBanner(outcome: outcome) { importModel.dismissOutcome() }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: outcome) {
                        // Successful imports confirm briefly; warnings stay until dismissed.
                        guard outcome.totalsMatch else { return }
                        try? await Task.sleep(for: .seconds(4))
                        importModel.dismissOutcome()
                    }
            }
        }
        .animation(.default, value: importModel.state)
        .task { ledger.reload() }
    }

    @ViewBuilder
    private var content: some View {
        if case .importing = importModel.state {
            ProgressView("Reading statement…")
        } else if case .failed(let failure) = importModel.state, ledger.isEmpty {
            ImportFailureView(failure: failure) { importModel.isPickerPresented = true }
        } else if ledger.isEmpty {
            ImportPromptView { importModel.isPickerPresented = true }
        } else {
            MonthOverviewView(ledger: ledger)
        }
    }
}

#Preview("With data") {
    RootView(store: .preview())
}

#Preview("Empty") {
    RootView(store: .preview(empty: true))
}
