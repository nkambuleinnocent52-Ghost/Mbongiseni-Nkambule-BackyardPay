# Lecturer feedback: implementation response

Source: the comments in **BackyardPay remarks.docx** supplied by the student. The document is feedback and design context. This response describes the application changes; it does not assert a mark or replace the final report.

| Lecturer concern | Change | Evidence to demonstrate |
|---|---|---|
| The community problem is not clear | Landing page now leads with matching paid/unpaid rent by tenant, room and calendar month. Proposed report wording below makes the record-reconciliation problem explicit. | Show a partial payment and the still-outstanding balance. |
| Records do not identify who has paid or not paid | Landlord dashboard includes every tenancy, even without submissions; the tenant list filters Paid, Partially paid, Outstanding, Overdue and Pending for a selected month. | Select a month with no payment and show the tenant still listed as outstanding. |
| Relationship to bank payments and duplicate receipts is unclear | EFT and PayShap require a separate bank transaction reference. Guidance explains payment occurs outside the app. Landlords manually match funds to bank records. Bank-method PDFs are rent-allocation acknowledgements, not bank-issued proof. | Submit EFT, show the two references, explain bank proof versus rental allocation, then confirm after checking receipt of funds. |
| Critical rental/lease details are missing | Rental record now includes parties and contact details, full structured property address, room, monthly rent, due day, occupancy start/end, rental type, deposit agreed/received, utilities and notice/house-rule terms. Optional emergency contact and read acknowledgement are included. | Open Rental details. Complete missing terms as landlord, then acknowledge reading as tenant. |
| Property location and monthly tenant history are unclear | Property address is prominent and saved map coordinates remain accessible. A monthly rental account shows every charged month, confirmed receipts, pending records, month balance and cumulative balance. A downloadable statement is available. | Show the linked property's address/map and a month with no submitted payment. Download the account statement. |
| Separate, useful stakeholder dashboards are needed | Landlords see collections, collection rate, outstanding rent, arrears, occupancy, pending reviews and records needing completion. Tenants see rent remaining, due date, overdue balance, rental/contact details and direct access to account history and receipts. | Switch accounts and explain why the information differs. |

## Suggested problem statement for the report

Informal backyard rental records can become difficult to reconcile when rent amounts, cash handovers, bank references and landlord confirmations are kept separately. A payment submission alone does not establish that the landlord received money, and a missing submission must not make an unpaid tenant disappear from a monthly record. Partial payments also require a clear link to the tenant, room and rental month so both parties can see what remains owed.

BackyardPay addresses that recordkeeping problem by linking tenants to a property and room, recording each month's rent charge, and separating submitted payments from landlord-confirmed receipts. It presents complete paid/unpaid accounts, a cumulative balance and rental acknowledgements that explain how received money was allocated. It is intended for landlords and tenants managing informal backyard rentals; any claims about the prevalence of these problems should be supported by sources or genuine research in the final report.

## Financial interpretation

- Cash: landlord checks the cash received, then confirms the record and issues the rent receipt.
- EFT / PayShap: the tenant pays through their bank, retains the bank's proof, and records the transaction reference here. The landlord checks their own banking records. The resulting acknowledgement links received funds to the rental account; it does not initiate or authenticate a bank transfer.
- Pending and rejected payments never reduce balances.
- Arrears are unpaid charges past the due day. Running account balance includes all unpaid charged months. It does not charge arrears a second time in later months.
- Deposits are separate records and are never counted as monthly rent collections.
- Full calendar-month rent applies. Automatic proration and rent-rate variations for an existing tenancy are not implemented.

## Rental records and compatibility

Existing local data keeps its accounts, payments, reference numbers and location when loading the new version. New fields are optional on old records, with missing rental terms explicitly shown as not recorded. A landlord must enter real agreed details; the app does not invent them. Changing rental dates cannot exclude existing payment records or overlap another tenancy for the same room. Ended tenancies remain in history and stop accumulating future months.

A tenant's acknowledgement records that they read the details. It is **not** a digital signature, legal lease or substitute for a separate signed agreement. Tenant acknowledgement is cleared when the landlord edits the terms.

New, explicitly created demo accounts include clearly fictional history, including a partial payment, so dashboards and monthly history can be demonstrated. Existing accounts are never silently overwritten with demo transactions.

## Visual direction

The supplied reference inspired a charcoal and black workspace, metallic-gold ribbon graphics, warm gold controls, quiet borders and readable off-white type. Desktop navigation and responsive metric cards give each role a clear workspace. Green and red remain reserved for meaningful statuses; every status also has a text label. Charts show stored confirmed amounts rather than invented activity.

## Remaining boundaries

The prototype still stores data on one browser/device, with no shared backend, bank API or uploaded bank-proof files. Native Android builds and device alerts require separate validation. Existing permission-based location, map links, browser alerts, in-app reminders and PDF sharing remain available. Any final validation results should be reported only after checks complete.

## Validation and previews

- 21 automated tests passed, covering payment rules, role isolation, local-storage compatibility, monthly balances, rental dates/room overlap, bank references and responsive layouts. The five UI/session checks were rerun after final visual refinements and passed.
- Static analysis: 21 Dart files, zero issues. Release web compilation passed.
- Screenshots use fictional demo records: [welcome](screenshots/welcome.png), [landlord dashboard](screenshots/landlord.png), [phone layout](screenshots/phone.png), [monthly account](screenshots/monthly-account.png).
- Chromium journey passed: role switching, pending-to-confirmed payment, balance update, reminder, simulated location save, confirmed receipt PDF, monthly account PDF and persisted session/data after refresh. No browser errors were reported. Real GPS and Android remain separate device checks.
