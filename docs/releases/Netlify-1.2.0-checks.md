# Version 1.2.0 checks — 11 November 2026

- 60 Flutter tests passed. Six new checks cover month/year rollover, twelve-month range, actual handover limits, fully paid current month selecting the next month with both amounts correct, no future debt added to today's ledger, rent/deposit navigation, pending deposits separate from received funds, and landlord-only receipt confirmation.
- Direct Dart analysis: 55 source/test/tool files, zero issues.
- Full disposable PostgreSQL suite passed, including all prior authorization/accounting migrations and new advance-rent/deposit-report checks. The complete owner upgrade was replayed and both suites passed again. The test script uses source migrations and works without generated downloads.
- Backend coverage includes current/future month separation, dated rent, month caps, landlord confirmation, reversal and handover, partial deposits, report caps, bank reference requirements, tenant/landlord/outsider access, idempotent reports/reviews, rejection/resubmission and manual-receipt interleaving without double counting or partial review writes.
- Chromium browser/API contract passed for November payment followed by December advance rent, owner approval and receipt PDF, unchanged current-month balance, tenant EFT deposit report, owner confirmation, separate balances, and the existing reporting/session/recovery flows. `pdftotext` verified an actual 11 November payment covering December rent. Supabase transport was simulated; no hosted account or database was changed.
- Release build and web startup checks passed: CSP, local renderer, phone launch, retiring old caches while preserving stored sessions, readable failure and retry.
- Packaged web integrity passed: 47 files, entry points, scripts, safe paths and per-file hashes.
- ClamAV 1.5.4 found zero infected files in the final web ZIP. Cached definitions are dated 1 November 2026 (10 days old); this is not Microsoft Defender clearance.

Scanned web ZIP SHA-256: `b61dc09de662823f0e4625cc4212ce66e24d7d1689fc1db676d6294a0333a71d`.

Screenshots: [advance rent](Netlify-1.2.0-advance-rent.png), [tenant deposit report](Netlify-1.2.0-deposit.png).

Hosted activation requires the owner to run the supplied additive SQL in Supabase and upload the web ZIP to the existing Netlify project. Existing data is preserved; no Auth/SMTP configuration reset is required.
