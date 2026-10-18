import Foundation
import HuggingFace
import MLXFoundationModels

/// Downloads, inspects and deletes local models. Weights come from Hugging Face once; user data never leaves the device.
public enum LocalModelStore {
    public enum State: Sendable, Equatable {
        case notDownloaded
        case downloading
        case ready
        case failed
        /// No Metal GPU (only very old hardware or Intel-Mac simulators).
        case unsupportedDevice
    }

    public static func state(of model: LocalModel) async -> State {
        switch await model.languageModel.availability {
        case .available: .ready
        case .downloading: .downloading
        case .unavailable(.modelNotDownloaded): .notDownloaded
        case .unavailable(.downloadFailed): .failed
        case .unavailable(.deviceNotCapable): .unsupportedDevice
        @unknown default: .failed
        }
    }

    /// Fraction 0...1 of an in-flight download, observable from SwiftUI.
    @MainActor
    public static func downloadProgress(of model: LocalModel) -> Double? {
        MLXDownloadProgress.shared.activeDownloads.first { $0.modelID == model.configuration.name }?.fractionCompleted
    }

    /// Bytes free where weights are stored, to warn before a download that won't fit.
    public static func freeDiskSpace(for model: LocalModel) -> Int64? {
        model.languageModel.freeDiskSpaceBytes
    }

    public static func download(_ model: LocalModel) async throws {
        try await model.languageModel.preload()
    }

    public static func delete(_ model: LocalModel) async throws {
        let languageModel = model.languageModel
        await languageModel.evict()
        guard let repo = Repo.ID(rawValue: model.id) else { return }
        let directory = HubCache.default.repoDirectory(repo: repo, kind: .model)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}
