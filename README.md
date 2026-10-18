# Trag

A private money coach for iPhone. Import your bank statement and see where your money goes. Everything runs on-device; your bank data never leaves the phone.

## Structure
```
Trag/                       SwiftUI app (thin UI layer, MainActor by default)
  App/                      entry point, root navigation
  Features/Import/          import flow: model + views
  Features/Ledger/          month overview, transactions, category picker
  Features/Ask/             "Ask your money" chat
  Features/Settings/        AI engine choice, model downloads, AI lab
  Persistence/              SwiftData models and TransactionStore
  Shared/                   formatting, category display, logging, preview data
  Resources/                assets, privacy manifest
TragKit/                    Swift package with all logic (pure, tested)
  StatementParsing/         bank statement -> transactions; one parser per bank (Banks/)
  Insights/                 plain-Swift numbers: totals, merchants, fees
  AICoach/                  AI engines (Apple / MLX), chat strategies, grounding, evals
TragTests/                  app tests (store, ledger, import errors)
docs/                       QUALITY.md (quality bar), bank format notes
scripts/                    check.sh (quality gate), format.sh, check-localization.py
test-data/private/          real statements, git-ignored, never committed
```

## Principle
Swift does the math, the LLM does the language. The model never computes totals; it calls tools that return exact numbers.

## Features (so far)
- Import Union banka PDF statements; every import is checked against the statement's own totals
- Months of history stored on-device (SwiftData), re-imports never duplicate
- Dashboard: category donut, spending per month, change vs last month
- Subscriptions and bills found automatically, with next expected charge
- Next-month spending estimate
- Spending by category and by merchant, per month
- Rule-based categories for common BiH merchants, plus your own choice per merchant
- Choose your AI engine: Apple Intelligence, or an open model (Qwen3 0.6B / 1.7B / Qwen3.5 2B) downloaded in the app and run with MLX. Older iPhones get AI too, and anyone can switch to compare.
- On-device AI, optional at runtime:
  - categories for shops the rules don't know (never overriding the user)
  - "Ask your money" chat: totals, lists of individual payments and follow-up questions ("nabroji te transakcije"); numbers always come from Swift, never from the model
  - three saving tips per month, phrased from signals Trag computes
- English and Bosnian (String Catalog, proper Bosnian plurals)

## Supported banks
| Bank | Format | Validation |
|---|---|---|
| Union banka (BiH) | PDF statement ("Izvod") | Parsed totals must equal the statement footer |

## Adding a bank
1. Add format notes in `docs/<bank>-format.md`.
2. Implement `StatementParser` in `TragKit/Sources/StatementParsing/Banks/`.
3. Register it in `StatementParserRegistry`.
4. Add interpreter tests with sanitized rows; real statements go in `test-data/private/` (git-ignored) and are checked automatically by the PDF tests.

## AI architecture
- **One API, two engines.** Every AI feature uses `LanguageModelSession`. Apple Intelligence uses `SystemLanguageModel`; downloaded models use `MLXLanguageModel` from `mlx-swift-lm`'s FoundationModels bridge, with grammar-constrained `@Generable` output.
- **Two chat strategies.** *Tool calling*: the model calls Trag's tools and writes the answer; amounts are verified by `GroundingCheck`. *Structured intent*: the model only fills in what was asked (category, shop, month); Swift computes the answer and the app phrases it in the user's language, so small models can't invent numbers and answers can be in Bosnian.
- **Evals, not vibes.** `EvalSuite` scores categories, chat and tips on fake data for any engine and strategy. It runs in tests on a Mac (`./scripts/ai-evals.sh`, Apple Intelligence) and in the app's **AI lab** on a phone, for downloaded models.

| Apple Intelligence (Mac) | Categories | Chat (9 cases incl. lists and follow-ups) | Tips |
|---|---|---|---|
| Tool calling | 10/10 | 7–8/9 (2.5 s) | 3/3 |
| **Structured intent** (default) | 10/10 | **9/9** every run (1.2 s) | 3/3 |

Structured intent is the default for every engine: in these evals it was more reliable than tool calling even on Apple's model, about twice as fast, and its answers are written by the app in the user's language (Bosnian). Tool calling remains available in the AI lab for comparison.

Downloaded models are scored on device in the AI lab.

## Building
MLX compiles Metal shaders, so build with Xcode / `xcodebuild` (not `swift build`). Requires Xcode's Metal Toolchain component, and trusting the pinned `mlx-swift-lm` macros once in Xcode (or `-skipMacroValidation` on the command line).

## Quality gate
```bash
./scripts/format.sh   # format in place
./scripts/check.sh    # format lint + tests + app build, warnings as errors
```
See docs/QUALITY.md for the full quality bar.
