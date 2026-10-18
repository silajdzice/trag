// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "TragKit",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [
        .library(name: "StatementParsing", targets: ["StatementParsing"]),
        .library(name: "Insights", targets: ["Insights"]),
        .library(name: "AICoach", targets: ["AICoach"]),
    ],
    dependencies: [
        // On-device open models through Apple's FoundationModels API (MLXLanguageModel). Pinned exactly.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.32.3"),
        .package(url: "https://github.com/huggingface/swift-huggingface", exact: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.5"),
    ],
    targets: [
        .target(name: "StatementParsing"),
        .target(name: "Insights", dependencies: ["StatementParsing"]),
        .target(
            name: "AICoach",
            dependencies: [
                "StatementParsing", "Insights",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "MLXFoundationModels", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ]),
        .testTarget(name: "StatementParsingTests", dependencies: ["StatementParsing"]),
        .testTarget(name: "InsightsTests", dependencies: ["Insights"]),
        .testTarget(name: "AICoachTests", dependencies: ["AICoach"]),
        // Runs the real on-device model; nondeterministic, so it is scored and run on demand (scripts/ai-evals.sh).
        .testTarget(name: "AICoachEvals", dependencies: ["AICoach"]),
    ]
)
