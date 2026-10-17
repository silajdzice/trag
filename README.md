# Trag

A private money coach for iPhone. Import your bank statement and see where your money goes. Everything runs on-device; your bank data never leaves the phone.

## Structure
- `Trag/`: SwiftUI app
- `TragKit/`: Swift package
  - `StatementParsing`: bank statement → transactions. One parser per bank behind `StatementParser`, chosen by `StatementParserRegistry`.
  - `Insights`: plain-Swift numbers (totals, top merchants, fees, later recurring payments and forecasts).
  - `AICoach`: Apple Foundation Models layer (categorisation, Q&A, tips). Optional: the app works without it.
- `docs/`: bank format notes

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

## Tests
```bash
cd TragKit && swift test
```
