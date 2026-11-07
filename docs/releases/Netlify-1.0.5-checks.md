# Version 1.0.5 verification — 7 November 2026

- 51 Flutter tests passed, including invitation metadata without room, public-code/room rejection before signup, registration without a room field, existing room availability and rental accounting.
- Direct Dart analysis: 40 files, zero issues.
- Release web build passed using Flutter 3.47.5, with CSP and local renderer resources.
- PostgreSQL disposable database tests passed, including migration replay, public-code claims and supplied-room rejection, ended-rental rejection, one-use private invitation, preserved landlord-assigned room/date/rent/deposit/history, no orphan profiles and scoped tenant snapshot. No hosted database was modified.
- Web startup checks passed: CSP, phone launch, old-cache retirement with storage preserved, readable failure and retry.
- Chromium browser/API contract passed with two isolated sessions: landlord creates property and assigns available Room 1; tenant registers with only that private invitation, preserving the rental; payment review, receipt PDF, reporting/reply, session restoration and password recovery pass. Supabase transport was simulated.
- Packaged web integrity passed: 47 files, root entry point and all script assets present, valid paths and per-file hash manifest.
- ClamAV 1.5.4: zero infected files in the web ZIP. Cached definitions are dated 1 November 2026; this is not Microsoft Defender clearance. Keep normal device protection enabled.

Scanned web ZIP SHA-256: `bb37f5df194bc68b16c1197510228ed1fc415fa185727d5beca392b315f7dab5`.

Hosted Supabase activation and Netlify publication require the owner’s existing project access. Browser transport tests use synthetic records, not research participants.
