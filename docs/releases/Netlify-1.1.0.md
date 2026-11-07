# BackyardPay 1.1.0 — simpler rental management

The rental page now shows the tenant, room, rent, balance and one primary payment action. Security deposit, issues, rent changes, contact/agreement and move-out expand in place. The document, inspection, charge-adjustment and rental-change-history buttons are removed from this page. Existing documents and historical financial records are preserved; earlier adjustments continue to explain existing balances.

## Room-specific rent

In Properties, open a property and expand **Room rent**. Select rooms (for example 6, 7, 8 and 9), enter their monthly amount and save. Other rooms use the property default. Select **Use property default** to remove selected overrides. The room grid shows each rate, and onboarding calculates move-in rent using the selected room’s rate. Supabase applies the same rate and opening rent term. Existing tenants retain their agreed amounts: use Monthly rent in their rental details to record an agreed future change.

## Everyday tasks

- Record money received supports cash, EFT, cash deposit, PayShap, debit order and other payments. It records actual receipt and allocation; it does not move money or verify bank transactions.
- The security-deposit section shows required, received, outstanding and held amounts. The landlord’s receipt tick is derived from saved actual deposit payments. Partial receipts remain supported; no deposit is marked paid merely by adding a tenant.
- Deposit returns and supported deductions are inline. A deduction requires an amount, reason, condition/cost evidence and confirmation of lawful grounds. It is limited to funds held; damage never automatically forfeits the entire deposit. Deposit updates notify the linked tenant. Historical interest/refunds remain visible, and interest can be recorded.
- Tenants write an issue and its location. The landlord’s acknowledgement tick appears to both parties. A small resolve action closes a completed issue. Replies stay with the private issue. The landlord can instead switch to a property-wide message, or send an update from the property page. Broadcasts notify current linked tenant accounts at that property only; SMS/email is not sent. Do not include private tenant information in a shared message.
- Monthly rent contains an inline change form and a list of effective months and rates below it. Previous months retain their charges.
- Move-out uses a returned-room checkbox and inline actual date/final-billing note. Confirmation frees the room from the following day and preserves debts and deposit records.

## Activate

1. In the existing Supabase project, run `downloads/BackyardPay-Simple-Rentals-Update.sql`. It contains the invitation-only correction and the new additive migration. It requires the existing research, proration and deposit backend used by versions 1.0.3–1.0.5. It does not reset accounts, records or Auth settings.
2. Download `downloads/BackyardPay-Netlify-web.zip` and upload it to the existing Netlify site. Refresh the app.
3. Set a custom room rate, onboard a tenant into that room, and check the move-in costs. Use separate landlord/tenant accounts to check acknowledgement ticks and notifications.

Apply the SQL before the web update. Existing accounts and tenancies continue working. This does not replace an agreement or decide legal liability; deposit deduction evidence can be recorded without presenting a separate inspection workflow.

[Verification results](Netlify-1.1.0-checks.md).
