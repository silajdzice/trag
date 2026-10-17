# Trag: one-page spec

## One-liner
A private money coach for iPhone: import your bank statement and see where your money goes, what's coming next month, and where you could save. Everything runs on your phone, so your bank data never leaves it.

## Problem
- People want to understand their spending, but bank apps in Bosnia (and the region) show raw transaction lists with no insights.
- Most people won't upload bank statements to ChatGPT or connect their bank to a third-party cloud app.
- Many people here have no online-first bank (no Revolut, N26), only a local bank that exports statements.

## Target user
- **V1:** Edhem and people like him. A Union banka customer, iPhone user, wants to know "where does my salary go?"
- **Later:** anyone in BiH and the region with a local bank statement, then the EU.

## Why on-device
Privacy, offline use, zero server cost, and it's a strong portfolio story ("fintech engineer builds a privacy-first AI finance app").

## Architecture principle: Swift does the math, the LLM does the language
| Layer | Responsibility | Tech |
|---|---|---|
| Import | Parse statements into transactions | PDFKit / CSV parser, per-bank parsers |
| Core (works for everyone) | Totals, categories via rules, recurring payments, monthly prediction | Plain Swift, SwiftData |
| AI layer (when available) | Smart categorisation of messy merchant names, natural-language Q&A, saving advice | Apple Foundation Models: `@Generable` structured output + `Tool` calling into core functions |
| UI | Dashboard, charts, transactions, chat | SwiftUI, Swift Charts |

**AI availability:** check `SystemLanguageModel.default.availability`. If it's unavailable (an older iPhone, unsupported language, AI turned off), the app still works fully, minus chat and advice. Optional later: an MLX open-model download for older phones.

## V1 features (MVP)
1. **Import** a Union banka statement (format TBD: PDF / CSV / Excel), plus a **generic CSV import** with column mapping for other banks.
2. **Transactions list** with automatic categories (rules + AI) and manual correction (corrections are remembered per merchant).
3. **Dashboard:** spend by category (chart), top merchants, this month vs last month.
4. **Subscriptions and recurring payments** detection.
5. **Next-month prediction** from history and recurring items.
6. **Ask your money (AI):** "How much did I spend on fuel in September?" The model answers using tool calls; numbers always come from Swift.
7. **Monthly insight (AI):** 3 short saving tips based on real numbers.

## Out of scope for V1
Bank connections/APIs, cloud sync, multiple users, budgets and goals, Android, multi-currency (BAM / KM only at first).

## Tech decisions
- Dev machine: M4 Pro, latest macOS: Foundation Models work in the Simulator
- iOS 26 minimum (Foundation Models; also runs on the iPhone 13 Pro Max, without AI).
- SwiftUI, SwiftData, Swift Charts, Swift Concurrency, Swift Testing.
- Modular: separate SPM packages for `StatementParsing`, `Insights` (pure Swift, fully unit-tested) and `AICoach`.
- Privacy: no network calls at all in V1 (you can say "no internet permission needed").

## Open decisions
- [x] App name: **Trag** ("trace": see the trace your money leaves). App Store already has "Trag: Authenticate & Trace" and "TRAG Tracking" (SLASH d.o.o. Sarajevo), so the store name needs a suffix, e.g. "Trag: Money Coach"
- [x] Repo: private for now; make it public as a showcase if we decide not to ship to the App Store
- [ ] Monetisation: free with Pro one-time (€4.99) vs fully paid
- [ ] Languages: English first, Bosnian UI in V1.1?
- [ ] Design: ask your wife (UX/UI) for the dashboard and onboarding, which also makes it the agency's first joint case study

## Success criteria
- Edhem uses it on his own statements every month.
- Public repo with a clean README, architecture diagram and demo GIF, pinned on GitHub.
- Shipped to the App Store (even if few users at first).
- A 2-minute demo you can show in interviews.
