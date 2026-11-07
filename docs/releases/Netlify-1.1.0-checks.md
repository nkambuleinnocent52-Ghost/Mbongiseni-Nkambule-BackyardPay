# Version 1.1.0 checks — 8 November 2026

- 54 Flutter tests passed. New checks cover room-rate serialization and default fallback, the compact rental page without removed actions, an inline deposit section, and selecting multiple rooms / restoring default rent. The final compact-widget tests also pass after the last wording and issue-resolution changes.
- Direct Dart analysis: 43 source/test/tool files, zero issues.
- Release web build passed using Flutter 3.47.5 with CSP, local rendering resources and no service-worker caching of old app code.
- Disposable PostgreSQL tests passed for migration replay, custom room-rate selection, calendar-day proration, default fallback, unchanged existing rental terms, invalid room/amount rejection, separate deposit receipts and idempotent replay, supported deductions/refunds, deduction notices, one-tenant and property-wide notifications, broadcast replay and landlord-only authorization. Prior payment/access/invitation tests also pass. The hosted database was not changed.
- Chromium browser/API contract passed with isolated landlord and tenant sessions: custom room rent, assigned-room invitation signup, prorated payment and approval, receipt PDF, simple issue submission, acknowledgement visible to the tenant, private reply, property-wide update, issue resolution, inline deposit receipt, phone/desktop layout, session restoration and password recovery. Supabase transport was simulated.
- Web startup checks passed: CSP, phone launch, cache retirement with local storage preserved, readable failure/retry.
- Packaged web ZIP integrity passed: 47 files with root entry point, all referenced scripts, safe paths and per-file hash manifest.
- ClamAV 1.5.4 found zero infected files in the final web ZIP. Cached definitions are dated 1 November 2026; this does not establish Microsoft Defender clearance. Keep ordinary protection enabled.

Scanned web ZIP SHA-256: `c8c153fbb3abe1dd482914aae40c77a0e9e7c12ec80f2921f0c233e5f75264df`.

Production Supabase activation and Netlify publication still require the owner’s project access. Browser transport tests use synthetic users and simulated Supabase responses; they do not verify hosted email or create research participants.

Screenshots: [desktop](Netlify-1.1.0-desktop.png) · [phone](Netlify-1.1.0-phone.png).
