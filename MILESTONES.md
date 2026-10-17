# Money Coach: milestones

Assumes about 15–20 h/week alongside your job and applications. Each milestone ends with something that works.

## M0: Setup (weekend 1)
- [x] Get a Union banka statement (kept locally in test-data/private, git-ignored) (mask account number, IBAN, name, address) and save it as test data
- [x] Check the Mac: Apple silicon + macOS 26 + Apple Intelligence on + Xcode 26
- [x] Create the Xcode project + SPM packages (`StatementParsing`, `Insights`, `AICoach`), public GitHub repo, README stub
- [ ] Quick spike: call the Foundation Model in the Simulator and categorize 10 real merchant names with `@Generable`

## M1: Import + transactions (week 1–2)
- [x] Union banka parser, unit-tested against the real (anonymized) statement
- [ ] Generic CSV import with column mapping
- [ ] SwiftData model: Transaction, Category, MerchantRule
- [ ] Transactions list + manual category correction (remembered per merchant)
- [ ] Rule-based categories (no AI yet)

## M2: Insights core (week 2–3)
- [ ] Spend by category, top merchants, month vs month
- [ ] Recurring payment / subscription detection
- [ ] Next-month prediction
- [ ] Dashboard with Swift Charts
- [ ] Unit tests for all of `Insights` (Swift Testing)

## M3: AI layer (week 3–4)
- [ ] AI categorization for unknown merchants (structured output), with rules taking priority
- [ ] Tools: `spendingByCategory`, `transactions(matching:)`, `recurringPayments`, `forecast`
- [ ] "Ask your money" chat screen
- [ ] Monthly insight: 3 saving tips grounded in real numbers
- [ ] Graceful fallback when the model isn't available (your iPhone 13 = test device)

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
