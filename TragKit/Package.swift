// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TragKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "StatementParsing", targets: ["StatementParsing"]),
        .library(name: "Insights", targets: ["Insights"]),
        .library(name: "AICoach", targets: ["AICoach"]),
    ],
    targets: [
        .target(name: "StatementParsing"),
        .target(name: "Insights", dependencies: ["StatementParsing"]),
        .target(name: "AICoach", dependencies: ["StatementParsing", "Insights"]),
        .testTarget(name: "StatementParsingTests", dependencies: ["StatementParsing"]),
        .testTarget(name: "InsightsTests", dependencies: ["Insights"]),
    ]
)
