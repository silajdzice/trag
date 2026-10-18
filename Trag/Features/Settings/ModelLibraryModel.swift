import AICoach
import Foundation
import Observation

/// Download state of every model in the catalog, with download and delete actions.
@Observable
final class ModelLibraryModel {
    private(set) var states: [LocalModel.ID: LocalModelStore.State] = [:]
    private(set) var errors: [LocalModel.ID: String] = [:]

    func refresh() async {
        for model in LocalModel.catalog {
            states[model.id] = await LocalModelStore.state(of: model)
        }
    }

    func state(of model: LocalModel) -> LocalModelStore.State {
        states[model.id] ?? .notDownloaded
    }

    /// Refuses to start when the device doesn't have room, so the user gets a clear message instead of a failed download.
    func download(_ model: LocalModel) async {
        errors[model.id] = nil
        if let free = LocalModelStore.freeDiskSpace(for: model), free < model.downloadBytes * 2 {
            errors[model.id] = String(localized: "Not enough free space on this iPhone.")
            return
        }
        states[model.id] = .downloading
        do {
            try await LocalModelStore.download(model)
            Log.ai.info("Downloaded \(model.id, privacy: .public)")
        } catch {
            Log.ai.error("Download of \(model.id, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            errors[model.id] = String(localized: "Download failed. Check your connection and try again.")
        }
        states[model.id] = await LocalModelStore.state(of: model)
    }

    func delete(_ model: LocalModel) async {
        do {
            try await LocalModelStore.delete(model)
        } catch {
            Log.ai.error("Deleting \(model.id, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
        states[model.id] = await LocalModelStore.state(of: model)
    }
}
