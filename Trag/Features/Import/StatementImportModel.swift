import Foundation
import OSLog
import Observation
import StatementParsing

/// Picks a statement file, parses it off the main actor and saves it.
@Observable
final class StatementImportModel {
    enum State: Equatable {
        case idle
        case importing
        case finished(ImportOutcome)
        case failed(ImportFailure)
    }

    private(set) var state: State = .idle
    var isPickerPresented = false

    private let importer: StatementImporter
    private let store: TransactionStore

    init(store: TransactionStore, importer: StatementImporter = StatementImporter()) {
        self.store = store
        self.importer = importer
    }

    func importFile(_ result: Result<URL, any Error>) async {
        guard case .success(let url) = result else { return }
        state = .importing
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let statement = try await importer.importStatement(from: url)
            let saved = try store.save(statement)
            Log.import.info("Imported \(statement.bankName, privacy: .public): \(saved.inserted) new, \(saved.alreadyImported) existing")
            state = .finished(ImportOutcome(result: saved, totalsMatch: statement.matchesReportedTotals))
        } catch {
            Log.import.error("Import failed: \(String(describing: error), privacy: .public)")
            state = .failed(ImportFailure(error))
        }
    }

    /// Loads made-up statements so the app can be tried without a real bank statement.
    func importDemoData() {
        do {
            let results = try DemoData.statements().map { try store.save($0) }
            let inserted = results.reduce(0) { $0 + $1.inserted }
            state = .finished(
                ImportOutcome(
                    result: .init(inserted: inserted, alreadyImported: results.reduce(0) { $0 + $1.alreadyImported }),
                    totalsMatch: true))
        } catch {
            state = .failed(ImportFailure(error))
        }
    }

    func dismissOutcome() {
        state = .idle
    }
}

struct ImportOutcome: Hashable {
    let result: TransactionStore.ImportResult
    let totalsMatch: Bool
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
            self.init(
                title: String(localized: "Bank not supported yet"),
                message: String(localized: "Trag can read Union banka statements today. More banks are coming."))
        case .unreadableDocument:
            self.init(
                title: String(localized: "Couldn't open the file"),
                message: String(localized: "Make sure it's a PDF statement downloaded from your bank."))
        case .noTransactionsFound:
            self.init(
                title: String(localized: "No transactions found"),
                message: String(localized: "The statement looks empty or its layout is different from what Trag expects."))
        case nil:
            self.init(title: String(localized: "Something went wrong"), message: error.localizedDescription)
        }
    }
}
