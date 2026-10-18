import AICoach
import SwiftUI

/// Runs the same eval suite used in development on this device, for the selected engine and both chat strategies.
struct AILabView: View {
    let engine: AIEngine
    @State private var reports: [EvalSuite.Report] = []
    @State private var status: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await run() }
                } label: {
                    Label("Run evals", systemImage: "play.fill")
                }
                .disabled(status != nil)
                if let status {
                    ProgressView(status)
                }
            } footer: {
                Text("Uses made-up data, not your statements. Each strategy runs categories, chat and tips.")
            }

            ForEach(reports, id: \.strategy) { report in
                Section {
                    ForEach(report.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(verbatim: task.name)
                                Spacer()
                                Text(verbatim: "\(task.passed)/\(task.total)")
                                    .monospacedDigit()
                                    .foregroundStyle(task.score >= 0.8 ? .green : task.score >= 0.5 ? .orange : .red)
                            }
                            Text(verbatim: "\(task.averageSeconds.formatted(.number.precision(.fractionLength(1)))) s")
                                .foregroundStyle(.secondary)
                            ForEach(task.failures, id: \.self) { failure in
                                Text(verbatim: "✗ \(failure)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                    }
                } header: {
                    Text(verbatim: "\(engineName) · \(report.strategy.rawValue)")
                }
            }
        }
        .navigationTitle("AI lab")
    }

    private var engineName: String {
        switch engine {
        case .appleIntelligence: "Apple Intelligence"
        case .local(let model): model.displayName
        }
    }

    private func run() async {
        reports = []
        for strategy in ChatStrategy.allCases {
            let report = await EvalSuite.run(engine: engine, strategy: strategy) { task in
                status = "\(strategy.rawValue): \(task)…"
            }
            reports.append(report)
        }
        status = nil
    }
}
