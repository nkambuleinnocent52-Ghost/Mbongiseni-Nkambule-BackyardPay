# Version 1.3.0: fixed payment rules

Both dashboards state: monthly rent is due on the 1st; the security deposit is paid once within ten calendar days of move-in. The deposit warning begins on that deadline, without an additional ten-day delay. First partial-month rent remains due at move-in. Payment date controls are removed from property/rent-change forms; the server enforces day1. Existing charged-month dates and explicit prior deposit agreements are retained; existing rent transitions to the1st next month without changing rent amounts.

Run downloads/BackyardPay-Fixed-Payment-Rules.sql in the existing Supabase project, then upload the latest web ZIP. The final scheduler result should be true for daily background reminders. Notices are in-app, not SMS. No account reset is required.

Verification:82Fluttertests passed;60Dartfiles analyzed with zero issues; full disposable PostgreSQL suite passed including policy enforcement, legacy preservation and no additional reminder delay; Chromium simulated-Supabase contract passed both role policy labels, no editable rent due day, day10 warning, deposit confirmation, payments/receipts and authentication recovery. Startup and47-file archive integrity checks passed. ClamAV1.5.4 reported zero infected files using1November cached definitions (not Microsoft clearance). Production updates require the owner's SQL run and Netlify upload.
