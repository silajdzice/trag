import StatementParsing
import SwiftUI

struct ImportPromptView: View {
    let onImport: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No statement yet", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Import a bank statement PDF. Everything stays on this iPhone.")
        } actions: {
            Button("Import statement", action: onImport)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct ImportFailureView: View {
    let failure: ImportFailure
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(failure.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            Button("Choose another file", action: onRetry)
                .buttonStyle(.bordered)
        }
    }
}

#Preview("Prompt") {
    ImportPromptView {}
}

#Preview("Failure") {
    ImportFailureView(failure: ImportFailure(StatementParsingError.unsupportedBank)) {}
}
