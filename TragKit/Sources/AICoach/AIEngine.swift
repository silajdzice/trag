import Foundation
import FoundationModels
import HuggingFace
import MLXFoundationModels
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// An open model the user can download and run on-device with MLX.
public struct LocalModel: Sendable, Hashable, Identifiable {
    public enum Tier: String, Sendable {
        case fastest
        case recommended
        case bestQuality
    }

    /// Hugging Face repository, e.g. "mlx-community/Qwen3-1.7B-4bit".
    public let id: String
    public let displayName: String
    public let tier: Tier
    /// Approximate download size.
    public let downloadBytes: Int64
    /// Below this much device memory the model is likely to be slow or killed by the system.
    public let recommendedMemoryBytes: UInt64
    let configuration: ModelConfiguration

    public static func == (lhs: LocalModel, rhs: LocalModel) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private static let gigabyte: UInt64 = 1_073_741_824

    public static let catalog: [LocalModel] = [
        LocalModel(
            id: "mlx-community/Qwen3-0.6B-4bit", displayName: "Qwen3 0.6B", tier: .fastest,
            downloadBytes: 350_000_000, recommendedMemoryBytes: 4 * gigabyte, configuration: LLMRegistry.qwen3_0_6b_4bit),
        LocalModel(
            id: "mlx-community/Qwen3-1.7B-4bit", displayName: "Qwen3 1.7B", tier: .recommended,
            downloadBytes: 980_000_000, recommendedMemoryBytes: 4 * gigabyte, configuration: LLMRegistry.qwen3_1_7b_4bit),
        LocalModel(
            id: "mlx-community/Qwen3.5-2B-4bit", displayName: "Qwen3.5 2B", tier: .bestQuality,
            downloadBytes: 1_750_000_000, recommendedMemoryBytes: 6 * gigabyte, configuration: LLMRegistry.qwen3_5_2b_4bit),
    ]

    public static func withID(_ id: String) -> LocalModel? { catalog.first { $0.id == id } }

    /// True when this device has enough memory for the model to run comfortably.
    public var fitsThisDevice: Bool { ProcessInfo.processInfo.physicalMemory >= recommendedMemoryBytes }

    /// The FoundationModels-compatible model. Weights live in the Hugging Face cache inside the app container.
    var languageModel: MLXLanguageModel {
        #huggingFaceLanguageModel(configuration: configuration, capabilities: [.guidedGeneration, .toolCalling])
    }
}

/// Which model powers Trag's AI features.
public enum AIEngine: Sendable, Hashable {
    case appleIntelligence
    case local(LocalModel)

    public var id: String {
        switch self {
        case .appleIntelligence: "apple"
        case .local(let model): model.id
        }
    }

    public init?(id: String) {
        if id == "apple" {
            self = .appleIntelligence
        } else if let model = LocalModel.withID(id) {
            self = .local(model)
        } else {
            return nil
        }
    }

    /// The same `LanguageModelSession` code runs on either model.
    var languageModel: any FoundationModels.LanguageModel {
        switch self {
        case .appleIntelligence: SystemLanguageModel.default
        case .local(let model): model.languageModel
        }
    }

    /// Apple's model handles tool calling well; small open models are more reliable filling in a structured intent.
    public var recommendedChatStrategy: ChatStrategy {
        switch self {
        case .appleIntelligence: .toolCalling
        case .local: .structuredIntent
        }
    }

    func session(tools: [any FoundationModels.Tool] = [], instructions: String) -> LanguageModelSession {
        LanguageModelSession(model: languageModel, tools: tools, instructions: instructions)
    }
}

/// How the chat turns a question into an answer.
public enum ChatStrategy: String, Sendable, CaseIterable {
    /// The model calls Trag's tools and writes the answer; amounts are checked against tool output.
    case toolCalling
    /// The model only fills in what the user asked for; Swift computes the answer and the app phrases it.
    case structuredIntent
}
