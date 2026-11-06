# BackyardPay: research implementation audit and assessment plan

6 November 2026. Audited against the supplied **BackyardPay Research Report** and **APT41P2 Project Guidelines 2026**. Document content is assessment/research evidence; the user's request authorises implementation. The app remains a Flutter mobile application with a web development release, separate landlord/tenant accounts and Supabase storage. Its direction fits the guideline. The earlier build was insufficient for the researched transaction model.

## Every lecturer comment

| Comment | Finding before this update | Implemented response | Evidence / remaining limit |
|---|---|---|---|
| C1: unclear problem | A broad payment-tracking claim did not establish a local need. | The project now distinguishes money received, allocation to rental charges, lease particulars and records shared between parties. | See the problem hypothesis below and the research report's source register. East London participant validation is still required; fictional personas are not participants. |
| C2: incomplete paid/unpaid records | Tenant submissions and one-payment/one-month assumptions omitted cash received without app use and ambiguous allocations. | Landlord-created tenant records without accounts; private invitation to claim existing history; landlord-recorded received money; named monthly account including no-submission months; multi-month allocations, partial payment, unallocated credit, dated rent and documented adjustments. | PostgreSQL tests exercise amounts, credit, old debt, future rent, access and actual handover. Balances are confirmed-record balances, not legal determinations of default. |
| C3: bank vs landlord receipt | A bank reference alone did not explain rental accounting. | Cash, bank cash deposit, EFT, PayShap, debit order and other received-payment records; actual payer separate from tenant; allocations and separate bank/receipt references; rental receipts for all confirmed methods; frozen issue details; evidenced full returns/reversals retain the original receipt and stop its allocations from reducing balances. | No money transfer, bank login, debit-order mandate or automatic bank verification. Uploaded files remain user-supplied evidence. Later credit allocation updates the statement, not the original receipt. |
| C4: lease essentials | Existing basic dates/deposit/utilities fields were insufficient. | Formal addresses, authority to let, dwelling/yard description, shared facilities, payment instructions, notice, escalation, other charges; dated changes and audit history; separate deposit receipts/interest/refunds/deductions; entry/exit records; private supporting files. | Records and acknowledgement do not establish ownership, jointly agreed inspections or signed legal leases. No automatic interest rate or universal proration rule is invented. Legal templates and arrangement-specific procedures still need review. |
| C5: location/monthly history | Location needed a full dwelling identity and continuous account. | Existing street/stand, area, city, postcode, room and optional GPS are retained. Receipts identify the dwelling; statements retain each charge month and allocations. Planned expiry is separate from actual handover. Previous rentals remain accessible. | A GPS pin is supplementary, not ownership evidence. Existing incomplete historical addresses/terms must be supplied honestly; the upgrade does not invent them. |
| C6: stakeholder dashboards | Shared totals did not guide stakeholder decisions. | Landlord sees named tenant balances and review actions, credit, open issues and missing lease/inspection/continued-term flags; tenant sees their charges, records, lease/deposit/inspection evidence and repair/account query thread. | Landlord changes workflow status; either party can add a message. This is not a tribunal decision. Notifications remain in-app; no background mobile push is claimed. |

## Problem and scope, ready to refine with local findings

**Research-informed hypothesis:** Some landlords and tenants in East London's backyard rental sector may find it difficult to connect payment evidence with the correct dwelling, rental period, agreed charge and remaining balance. A bank transaction, a cash receipt and a rental account answer different questions. BackyardPay supports shared, retrievable records of these events and conditions, including payments received before a tenant installs the app. The frequency and severity of this problem among intended East London users have not yet been measured. Published findings about other cities must remain identified as such.

The supported billing model is monthly rent with dated rates and explicitly documented charge adjustments. An agreed partial-month charge can be recorded as an adjustment. Weekly/non-monthly billing, automated utility sales, bank feeds, payment collection mandates and legally automated debt recovery are outside this release. Deposit events remain separate from rent. Do not split one actual bank transfer into invented transfers; record one event with its allocations. Actual refunds/interest/deductions require supporting evidence and applicable legal conditions, not an assumed fixed formula.

