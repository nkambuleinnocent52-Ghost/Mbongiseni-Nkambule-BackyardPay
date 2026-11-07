# BackyardPay 1.0.2 (build 3): automatic first-month rent

The owner selected calendar-day proration for new move-ins. Each property's **First month billing** setting defaults to **Prorate actual calendar days**, with **Charge full month** retained as an explicit agreement choice. The daily amount is derived from monthly rent and the actual move-in month's length; entering two independent prices would allow them to contradict each other.

The first charge is `monthly cents × days from move-in through month-end inclusive ÷ calendar days in that month`, rounded once to the nearest cent (half-up). Do not round a daily price before multiplying it. For R1,500 and 15 January, 17 of 31 days gives **R822.58**. A 15 February move-in gives R750.00 in a 28-day February; leap-year February is handled separately. Subsequent calendar months use full monthly rent, subject to the app's existing dated rates and documented adjustments. The first due date cannot precede move-in; later months retain the agreed due day, normally the first.

The onboarding form previews the first charge immediately when the move-in date changes. Property records show the billing basis and an indicative daily equivalent. Rental accounts and downloadable statements explain the recorded first-month calculation. The database calculates the same charge and prevents confirmed allocation beyond it. Deposits remain separate. Existing manual adjustments are applied after the prorated base charge.

## Preserve history

The additive migration snapshots the property preference into each newly created tenancy, including tenant signup into a vacant room. Later property edits do not rewrite that tenancy's billing basis. All pre-upgrade tenancies retain their previous full-month base and any existing adjustments; their balances, receipts and allocations are not retroactively recalculated. Where an existing agreement needs correcting, use an evidenced charge adjustment. Planned expiry and actual handover retain their existing behaviour; automatic final-month proration is not introduced by this update.

This calendar-day basis is the chosen product/agreement rule, not a claim that every rental arrangement is legally required to use it.

## Activate on the existing project

1. In Supabase SQL Editor, run **downloads/BackyardPay-Proration-Update.sql**, after the previously applied Research Update. This is the only new SQL required for 1.0.2. It is safe to rerun; it does not reset data or change Auth/email settings. Do not reapply older migrations afterwards.
2. Upload the latest **BackyardPay-Netlify-web.zip** to the existing Netlify project, keeping normal Windows/browser protection enabled.
3. Refresh the app. Add/edit a property's first-month billing preference, then onboard a tenant with the actual date and check the preview. Existing tenancies keep their recorded basis.

## Validation

Calendar math is tested for 28, 29, 30 and 31-day months, first/last dates, final-only cent rounding, subsequent rates, separate adjustments and first-month due date. The actual onboarding screen has a live-preview widget check. PostgreSQL tests apply the migration twice, preserve a pre-upgrade charge, check the recorded property choice, exercise tenant signup and reject confirmed over-allocation. The browser/API contract includes a tenant's automatically prorated current-month payment; transport is simulated, with independent SQL tests for server arithmetic and permissions. This does not assert that the owner-controlled hosted database has already received the migration.

Source, startup, browser, release integrity and independent scanner checks accompany the build. The previous Defender finding remains documented for the original research archive. No Microsoft clearance is claimed; let Windows check new downloads normally.
