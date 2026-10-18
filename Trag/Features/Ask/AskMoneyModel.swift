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
    }

    private(set) var messages: [Message] = []
    private(set) var isThinking = false
    var draft = ""

    private let chat: MoneyChat

    init(queries: SpendingQueries, engine: AIEngine) {
        chat = MoneyChat(queries: queries, engine: engine)
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
            String(localized: "Which subscriptions and bills do I pay?"),
            String(localized: "How much will I spend next month?"),
        ]
    }

    func send(_ text: String? = nil) async {
        let question = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }
        draft = ""
        messages.append(Message(role: .user, text: question))
        isThinking = true
        defer { isThinking = false }

        switch await chat.ask(question) {
        case .answer(let answer):
            messages.append(Message(role: .assistant, text: answer))
        case .computed(let answer):
            messages.append(Message(role: answer == .notUnderstood ? .notice : .assistant, text: answer.localizedText))
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
