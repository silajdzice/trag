import AICoach
import Foundation
import Observation

/// Conversation state for "Ask your money". The model only sees data through Trag's tools.
@Observable
final class AskMoneyModel {
    struct Message: Identifiable, Equatable {
        enum Role {
            case user
            case assistant
            /// Trag speaking, e.g. when an answer was withheld.
            case notice
        }

        let id = UUID()
        let role: Role
        let text: String
        /// Payments to show under the text, when the answer is a list.
        var payments: [ListedPayment] = []
        /// How many matched in total (the list may be shortened).
        var paymentCount = 0
    }

    private(set) var messages: [Message] = []
    private(set) var isThinking = false
    var draft = ""

    private let chat: any MoneyAnswering
    /// Questions sent while an answer is being written; answered in order.
    private var queue: [String] = []

    convenience init(queries: SpendingQueries, engine: AIEngine) {
        self.init(chat: MoneyChat(queries: queries, engine: engine))
    }

    init(chat: any MoneyAnswering) {
        self.chat = chat
    }

    /// Only model-written answers are in English; Swift-computed answers use the app's language.
    var answersInEnglish: Bool {
        chat.strategy == .toolCalling && !AIAvailability.supportsUserLanguage()
    }

    /// Questions that work well, in the user's language.
    var suggestions: [String] {
        [
            String(localized: "Where did most of my money go this month?"),
            String(localized: "How much did I spend on groceries this month?"),
            String(localized: "Show my payments for pets this month."),
            String(localized: "Which subscriptions and bills do I pay?"),
            String(localized: "How much will I spend next month?"),
        ]
    }

    /// Shows the question at once. If an answer is still being written, the question waits its turn
    /// instead of being dropped.
    func send(_ text: String? = nil) async {
        let question = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if text == nil { draft = "" }
        messages.append(Message(role: .user, text: question))
        queue.append(question)
        guard !isThinking else { return }

        isThinking = true
        defer { isThinking = false }
        while !queue.isEmpty {
            await answer(queue.removeFirst())
        }
    }

    private func answer(_ question: String) async {
        switch await chat.ask(question) {
        case .answer(let answer):
            messages.append(Message(role: .assistant, text: answer))
        case .computed(let answer):
            var message = Message(role: answer == .notUnderstood ? .notice : .assistant, text: answer.localizedText)
            if case .transactionList(_, _, _, let payments, let count, _, _) = answer {
                message.payments = payments
                message.paymentCount = count
            }
            messages.append(message)
        case .notGrounded:
            messages.append(
                Message(
                    role: .notice,
                    text: String(
                        localized:
                            "I couldn't find a reliable answer in your data. Try asking about a category, a shop or a month."
                    )))
        case .failed:
            messages.append(Message(role: .notice, text: String(localized: "Something went wrong. Please try again.")))
        }
    }
}

extension AskMoneyModel: Identifiable {}
