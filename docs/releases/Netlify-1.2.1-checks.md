# Version 1.2.1 checks — 11 November 2026

- 78 Flutter tests passed. New logic checks cover days9/10/11, SAST calendar inputs, explicit/fallback/malformed due dates, partial/full receipts, partial/full pending reports and ended/zero/unknown deposits. Widget checks at320px cover unpaid warnings, review-only pending wording, clearing paid warnings, owner scheduler status and landlord-only deadline controls.
- Direct Dart analysis: 59 files, zero issues.
- Release build passed with Flutter3.47.5, CSP and local renderer resources. Startup checks passed for phone launch, old-cache retirement with sessions preserved, readable script failure and retry.
- Full disposable PostgreSQL suite passed, including reminder migration replay and the complete datefix→advance→depositreports→reminders owner replay. All earlier feature suites still pass after replay. Reminder checks cover day9/10, SAST dates, caller scope/row-level security, private global worker, once-only notifications, partial/full pending funds, paid/ended/rescheduled resolution and owner-only agreed deadline updates.
- Scheduling was checked using a test-only Cron API fixture in the disposable database. Named daily configuration, active/disabled/wrong-schedule status, replay and running the stored private command without an app/auth session all passed. This verifies configuration and worker behavior, not actual execution by the hosted Supabase Cron service. The owner script ends with a read-only active-job status query.
- Chromium browser/API contract passed for setting an agreed due date, showing the ten-day warning at the top of the tenant dashboard, switching a fully reported amount to review-only wording, and clearing the warning after landlord confirmation. The prior advance-rent, deposit, payment/PDF, issue and session/recovery flows also passed. Supabase transport was simulated; production scheduling was not executed by this browser test.
- ClamAV1.5.4 found zero infected files in the final web ZIP using cached definitions dated1November2026 (10daysold). This is not Microsoft Defender clearance.
- Web ZIP integrity passed with47files, valid paths, all required entry points and per-file hashes.

Hosted activation requires running the complete supplied SQL and uploading the web ZIP. Background reminders need the SQL's `daily_background_reminders_active` result to be true. If Cron is unavailable, the app reports that status and performs scoped checks when signed-in records refresh. Alerts are stored in-app notifications, not SMS/email/push delivery while a browser is closed.

Scanned web ZIP SHA-256: `1d971fbc1e3047a0ca2027efc712bb0de2b0367227c23a649a01b2037e799456`.

Screenshots: [ten-day warning](Netlify-1.2.1-reminder.png), [reported payment awaiting review](Netlify-1.2.1-pending-review.png).
