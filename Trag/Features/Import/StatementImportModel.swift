import Foundation
import OSLog
import Observation
import StatementParsing

@Observable
final class StatementImportModel {
    enum State {
        case empty
        case importing
        case loaded(ParsedStatement)
        case failed(ImportFailure)
    }

    private(set) var state: State
    var isPickerPresented = false

    private let importer: StatementImporter

    init(state: State = .empty, importer: StatementImporter = StatementImporter()) {
        self.state = state
        self.importer = importer
    }

    func importFile(_ result: Result<URL, any Error>) async {
        guard case .success(let url) = result else { return }
        state = .importing
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let statement = try await importer.importStatement(from: url)
            Log.import.info("Imported \(statement.bankName, privacy: .public) statement with \(statement.transactions.count) transactions")
            state = .loaded(statement)
        } catch {
            Log.import.error("Import failed: \(String(describing: error), privacy: .public)")
            state = .failed(ImportFailure(error))
        }
    }
}

struct ImportFailure: Error, Equatable {
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(_ error: any Error) {
        switch error as? StatementParsingError {
        case .unsupportedBank:
            self.init(title: "Bank not supported yet", message: "Trag can read Union banka statements today. More banks are coming.")
        case .unreadableDocument:
            self.init(title: "Couldn't open the file", message: "Make sure it's a PDF statement downloaded from your bank.")
        case .noTransactionsFound:
            self.init(
                title: "No transactions found", message: "The statement looks empty or its layout is different from what Trag expects.")
        case nil:
            self.init(title: "Something went wrong", message: error.localizedDescription)
        }
    }
}