## Marking guideline crosswalk

| Assessment item | Required submission | Current position / next evidence |
|---|---|---|
| Title/cover — 5 | Relevant title, student/project information, professional presentation | Use “BackyardPay: Shared Records for Backyard Rentals”, Mbongiseni Nkambule, APT41P2, 2026; add actual student number, institution and lecturer. Do not invent missing details. |
| Context — 15 | Maximum one page; community need, background, target users, mobile suitability | Use the hypothesis above, qualified published evidence and future actual local validation. Explain recording cash at the point of payment, phone access to evidence and permission-based location compared with desktop-only use. |
| Goal/objectives — 10 | Half a page; functionality and inputs/processes/outputs | Goal: maintain understandable, shared monthly rental records. Inputs: parties/dwelling/terms, payments/payer/evidence and cases. Processes: access control, reconciliation, allocation, charge/deposit calculations. Outputs: role dashboards, receipts/statements, history and in-app alerts. |
| Manual/functionality — 25 | Maximum five pages with screenshots, navigation and mobile features | Capture final release screenshots using the five-page plan below. Browser development screenshots do not prove real Android permission/notification behaviour. |
| Code appendix — 20 | Three to five pages of selected explained code | Use four pages: models/cents; Supabase RPC and RLS; dated charges/allocations; Flutter state/forms + private files. Explain why each check exists. Do not submit the entire repository as the appendix. |
| Oral/demo — 20 | Twenty-minute presentation and successful demonstration | Follow the timed runbook below; rehearse on the actual intended phone. Automated tests support but do not replace live demonstration and questioning. |
| References — 5 | Relevant sources and consistent referencing | Reuse the report's verified source register with consistent citations/access dates. Keep primary research, law, national banking material and evidence from other cities distinguished. |

### Five-page manual plan

1. Account access and separate role dashboards. Register landlord/tenant; existing email/password login remains. Development email-confirmation setting is unchanged.
2. Add property and tenant record; complete lease details; privately invite tenant to existing room/history. Explain permission-based location.
3. Record received cash or report EFT; identify payer, reference and allocation; reconcile on landlord side; retrieve rental receipt. Distinguish pending from confirmed.
4. Monthly account, older debt, multiple allocations, credit, dated rent and actual handover; download statement and retain earlier tenancy history.
5. Deposit account, entry/exit evidence, private documents and repair/account query thread; show in-app alert and clarify it is not background push.

### Twenty-minute runbook

- 0–3 minutes: community problem, qualified research findings, scope and mobile rationale.
- 3–6: landlord property, offline tenant record, full lease particulars and location.
- 6–11: one cash payment and one EFT report; reconcile and allocate across months; show receipt vs bank evidence, named unpaid/partial account and retained credit.
- 11–14: tenant view, continuous statement and dated rent change without rewriting history.
- 14–17: separate deposit/inspection/evidence and repair/query workflow.
- 17–19: architecture, server permissions, calculation tests and real mobile features demonstrated on-device.
- 19–20: limitations and next validation; reserve concise answers for questions.

## Activation and limitations

This is an additive upgrade, not a database reset. Apply **BackyardPay-Research-Update.sql** to the existing project before publishing the new web ZIP. Do not run the original migration again after the upgrade: its old RPC definitions would replace the new ones. Take a database backup/export first. The upgrade backfills existing one-month allocations and opening deposit records without issuing fictitious new receipts. Existing accounts and records are retained. Existing incomplete historical receipt details are labelled as such.

Supabase project configuration remains the owner's responsibility. No service/admin secret is included. Email/password authentication and role/database permissions remain; this update does not enable email confirmation. To avoid SMTP during development, Confirm email must remain off in the project's email-provider settings.

The hosted Netlify application could not be inspected from this environment because its hostname is not allowed by the network policy. Source, local release and isolated database checks are the audit basis. Hosted SQL/storage activation, actual browser file transfer, real Android installation/GPS/alerts, local usability interviews and the final page-limited submission remain explicit acceptance work. No assessment score is guaranteed.
