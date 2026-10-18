import AICoach
import SwiftUI

/// Chat about the user's own spending, answered on-device and checked against the data.
struct AskMoneyView: View {
    @State var model: AskMoneyModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        Label("Runs entirely on this iPhone.", systemImage: "lock.shield")
                        if model.answersInEnglish {
                            Label(
                                "Answers are in English: Apple's on-device model doesn't support Bosnian yet.",
                                systemImage: "globe")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    if model.messages.isEmpty {
                        Section("Try asking") {
                            ForEach(model.suggestions, id: \.self) { suggestion in
                                Button(suggestion) { Task { await model.send(suggestion) } }
                            }
                        }
                    }

                    ForEach(model.messages) { message in
                        MessageBubble(message: message)
                            .listRowSeparator(.hidden)
                            .id(message.id)
                    }

                    if model.isThinking {
                        ProgressView("Thinking…")
                            .listRowSeparator(.hidden)
                            .id("thinking")
                    }
                }
                .listStyle(.plain)
                .onChange(of: model.messages.count) {
                    withAnimation { proxy.scrollTo(model.messages.last?.id, anchor: .bottom) }
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle("Ask your money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your spending", text: $model.draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { Task { await model.send() } }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: .rect(cornerRadius: 20))
            Button("Send", systemImage: "arrow.up.circle.fill") {
                Task { await model.send() }
            }
            .labelStyle(.iconOnly)
            .font(.title)
            .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty || model.isThinking)
        }
        .padding()
    }
}

private struct MessageBubble: View {
    let message: AskMoneyModel.Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Group {
                switch message.role {
                case .user:
                    Text(message.text)
                        .padding(12)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: .rect(cornerRadius: 16))
                case .assistant:
                    Label {
                        Text(markdown: message.text)
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(.tint)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: .rect(cornerRadius: 16))
                case .notice:
                    Label(message.text, systemImage: "exclamationmark.bubble")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}

extension Text {
    /// Renders the model's inline markdown (bold, italics); falls back to plain text.
    init(markdown: String) {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            self.init(attributed)
        } else {
            self.init(verbatim: markdown)
        }
    }
}
