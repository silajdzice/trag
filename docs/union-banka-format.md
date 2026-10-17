# Union banka statement format (izvod): parser notes

Source: monthly PDF statement ("Izvod"), 5 pages for ~80 transactions. No personal data in this file.

## Header
- Client name + address, Partija (account no.), Valuta `977 KM`, IBAN
- Opening balance: `Prethodni saldo glavnice` / `Prethodno stanje`

## Table columns
`Referenca naloga | Datum transakcije | Datum valute | Nalogodavac/Korisnik | Opis promjene | Iznos duguje | Iznos potražuje`
- Duguje = money out (debit), Potražuje = money in (credit)
- Number format: `1.234,56` (dot = thousands, comma = decimals)
- Dates: `dd.MM.yyyy.` (trailing dot)
- "Nalogodavac/Korisnik" spans multiple lines (account no. + name + street + city) for bill payments

## Transaction types seen
| Type | How to recognise | Notes |
|---|---|---|
| Card purchase, domestic | `Kupovina na POS terminalu van BC, unutar BH <masked card> <MERCHANT>` | Merchant name is truncated to ~22 chars, e.g. `AMKO KOMERC D.O.O. SAR` |
| Card purchase, foreign | `Kupovina na POS terminalu van BH <card> <MERCHANT> (12.99 EUR)` | Original currency + amount in parentheses; KM amount in Duguje |
| FX fee | `Naknada za VISA konverziju - ...` | Separate row, small amount; should be linked to its purchase |
| ATM withdrawal | `Podizanje gotovine na ATM-u BH mreža ...` | + separate `Naknada - Podizanje gotovine...` fee row |
| Bill payment | Payee block (e.g. utility company) + reference/description | **Same reference appears twice**: the bill amount + a 0,75 KM fee row |
| Salary / income | Employer in Nalogodavac, `PLACA ZA 9 2026`, `REGRES 2026` | Credit column |
| Bank package fee | `Naknada za paket ...` | Monthly |

## Footer
`Ukupno` (totals duguje/potražuje), `Saldo`, `Raspoloživo`, statement period + generation timestamp.

## Parsing gotchas
1. **Text layer order differs from the visual layout.** In raw text extraction the amounts were not next to their rows. Plan: parse with **positions** (PDFKit `PDFPage` + character bounds, or Vision OCR as a fallback), grouping by row Y-coordinate and assigning columns by X ranges. Validate in the M0 spike.
2. Rendered font drops some diacritics (Ć, Č) but the text layer has them, so normalise the Unicode.
3. Multi-line cells and page breaks: a row can continue on the next page (payee address split across pages 3–4).
4. Fees should be modelled as linked child transactions, so "Bank fees" can be shown as their own category (a nice insight: FX + ATM + bill + package fees per month).
5. Validate the parse against the footer: sum(duguje) and sum(potražuje) must equal `Ukupno`. This is a great self-check and unit test.

## Test data policy
- The real statement stays **out of git** (`test-data/private/` in `.gitignore`); use it only for local manual runs.
- Unit tests use a **sanitized fixture**: the same structure with fake name, address, IBAN, account numbers, customer/reference numbers and salary.
