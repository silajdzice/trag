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
- Light/dark mode; strings in a String Catalog (English first, Bosnian next).

## Testing
- Swift Testing for packages; each bank parser has sanitized interpreter tests plus footer-total validation against private statements.
- Snapshot of behaviour, not implementation: test public APIs.
- UI smoke test for the import flow once the dashboard lands.

## Privacy and security
- No network access in V1; no analytics SDKs.
- `PrivacyInfo.xcprivacy` declares no data collection.
- Logs via `os.Logger`; never log amounts, names, IBANs or merchant names (`privacy: .private`).
- Real statements only in git-ignored `test-data/private/`; run the personal-data grep before every commit.

## Tooling
- `swift format` (bundled with Xcode) with the repo's `.swift-format` config.
- `scripts/check.sh` = format lint + package tests + app build. It must pass before every commit.
- CI (GitHub Actions) runs the same script once the repo is on GitHub.
- Conventional, small commits.
