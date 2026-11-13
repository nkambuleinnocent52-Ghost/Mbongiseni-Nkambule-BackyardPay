# Application review — version 1.5.0

This update addresses the six comments in the supplied “BackyardPay remarks” document and the later screenshot review. The old cream/purple screenshots describe an earlier local demonstration. The current implementation uses separate role screens and a shared Supabase database.

## Lecturer's six comments

| Comment | Response and where to check |
| --- | --- |
| Identify the problem clearly | The project addresses scattered rental/payment records: identifying the tenant, room and month paid, distinguishing a tenant report from actual receipt and retaining a shared history. It records payments rather than transferring money. |
| Identify tenants who have/have not paid | Landlord → My tenants lists named tenants, property/room, rent status and balance. Month, search and status filters include records with no payment. |
| Explain bank payments and another receipt | Cash, EFT and PayShap are paid outside the app. The tenant reports the transaction/reference; the landlord checks actual receipt. The landlord's rental receipt acknowledges that same money and specifies its rent month/purpose. It is not another transaction or automatic bank verification. |
| Include rental particulars | Property terms capture shared details once. The rental editor retains the tenant's room, addresses, duration and responsibilities. Move-in date and deposit come from onboarding and are read-only. An incomplete historic record still needs actual details; the app does not create a signed lease. |
| Show the property and monthly history | Rental details identify the property/address/room; the tenant can open its address in Google Maps. Monthly rental account and payment history retain month-specific charges, payments, credit and dated changes. |
| Give each role relevant functionality | Landlord: collections, unpaid rent, rooms, tenants and reports. Tenant: their rental, due amounts, payment/deposit reports, receipts and issues. Report and notification paths are role-scoped. |

## Decisions from the screenshot review

- **Rent due day:** fixed at the 1st. First partial-month rent remains due at actual move-in.
- **New rent starts:** a month picker, not a typed payment day. It shows the selected tenant/room, current rent, new amount and increase/decrease. It records a change for that tenancy only and notifies the tenant. Earlier charges stay unchanged.
- **Rent increases:** there is no verified universal rule requiring identical increases for every room, a single annual interval or a universal 10% cap. Record the applicable agreement and required notice; saving in the app does not itself authorise an increase. See the source-backed research audit.
- **Overpayment:** the app proposes the chosen month's remaining rent first, then following months. For R2,000 against R1,200 now, it proposes R1,200 now and R800 next month, leaving R700 of next month's R1,500 after confirmation. The tenant checks the split before sending. The landlord confirms the proposal unchanged or rejects it with an explanation; the server prevents silent reassignment. Cash received directly can still be recorded by the landlord using the tenant's instructions.
- **Payment purpose:** payment details and landlord attention rows explicitly identify Rent; deposit reports identify Security deposit. Deposits do not reduce rent balances.
- **Payer identity:** the tenant's rental identity remains fixed. “Someone else paid” is optional and records the actual payer without changing the tenant. The bank reference is a separate field.
- **Property information:** address, shared facilities, payment instructions, utilities, house rules and notice/increase terms are entered once under Property terms. New tenancies receive a copy. Existing agreements do not silently change when property defaults change.
- **Move-in/deposit:** the ordinary agreement editor cannot change the actual move-in date or recorded deposit amount. Property deposit defaults apply to new tenants. Existing financial history is retained.
- **Maps:** address links open Google Maps search using the entered address. GPS capture has been removed from this flow. The Anfield Residence identity/exact map pin was not verified; the app does not invent coordinates. Property editing remains a compact owner-only toolbar action.
- **Problems:** tenants choose a category and location, describe the problem and send it. The form closes/clears after success. Issue cards show Submitted, Acknowledged, In progress or Resolved; replies appear inside the opened card. Existing separate reports are retained rather than deleted as apparent duplicates.
- **Notifications:** new notices identify their tenant/room and purpose and open the relevant payment, deposit or issue. Older notices without stored targets open the appropriate list; the app does not guess a tenant.
- **Logout:** the top-right door/exit control is present on signed-in pages. Its anchored menu asks for confirmation beside the icon, with Cancel and Log out.
- **Icons:** the application uses standard Flutter Material icons. The home mark is a conventional outlined house. External browser/hosting assistant overlays are not application features.
- **Persistent login:** normal browser restarts restore a valid saved Supabase session. Explicit logout, cleared browser storage or a revoked/expired non-refreshable session require login again. Use separate browser profiles/private windows when testing both roles. Private browsing cannot promise storage after all private windows close.
- **Optional Login ID:** nine digits, grouped for readability, with the same password. It is an identifier, not a second security factor. It remains hidden until its server endpoint is deployed and enabled. Email/password login remains supported. See `setup/OPTIONAL-LOGIN-ID.md`.

## Plain-language agreement fields

| Field | Meaning / scope |
| --- | --- |
| Ongoing monthly rental | Continues monthly until ended with the required notice; it does not mean rent may change every month. |
| Fixed-term rental | Has an agreed end date. It still has monthly rent and a separate rent-change arrangement. |
| Landlord address for written notices | Where formal rental communications can be delivered; shared property term. |
| Tenant address for written notices | The tenant's address for formal communications, normally prefilled with property and room; tenant-specific. |
| Authority to rent out property | Owner or agent authorised by the owner. A recorded statement does not verify ownership. |
| Room description | The particular room/space rented; prefilled from its room and address. |
| Shared spaces and access | Bathrooms, taps, yard or gate access common to the property. |
| How tenants should pay | Cash/bank arrangement and reference instructions; never a PIN or password. |
| Notice to end rental | The actual agreement and applicable notice requirements. It is not automatic permission to evict. |
| Other charges / utilities | What is charged, how calculated and who pays water/electricity. |
| Emergency contact | An optional contact for that tenant; not the payer, landlord or account password. |

## Activation

For an existing release 1.4.0 database, apply `downloads/BackyardPay-Review-Update.sql` once, then upload `BackyardPay-Netlify-web.zip` to the existing Netlify project. This update is additive; do not reset the database. The optional Login ID requires its separate server-function deployment and explicit activation. Core email login and session persistence do not depend on that optional activation.

The deployed website changes only after its web upload. Source-code publication alone does not deploy the website or update Supabase.

## Verification

- 105 Flutter tests passed; static analysis examined 78 Dart files with zero issues.
- The Chromium contract passed shared property terms, assigned-room signup, an overpayment split, unchanged landlord confirmation, subsequent-month remainder, deposit report/receipt, actionable issue notification, acknowledgment/progress/resolution, logout and session restart. Its backend transport is simulated.
- The complete disposable PostgreSQL suite passed all migrations and the four new migration replays, permissions, preserved history, fixed onboarding fields, targeted notices, Login ID default-off/rate limits and preserved payment proposals. No hosted records were seeded.
- Startup, mobile navigation and address-query checks passed. The optional ID endpoint passed its isolated server contract.
- Live database activation, optional function deployment and Netlify publication remain owner deployment steps.

## Screenshots

The following use isolated test accounts in release 1.5.0: [rent change](review/screenshots/rent-change.png), [agreement](review/screenshots/agreement.png), [logout](review/screenshots/logout.png), [issue status](review/screenshots/issue-status.png). Some report dates use an advanced test clock.

The 47-file release archive passed integrity checks. SHA-256: `f1ff1becf861639b106d70cb00c43cdaf7ee8eeb3160602f4267cfdf3bdbddc4`. ClamAV 1.5.4 reported zero infected files using cached signatures dated 1 November 2026; this does not establish Microsoft Defender clearance.
