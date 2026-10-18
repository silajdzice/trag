import AICoach
import SwiftUI

/// Choose the AI engine: Apple Intelligence, a downloaded open model, or off.
struct AISettingsView: View {
    @Bindable var settings: AISettings
    @State private var library = ModelLibraryModel()
    @State private var modelToDelete: LocalModel?

    var body: some View {
        List {
            Section {
                EngineRow(
                    title: Text(verbatim: "Apple Intelligence"),
                    subtitle: appleSubtitle,
                    systemImage: "apple.intelligence",
                    isSelected: settings.isSelected(.appleIntelligence),
                    isEnabled: settings.appleIntelligence.isAvailable
                ) {
                    settings.select(.appleIntelligence)
                }
            } header: {
                Text("Built in")
            } footer: {
                if !settings.appleIntelligence.isAvailable {
                    Text("Older iPhones can't use Apple Intelligence. Download a model below to use AI features.")
                }
            }

            Section {
                ForEach(LocalModel.catalog) { model in
                    ModelRow(
                        model: model,
                        state: library.state(of: model),
                        error: library.errors[model.id],
                        isSelected: settings.isSelected(.local(model)),
                        onSelect: { settings.select(.local(model)) },
                        onDownload: { Task { await library.download(model) } },
                        onDelete: { modelToDelete = model }
                    )
                }
            } header: {
                Text("Download a model")
            } footer: {
                Text(
                    "Models download once from Hugging Face over the internet. After that everything runs offline, and your bank data never leaves this iPhone."
                )
            }

            Section {
                EngineRow(
                    title: Text("Off"), subtitle: Text("Dashboard, categories and forecasts still work."),
                    systemImage: "sparkles.slash", isSelected: settings.isOff, isEnabled: true
                ) {
                    settings.select(nil)
                }
            }

            if let engine = settings.selectedEngine {
                Section {
                    NavigationLink {
                        AILabView(engine: engine)
                    } label: {
                        Label("AI lab: measure quality", systemImage: "gauge.with.dots.needle.67percent")
                    }
                }
            }
        }
        .navigationTitle("AI")
        .task { await library.refresh() }
        .confirmationDialog(
            "Delete this model?", isPresented: .constant(modelToDelete != nil), titleVisibility: .visible,
            presenting: modelToDelete
        ) { model in
            Button("Delete \(model.displayName)", role: .destructive) {
                if settings.isSelected(.local(model)) { settings.select(nil) }
                Task { await library.delete(model) }
                modelToDelete = nil
            }
            Button("Cancel", role: .cancel) { modelToDelete = nil }
        } message: { model in
            Text("Frees \(Int64(model.downloadBytes).formatted(.byteCount(style: .file))). You can download it again later.")
        }
    }

    private var appleSubtitle: Text {
        switch settings.appleIntelligence {
        case .available: Text("Best quality, no download.")
        case .unavailable(.deviceNotEligible): Text("Not supported on this iPhone.")
        case .unavailable(.appleIntelligenceNotEnabled): Text("Turn on Apple Intelligence in Settings.")
        case .unavailable(.modelNotReady): Text("Still getting ready.")
        case .unavailable(.unknown): Text("Unavailable right now.")
        }
    }
}

private struct EngineRow: View {
    let title: Text
    let subtitle: Text
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        title
                        subtitle.font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: systemImage)
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
        }
        .tint(.primary)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ModelRow: View {
    let model: LocalModel
    let state: LocalModelStore.State
    let error: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(verbatim: model.displayName)
                        TierBadge(tier: model.tier)
                    }
                    Text(model.downloadBytes, format: .byteCount(style: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                action
            }
            if state == .downloading {
                ProgressView(value: LocalModelStore.downloadProgress(of: model) ?? 0)
            }
            if !model.fitsThisDevice {
                Label("May be slow on this iPhone: it needs more memory.", systemImage: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
        .swipeActions {
            if state == .ready {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        switch state {
        case .ready:
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(.tint)
                    .accessibilityLabel(Text("In use"))
            } else {
                Button("Use", action: onSelect).buttonStyle(.bordered)
            }
        case .downloading:
            ProgressView()
        case .notDownloaded, .failed:
            Button("Download", systemImage: "arrow.down.circle", action: onDownload)
                .labelStyle(.iconOnly)
                .font(.title2)
        case .unsupportedDevice:
            Text("Not supported").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct TierBadge: View {
    let tier: LocalModel.Tier

    var body: some View {
        Group {
            switch tier {
            case .fastest: Text("Fastest")
            case .recommended: Text("Recommended")
            case .bestQuality: Text("Best quality")
            }
        }
        .font(.caption2.bold())
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tier == .recommended ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15), in: .capsule)
    }
}

#Preview("Older iPhone") {
    NavigationStack {
        AISettingsView(
            settings: AISettings(defaults: UserDefaults(suiteName: "preview")!, appleIntelligence: .unavailable(.deviceNotEligible)))
    }
}
