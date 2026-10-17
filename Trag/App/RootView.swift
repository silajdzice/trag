import SwiftUI

struct RootView: View {
    @State private var importModel = StatementImportModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Trag")
                .toolbar {
                    if case .loaded = importModel.state {
                        Button("Import statement", systemImage: "square.and.arrow.down") {
                            importModel.isPickerPresented = true
                        }
                    }
                }
                .fileImporter(isPresented: $importModel.isPickerPresented, allowedContentTypes: [.pdf]) { result in
                    Task { await importModel.importFile(result) }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch importModel.state {
        case .empty:
            ImportPromptView { importModel.isPickerPresented = true }
        case .importing:
            ProgressView("Reading statement…")
        case .loaded(let statement):
            StatementView(statement: statement)
        case .failed(let failure):
            ImportFailureView(failure: failure) { importModel.isPickerPresented = true }
        }
    }
}

#Preview {
    RootView()
}
