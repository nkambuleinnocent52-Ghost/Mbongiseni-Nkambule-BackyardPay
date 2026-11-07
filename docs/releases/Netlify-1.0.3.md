# BackyardPay 1.0.3 (build 4): property deposits and private tenant reports

Research basis: [Tenant reports review](../research/Tenant-Reports-Review-2026-11-07.md), the earlier deposit/notice review, Rental Housing Act ss. 4–5 and the Eastern Cape Rental Housing Tribunal's current complaint guidance. The owner authorised implementation after this review. A report is a factual record; it does not automatically establish fault, deduct money, waive rent or authorise entry.

## Property deposit and onboarding

The landlord explicitly enters **Security deposit per new tenancy** on the property form; 0 means none is agreed. Existing property settings are initially unknown, rather than an invented deposit amount. New onboarding requires the setting to be completed. Existing tenancies, agreed deposits, payments and receipts are preserved.

For each new tenancy the property deposit is recorded as an agreed obligation, due by move-in, with **zero money received**. A subsequent property change does not change the old tenancy's agreement. The landlord records actual receipt separately in the Deposit account. Interest, supported deductions and refunds remain separate events.

The onboarding preview itemises deposit, prorated first rent, and total initially due. For R2,000 deposit and R1,500 rent with 15 January entry it shows R2,822.58, not a misleading R2,822.58 rent charge. The tenant dashboard and rental details show agreed deposit, received deposit, remaining deposit, rent balance and combined recorded amount due. Any unallocated received rent money remains visibly separate for reconciliation. This overview total does not itself transfer or bank-verify money.

## Reporting

A linked tenant can report leaks/plumbing, gate/shared-facility defects, electrical/safety concerns, structure/damp, noise/nuisance, room damage, account/deposit queries and other matters. Self-caused damage can be reported; unknown cause is valid. Required fields identify category, urgency, actual date and exact location, plus the description. Access availability is optional, with an explicit reminder that visits must be arranged.

Both parties can add messages; the landlord maintains open/in-progress/resolved workflow state. The landlord's **Tenant reports** overview shows the reporting rental, room, category, urgency and state. Reports use existing in-app notifications, not automatic SMS or contractor/emergency dispatch. Immediate danger requires direct contact with relevant emergency/municipal services and the landlord.

Private PDF/JPEG/PNG files can be linked to each report. The existing Storage bucket and role rules apply; a report attachment must belong to the same tenancy and be uploaded by the caller. Existing unlinked rental documents remain accessible. Hosted Storage transfer still requires real deployment acceptance.

Reports cannot automatically create financial liabilities. Deposit deductions remain explicit, supported, balance-limited records with the existing inspection prerequisites. The form asks for the supported deduction amount, not automatic loss of the full deposit. When a single bank transfer covers rent and deposit, forms instruct users to record its purpose-specific components against the same actual bank reference, never the full transfer twice. Automatic bank transaction import/splitting is not included.

## Activate

1. Run **BackyardPay-Deposit-Reports-Update.sql** in the existing Supabase project's SQL Editor. This single file includes the Proration update followed by this release's update; either may safely be replayed. The Research update must already exist. Do not run older database-setup scripts afterwards.
2. Upload the latest **BackyardPay-Netlify-web.zip** to the existing Netlify project and refresh. Use normal browser/Windows protection; leave any blocked download blocked.
3. Edit the property's agreed deposit before adding the next tenant. Verify the preview, record actual receipts and use a linked tenant account to submit a private report.

The release does not reset data or change email-confirmation/SMTP settings. No production data was seeded from the workspace. Real hosted accounts, file transfers and phone permissions need owner acceptance; browser and database tests are local/isolated.
