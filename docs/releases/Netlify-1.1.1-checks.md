# Version 1.1.1 checks — 8 November 2026

- 54 Flutter tests passed, including 320-pixel layouts and existing rental/payment behavior.
- Direct Dart analysis: 43 files, zero issues.
- Release web build passed using Flutter 3.47.5 with CSP and local renderer resources.
- Chromium browser/API contract passed for landlord room assignment and custom rate, tenant signup/payment report without a confirmation checkbox, landlord payment confirmation and receipt PDF, tenant report/acknowledgement/reply/broadcast, deposit receipt, restored sessions and password recovery. Transport was simulated; no production accounts or data were created.
- Startup checks passed for CSP, phone launch, retiring old caches while preserving stored sessions, readable startup failure and retry.
- Packaged ZIP integrity passed: 47 files, required entry points, scripts, safe paths and per-file hashes.
- ClamAV 1.5.4 found zero infected files in the web ZIP, using cached definitions dated 1 November 2026. This is not Microsoft Defender clearance.

Scanned web ZIP SHA-256: `f1b2267efac9879a949bac67258955bafbf736475e86fd254fe7e103ad561aaf`.

Screenshots: [tenant](Netlify-1.1.1-tenant.png), [landlord](Netlify-1.1.1-landlord.png).

The web release must be uploaded to the owner's existing Netlify project before it changes the live application. No new SQL is required for this wording-only update.
