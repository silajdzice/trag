# Trag

A private money coach for iPhone. Import your bank statement and see where your money goes. Everything runs on-device; your bank data never leaves the phone.

## Structure
```
Trag/                       SwiftUI app (thin UI layer, MainActor by default)
  App/                      entry point, root navigation
  Features/Import/          import flow: model + views
  Features/Ledger/          month overview, transactions, category picker
  Persistence/              SwiftData models and TransactionStore
  Shared/                   formatting, category display, logging, preview data
  Resources/                assets, privacy manifest
TragKit/                    Swift package with all logic (pure, tested)
  StatementParsing/         bank statement -> transactions; one parser per bank (Banks/)
  Insights/                 plain-Swift numbers: totals, merchants, fees
  AICoach/                  on-device model layer (optional at runtime)
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

## Quality gate
```bash
./scripts/format.sh   # format in place
./scripts/check.sh    # format lint + tests + app build, warnings as errors
```
See docs/QUALITY.md for the full quality bar.
