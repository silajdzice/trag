import SwiftUI

struct ImportOutcomeBanner: View {
    let outcome: ImportOutcome
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: outcome.totalsMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(outcome.totalsMatch ? Color.green : Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if outcome.result.inserted > 0 {
                    Text("\(outcome.result.inserted) new transactions")
                        .font(.headline)
                } else {
                    Text("This statement was already imported")
                        .font(.headline)
                }
                if !outcome.totalsMatch {
                    Text("Some rows may be missing from this statement.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack {
        ImportOutcomeBanner(outcome: ImportOutcome(result: .init(inserted: 77, alreadyImported: 0), totalsMatch: true)) {}
        ImportOutcomeBanner(outcome: ImportOutcome(result: .init(inserted: 0, alreadyImported: 77), totalsMatch: false)) {}
    }
    .padding()
}
