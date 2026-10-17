# Trag: guidance for coding agents

Read `docs/QUALITY.md` (the quality bar) and `SPEC.md` before changing code.

- Run `scripts/check.sh` before saying work is done; it must pass with zero warnings.
- Never commit or print real statement data. Real PDFs live only in `test-data/private/` (git-ignored). Before committing, run:
  `git grep -niE "<owner surname>|<account digits>|<card last4>" -- .` with the owner's real values and make sure nothing matches.
- Business logic goes in `TragKit` (pure, tested), not in the app target.
- New bank: follow "Adding a bank" in README.md.
- Money is `Decimal`. Dates in bank formats are parsed in `Europe/Sarajevo`.
