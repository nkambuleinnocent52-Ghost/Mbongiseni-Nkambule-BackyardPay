# BackyardPay 1.2.1 — ten-day deposit reminders

A deposit that is still outstanding after ten calendar days from its agreed due date gets an in-app reminder. The due date defaults to move-in; an actually agreed later date can be recorded by the landlord under Rental details → Security deposit → Deposit due date and reminder. For example, a due date of 1 November becomes eligible on 11 November. This is an application reminder rule, not a legal grace period, fee or eviction action.

The tenant sees the amount still not received/reported, a report-payment action and a persistent dashboard warning. The landlord sees a deposit follow-up summary. Partial payments reduce the amount. If the tenant has reported some or all of the remaining deposit, that reported portion is not requested again: the landlord is reminded to check it. Once confirmed, paid warnings are cleared/read; ended rentals and zero/unknown deposits are excluded. A rescheduled agreed due date resolves the old warning and starts its own ten-day threshold. Notifications are issued once per rental/due date/recipient/type; refreshing does not spam another copy.

## Automatic schedule

The SQL tries to enable Supabase pg_cron and creates `backyardpay-deposit-reminders`, scheduled daily at 06:00 UTC (08:00 South African time on the normal Supabase UTC scheduler). It creates stored in-app notifications even without an open browser. This is not SMS, email or browser push while the browser is closed; tenants see the notification when they open BackyardPay.

If Cron is unavailable or disabled, scoped checks still run when a signed-in user opens/refreshes their records. The landlord's deposit reminder section explicitly shows whether daily background checks are active or whether checks currently happen only on app refresh. An active-job status confirms configuration, not a claim that a hosted job has already executed.

## Activate before uploading the new web build

1. Open `downloads/BackyardPay-Deposit-Reminder-Update.sql`, copy all its SQL into a new query in the existing Supabase SQL Editor and run it. It includes the date correction, advance rent/deposit reports and this reminder migration, so there is one current upgrade file. It requires the research/proration/simple-rentals backend from the existing 1.1.x application. No account/database reset or Auth changes are needed.
2. The final result shows `daily_background_reminders_active`. It should be **true** for checks while the app is closed. If it is **false** or the SQL output says Cron is not active, enable the **pg_cron / Cron** extension in the existing Supabase project and rerun this same SQL. Do not run files from `supabase/tests` on the hosted project; its Cron fixture is only a local test contract, not a real scheduler.
3. Upload `downloads/BackyardPay-Netlify-web.zip` to the existing Netlify project and refresh. Open a landlord rental's Security deposit → Deposit due date and reminder. For reminders while the app is closed, confirm it says **Daily background reminders are active**.

The migration and existing records are safe to replay. Do not run an older upgrade file after this one, since earlier files replace the outer snapshot/command functions. Use the complete latest file for replay.

## Rule and evidence

The server uses the Africa/Johannesburg calendar. Only the landlord can change an agreed deposit due date, and an explanation and tenant notification are recorded. A public snapshot remains security-invoker with the existing row-level access rules; only a private scheduler worker can check all rentals. Scoped app checks cannot select another user's scope/date. Notification generation happens after command commits through the subsequent snapshot, avoiding cross-property lock escalation inside payment mutations.

The ten-day reminder does not change the agreed payment obligation. The Rental Housing Act permits an agreed deposit before occupation; it does not create a universal post-move-in ten-day allowance. [Deposit-deadline research](../research/Deposit-Deadline-Review-2026-11-11.md).

[Recorded checks and screenshots](Netlify-1.2.1-checks.md).
