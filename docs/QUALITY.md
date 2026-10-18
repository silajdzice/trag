# Trag quality bar

Trag is a portfolio app: the code will be read by hiring managers. Every merged change meets this bar.

## Architecture
- **Modular SPM:** `StatementParsing` → `Insights` → `AICoach`; the app target is a thin UI layer. Packages never import SwiftUI.
- **Pure core:** parsing interpretation, insights and forecasts are pure functions over value types, fully unit-tested. Side effects (PDF, disk, model) sit behind small protocols.
- **Swift does math, the LLM does language.** The model never computes numbers; it calls tools.
- **App structure:** feature folders (`Features/Import`, `Features/Dashboard`, …), one `@Observable @MainActor` model per feature, views stay dumb.
- **Persistence:** SwiftData behind a repository protocol, so insights are testable without a store.

## Swift and concurrency
- Swift 6 language mode, complete strict concurrency, zero warnings.
- App target uses `MainActor` default isolation; heavy work (PDF parsing, AI) runs off the main actor via `nonisolated`/`@concurrent` async functions.
- No `@unchecked Sendable` except at framework boundaries, with a comment explaining why.
- `Decimal` for money, never `Double`.

## UI
- SwiftUI only; system components first, custom only when there's a reason.
- Every screen has loading, empty, error and content states, and a `#Preview` for each with sample data.
- Accessibility: Dynamic Type up to AX5, VoiceOver labels for amounts and charts, sufficient contrast, no information conveyed by color alone.
- Light/dark mode. Every user-facing string lives in `Localizable.xcstrings` with English and Bosnian (plural variants where counts appear); `scripts/check-localization.py` fails on missing or untranslated keys. Money, dates and months use the user's locale. Packages hold no UI strings.

## AI
- Swift does math, the model does language. The model sees data only through tools that return exact, Swift-computed text.
- Every AI answer passes `GroundingCheck`: amounts not present in tool output are withheld.
- AI is optional at runtime; every screen works without it and explains why it's unavailable.
- AI suggestions never override user choices and are visibly marked.
- Prompt changes are measured with `EvalSuite` (scripts/ai-evals.sh on a Mac, the AI lab on a phone), not unit tests.
- Engines are swappable behind `LanguageModelSession`; small models use the structured-intent strategy so they never write amounts.
- Extraction (intents, categories) decodes greedily, so evals are reproducible. Model output is verified in Swift: a shop name must appear in the question (models copy prompt examples), and the answer kind follows the filled-in details.
- Every chat answer has a 30 s timeout. `toolCallingMode: .required` is not used: it makes the model call tools forever.
- Models are downloaded only by the user, in the app, from pinned Hugging Face repos; dependencies are pinned to exact versions.

## Testing
- Swift Testing for packages; each bank parser has sanitized interpreter tests plus footer-total validation against private statements.
- Snapshot of behaviour, not implementation: test public APIs.
- UI smoke test for the import flow once the dashboard lands.

## Privacy and security
- The only network access is a user-started model download from Hugging Face; bank data never leaves the device. No analytics SDKs.
- `PrivacyInfo.xcprivacy` declares no data collection.
- Logs via `os.Logger`; never log amounts, names, IBANs or merchant names (`privacy: .private`).
- Real statements only in git-ignored `test-data/private/`; run the personal-data grep before every commit.

## Tooling
- `swift format` (bundled with Xcode) with the repo's `.swift-format` config.
- `scripts/check.sh` = format lint + package tests + app build. It must pass before every commit.
- CI (GitHub Actions) runs the same script once the repo is on GitHub.
- Conventional, small commits.
