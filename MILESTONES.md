# Money Coach: milestones

Assumes about 15–20 h/week alongside your job and applications. Each milestone ends with something that works.

## M0: Setup (weekend 1)
- [x] Get a Union banka statement (kept locally in test-data/private, git-ignored) (mask account number, IBAN, name, address) and save it as test data
- [x] Check the Mac: Apple silicon + macOS 26 + Apple Intelligence on + Xcode 26
- [x] Create the Xcode project + SPM packages (`StatementParsing`, `Insights`, `AICoach`), public GitHub repo, README stub
- [ ] Quick spike: call the Foundation Model in the Simulator and categorize 10 real merchant names with `@Generable`

## M0.5: Quality baseline (done)
- [x] Feature folders, @Observable models, async import off the main actor
- [x] swift-format + scripts/check.sh (warnings as errors), docs/QUALITY.md, CLAUDE.md
- [x] Privacy manifest, os.Logger without personal data, previews with fake data
- [x] App unit-test target for feature models
- [x] String Catalog: English + Bosnian (with plurals), checked by scripts/check-localization.py
- [x] GitHub Actions running scripts/check.sh
- [ ] UI smoke test for the import flow (with the dashboard)

## M1: Import + transactions (week 1–2)
- [x] Union banka parser, unit-tested; handles rows split across pages (validated on Jul–Sep statements) against the real (anonymized) statement
- [ ] Generic CSV import with column mapping (moved to after V1: no CSV-only bank yet)
- [x] SwiftData model: StoredTransaction, CategoryOverride; re-import never duplicates
- [x] Transactions list + manual category correction (remembered per merchant)
- [x] Rule-based categories (no AI yet): 81% of real spending categorised by rules alone

## M2: Insights core (week 2–3)
- [x] Spend by category, top merchants, month vs month (% change)
- [x] Recurring payment / subscription detection (stable foreign price or bills; everyday categories excluded)
- [x] Next-month prediction (recurring + average of the rest, last 3 months)
- [x] Dashboard with Swift Charts: category donut, monthly bars; light/dark checked
- [x] Unit tests for all of `Insights` (Swift Testing)

## M3: AI layer (week 3–4)
- [x] AI categorization for unknown merchants (@Generable), user > rules > AI; each merchant asked once; ✨ marker
- [x] Tools: monthSummary, spendingByCategory, spendingAtMerchant, subscriptionsAndBills, nextMonthEstimate
- [x] "Ask your money" chat with grounding check (answers with invented amounts are withheld)
- [x] Monthly insight: 3 saving tips from Swift-computed signals, grounded
- [x] Graceful fallback when the model isn't available, with the reason shown (verify on the iPhone 13)

AI evals (scripts/ai-evals.sh, real model): categories 10/10, chat 4/4 grounded incl. Bosnian questions.

## M3.5: Choose your AI (done)
- [x] Engine choice: Apple Intelligence, downloadable open models (MLX via FoundationModels bridge), or off
- [x] Model library: sizes, tiers, RAM hint, download with progress, delete, disk-space check
- [x] Structured-intent chat strategy with Swift-computed, localized answers (Bosnian)
- [x] Shared EvalSuite: Mac tests + on-device AI lab; Apple: 6/6 chat with both strategies
- [ ] Download a model on the iPhone 13 and record AI lab scores for Qwen3 0.6B / 1.7B / Qwen3.5 2B

## M4: Polish + ship (week 5–6)
- [ ] Design pass (ideally with your wife): onboarding, dashboard, empty states
- [ ] App icon, screenshots, privacy label ("Data not collected")
- [ ] README with an architecture diagram + demo GIF; pin the repo
- [ ] TestFlight with 5–10 friends, fix feedback
- [ ] App Store submission

## After V1
- More local banks (Raiffeisen, UniCredit, Sparkasse, ASA, NLB)
- Bosnian UI
- Budgets and goals
- MLX model download for older iPhones
- Blog post / LinkedIn post about the "Swift does math, LLM does language" architecture
