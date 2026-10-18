import Foundation
import Testing

@testable import AICoach

/// Runs the shared `EvalSuite` against Apple Intelligence on this Mac. Downloaded models are evaluated
/// on the phone in the app's AI lab (no model downloads on the development machine).
@Suite(.enabled(if: AIAvailability.current.isAvailable, "On-device model unavailable"), .serialized)
struct AICoachEvals {
    @Test(arguments: ChatStrategy.allCases)
    @MainActor
    func appleIntelligence(strategy: ChatStrategy) async {
        let report = await EvalSuite.run(engine: .appleIntelligence, strategy: strategy)
        for task in report.tasks {
            print(
                "EVAL apple/\(strategy.rawValue) \(task.name): \(task.passed)/\(task.total), "
                    + String(format: "%.1fs avg", task.averageSeconds))
            for failure in task.failures { print("  ✗ \(failure)") }
        }
        #expect(report.tasks.allSatisfy { $0.score >= 0.6 })
    }
}
