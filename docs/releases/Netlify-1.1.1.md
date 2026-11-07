# BackyardPay 1.1.1 — plain payment wording

Payment reporting, landlord confirmation, payment details, the monthly account and dashboard summaries now use ordinary language for money linked to rent months.

- Tenant heading: **Which month did you pay for?** Landlord heading: **Which month does this payment cover?**
- Tenant amount: **How much did you pay? (rand)**. Landlord amount: **Amount received (rand)**.
- **Amount for this month (rand)** replaces Allocation. **Money not yet linked to a month** replaces Unallocated credit.
- Month selectors and payment details show readable month names, such as Nov 2026.
- The tenant guide explains paying first, reporting next and waiting for the landlord to confirm. The landlord guide explains checking actual cash or bank records. The confirmation checkbox stays landlord-only.
- A zero remainder says all of this payment is linked to rent months, and explicitly says this does not mean all rent is paid. An excessive total asks the user to reduce the month amounts.
- Pending-payment guidance is different for landlord and tenant. The existing payment amounts, approval rules and records are preserved.

Upload the latest `downloads/BackyardPay-Netlify-web.zip` to the existing Netlify project and refresh the app. This wording release needs no additional SQL. If the earlier South African payment-date fix has not been applied, it remains a separate backend update documented in `Payment-date-fix.md`.

Validation: 54 Flutter tests passed, including small-screen layouts; direct Dart analysis reports zero issues across 43 files. Release, browser startup, browser/API contract and packaged ZIP checks are recorded with the release checks. Browser transport is simulated, not hosted-project verification.

[Recorded check results and screenshots](Netlify-1.1.1-checks.md).
