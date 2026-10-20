import AICoach
import SwiftUI

struct RootView: View {
    @State private var ledger: LedgerModel
    @State private var importModel: StatementImportModel
    @State private var askModel: AskMoneyModel?
    @State private var aiSettings: AISettings

    init(store: TransactionStore, aiSettings: AISettings = AISettings()) {
        let ledger = LedgerModel(store: store)
        ledger.useEngine(aiSettings.selectedEngine)
        _ledger = State(initialValue: ledger)
        _importModel = State(initialValue: StatementImportModel(store: store))
        _aiSettings = State(initialValue: aiSettings)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text(verbatim: "Trag"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            AISettingsView(settings: aiSettings)
                        } label: {
                            Label("AI settings", systemImage: "gearshape")
                        }
                    }
                    if !ledger.isEmpty, let engine = aiSettings.selectedEngine {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Ask your money", systemImage: "sparkles") {
                                askModel = AskMoneyModel(queries: ledger.queries, engine: engine)
                            }
                        }
                    }
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
                await ledger.suggestCategories()
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
        .sheet(item: $askModel) { model in
            AskMoneyView(model: model)
        }
        .task {
            ledger.reload()
            await ledger.suggestCategories()
        }
        .onChange(of: aiSettings.selection) {
            ledger.useEngine(aiSettings.selectedEngine)
            Task { await ledger.suggestCategories() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if case .importing = importModel.state {
            ProgressView("Reading statement…")
        } else if case .failed(let failure) = importModel.state, ledger.isEmpty {
            ImportFailureView(failure: failure) { importModel.isPickerPresented = true }
        } else if ledger.isEmpty {
            ImportPromptView {
                importModel.isPickerPresented = true
            } onTryDemo: {
                importModel.importDemoData()
                ledger.reload()
                Task { await ledger.suggestCategories() }
            }
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
