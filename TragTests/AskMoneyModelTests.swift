import AICoach
import Foundation
import Insights
import Testing

@testable import Trag

/// Answers after a short delay, recording the order questions arrive in.
@MainActor
final class SlowStubChat: MoneyAnswering {
    let strategy = ChatStrategy.structuredIntent
    private(set) var asked: [String] = []

    func ask(_ question: String) async -> MoneyChat.Reply {
        asked.append(question)
        try? await Task.sleep(for: .milliseconds(50))
        return .computed(.forecast(month: Month(year: 2026, month: 10), total: Decimal(asked.count), currency: "BAM"))
    }
}

@MainActor
@Suite struct AskMoneyModelTests {
    @Test func questionsSentWhileThinkingAreQueuedNotDropped() async {
        let chat = SlowStubChat()
        let model = AskMoneyModel(chat: chat)

        async let first: Void = model.send("First?")
        async let second: Void = model.send("Second?")
        _ = await (first, second)

        #expect(chat.asked == ["First?", "Second?"])
        #expect(model.messages.map(\.role) == [.user, .user, .assistant, .assistant])
        #expect(!model.isThinking)
    }

    @Test func listAnswersCarryTheirPayments() async {
        final class ListChat: MoneyAnswering {
            let strategy = ChatStrategy.structuredIntent
            func ask(_ question: String) async -> MoneyChat.Reply {
                .computed(
                    .transactionList(
                        category: .pets, merchant: nil, month: Month(year: 2026, month: 9),
                        payments: [
                            ListedPayment(id: "1", date: .now, merchant: "ZOO CENTAR", amount: 20.5, currency: "BAM")
                        ],
                        count: 1, total: 20.5, currency: "BAM"))
            }
        }
        let model = AskMoneyModel(chat: ListChat())
        await model.send("List pets")
        #expect(model.messages.last?.payments.map(\.merchant) == ["ZOO CENTAR"])
        #expect(model.messages.last?.paymentCount == 1)
    }
}
