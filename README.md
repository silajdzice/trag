# Trag

A private money coach for iPhone. Import your bank statement and see where your money goes. Everything runs on-device; your bank data never leaves the phone.

## Structure
```
Trag/                       SwiftUI app (thin UI layer, MainActor by default)
  App/                      entry point, root navigation
  Features/Import/          import flow: model + views
  Features/Statement/       statement overview
  Shared/                   formatting, logging, preview data
  Resources/                assets, privacy manifest
TragKit/                    Swift package with all logic (pure, tested)
  StatementParsing/         bank statement -> transactions; one parser per bank (Banks/)
  Insights/                 plain-Swift numbers: totals, merchants, fees
  AICoach/                  on-device model layer (optional at runtime)
docs/                       QUALITY.md (quality bar), bank format notes
scripts/                    check.sh (quality gate), format.sh
test-data/private/          real statements, git-ignored, never committed
```

## Principle
Swift does the math, the LLM does the language. The model never computes totals; it calls tools that return exact numbers.

## Supported banks
| Bank | Format | Validation |
|---|---|---|
| Union banka (BiH) | PDF statement ("Izvod") | Parsed totals must equal the statement footer |

## Adding a bank
1. Add format notes in `docs/<bank>-format.md`.
2. Implement `StatementParser` in `TragKit/Sources/StatementParsing/Banks/`.
3. Register it in `StatementParserRegistry`.
4. Add interpreter tests with sanitized rows; real statements go in `test-data/private/` (git-ignored) and are checked automatically by the PDF tests.

## Quality gate
```bash
./scripts/format.sh   # format in place
./scripts/check.sh    # format lint + tests + app build, warnings as errors
```
See docs/QUALITY.md for the full quality bar.
