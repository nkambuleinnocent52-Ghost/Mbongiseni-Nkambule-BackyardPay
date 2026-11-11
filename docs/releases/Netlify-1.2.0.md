# BackyardPay 1.2.0 — advance rent and tenant deposit reports

## Rent for a later month

The rent-payment month list includes the tenancy's months through twelve months ahead of the current South African month. It ends at an actual handover, not merely a planned lease expiry. If November is already confirmed as paid, a new payment form suggests December and fills in its applicable monthly rent. Choosing another month refreshes the amount for a new single-month payment. When several months share one payment, each appears once; the total must still match the amount actually paid.

Advance rent remains linked to the selected future month and appears on its receipt. It does not create future debt in today's account or reduce some other month's rent. Confirmed monthly limits and dated agreed rent changes still apply. A future rate reduction below money already confirmed for that month must be reconciled first. Reversed/rejected payment history is preserved without permanently preventing handover; pending/confirmed future allocations still require reconciliation before closing earlier.

## Report a security-deposit payment

The tenant selects **Payment for → Security deposit** on the payment screen, or opens **Rental details → Security deposit → Report deposit payment**. The form records the actual deposit amount, date, method and bank reference where applicable. It does not transfer money. Pending reports remain separate from confirmed funds and the deposit still due.

The landlord sees **Deposit payments to check (n)** on the dashboard and the report inside the rental's deposit section. After checking the actual cash or bank transaction, the landlord ticks receipt and confirms. Confirmation creates one actual deposit receipt and notifies the tenant. If it cannot be confirmed, the landlord records a reason, which the tenant receives. Partial payments are supported; reports plus receipts cannot exceed the agreed deposit. Bank duplicates, repeated confirmation, manual-receipt conflicts and unauthorized reviews are checked on the server.

The old direct landlord receipt checkbox is disabled while a tenant report awaits review, to guide the landlord to confirm that report rather than enter the same money again. Deposits are never included as rent.

## Activate on the existing project

1. Open `downloads/BackyardPay-Advance-Deposit-Update.sql`, copy all SQL and run it in the existing Supabase SQL Editor. It includes the South African date correction and the two new additive migrations. It requires the research/proration/simple-rentals backend used by 1.1.x. Do not reset the database or Auth.
2. Download `downloads/BackyardPay-Netlify-web.zip` and upload it to the existing Netlify site. Refresh.
3. With November confirmed, report December rent. Separately report a tenant deposit payment; sign in as landlord to check and confirm it. Existing accounts, rental rates, receipts and history remain.

For editing or code submission, use `BackyardPay-Netlify-source.zip`. The separated source-file structure remains intact. No SMS or bank payment processing is introduced.

## Deposit deadline research

The Rental Housing Act s. 5(3)(c) allows the landlord to require the agreed deposit before moving in. The reviewed national provisions do not give every tenant an automatic 7/14/30-day initial-payment grace period. Follow the agreed due date; if later payment or instalments are allowed, agree and record the exact dates. Do not confuse refund deadlines after departure with the initial deposit deadline. Nonpayment does not authorize automatic lockout or eviction. See [research and sources](../research/Deposit-Deadline-Review-2026-11-11.md).

[Verification and screenshots](Netlify-1.2.0-checks.md).
