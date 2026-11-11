# Version 1.1.2 source-organisation checks — 11 November 2026

- 54 Flutter tests passed, including session/logout, phone layouts, registration and existing rental/accounting rules.
- Direct Dart analysis: 52 source/test/tool files, zero issues.
- Release web build passed with Flutter 3.47.5, CSP, local renderer resources and no old service-worker caching.
- Chromium browser/API contract passed with separate landlord and tenant sessions: registration, property/custom room rate, landlord room assignment, tenant payment report, landlord review and receipt PDF, reports/acknowledgement/reply/broadcast, deposit receipt, restored login and password-recovery callback. Supabase responses were simulated; no production data was created.
- Startup checks passed: CSP, phone launch, cache retirement with sessions preserved, readable failure/retry.
- ZIP integrity passed for the 47-file web archive, including root entry points, scripts, safe paths and per-file hashes.
- ClamAV 1.5.4 found zero infected files in the web ZIP. Cached definitions are dated 1 November 2026 (10 days old); this does not establish Microsoft Defender clearance.

Scanned web ZIP SHA-256: `0dc11d5160150e24cb973b79d8390534e5900986844f7e0d59ce5d9a836337b3`.

`main.dart` now contains 39 lines. Login/registration, password reset/recovery, the landlord dashboard, the tenant dashboard and the tenant list have their own source files. Shared dashboard code remains in a single Dart library using standard `part` files. Existing imports/exports remain compatible. No SQL or hosted account settings were changed.
