# BackyardPay: rental-practice research and response to lecturer feedback

**Desk research completed: 6 November 2026. Setting: backyard rental accommodation in East London / Buffalo City, Eastern Cape, South Africa.**

## 1. What this investigation establishes

BackyardPay should be justified as a shared **tenancy, rental-account and receipt record**, not as a substitute for a bank. Research supports considering both cash and electronic payment workflows, identifying exactly what is being rented, and distinguishing rent, deposits and other agreed charges. The tenant needs access to the same underlying account as the landlord, with an explanation of charges, payment allocation and anything awaiting reconciliation.

Three findings are especially important. First, the Rental Housing Act requires a landlord's written receipt for payments received; a bank payment record does not make the landlord's rental-account obligation disappear [S1–S2]. Second, backyard rental is not a single uniform market: it can mean renting a room, renting an entire backyard structure, or renting space for a tenant-owned structure [S4–S5]. Third, the published evidence consulted does **not** establish how frequently East London landlords use each payment method or experience recordkeeping disputes. That local claim needs a small primary investigation rather than invented evidence.

**Evidence versus recommendation:** statements attributed to sources below are research findings. Proposed fields, workflows, dashboards and acceptance criteria are design recommendations derived from those findings, not claims that every existing landlord already works that way. The application was not changed during this investigation.

## 2. Method and limits

All six comments embedded in the supplied Word document were read, together with its body and screenshots. They are listed individually in section 10. The report's fictional Themba and Andile personas are design hypotheses, not interview participants.

The desk review prioritised original legislation and government information, a neighbourhood-level backyard-rental survey, a research report on small-scale rental, bank guidance, and a clearly labelled commercial product comparison. Full source pages or PDFs were read. Search snippets were used only to locate material and are not cited as evidence. Source register entries give the URL, date where available, relevant section and limits. Access date is 6 November 2026 throughout.

Published neighbourhood evidence is from Cape Town, principally Palm Park in Eerste River in 2020. It cannot be relabelled as East London research or treated as a 2026 payment-method estimate. Local Buffalo City planning material and the Eastern Cape tribunal page provide geographic and institutional context, not transaction-frequency evidence. Some attempted sources could not be retrieved, including the SAFLII consolidated Act and some housing/research/banking pages. No claims rely on unread pages. The government original Act was therefore read alongside the enacted 2007 amendment, with a separate check of the government's 2014 amendment commencement listing.

## 3. How backyard rental actually varies

### 3.1 The dwelling and parties must be understood first

The Palm Park profile distinguishes households renting a structure from households owning a structure and renting yard space; it also identifies tenants in rooms in the main house and residents who do not necessarily pay rent. Family connections and household contributions complicate a simple one-room/one-person picture. It notes that different household members may contribute to rent [S4, printed pp. 29–31; PDF pp. 30–32]. A contributor or payer must therefore not automatically be treated as the legal tenant.

Scheba, Turok and du Trevou distinguish conventional backyard accommodation from more formal small-scale brick-and-mortar rental development. Their 2022 report focuses on the latter and explicitly recognises variation between developers. Its evidence includes 30 expert interviews and 21 homeowner/micro-developer interviews, principally in Cape Town in the second half of 2021 [S5, printed pp. 9, 16–17; PDF pp. 11, 18–19]. Findings about professional micro-developers cannot simply be attributed to a household letting one backyard room.

Buffalo City's IDP 2021–2026 recognises backyard rooms within its dwelling classifications and acknowledges backyard dwellers in its housing policy discussion [S9, pp. 85, 221]. It establishes local relevance, but it does not establish the preferred rent-payment method in a particular East London neighbourhood.

**Recommended initial target:** a household landlord or authorised manager with a small number of rented rooms or units, and the tenants responsible for their rent. Determine through local interviews whether tenant-owned structures/yard-space leases must be supported immediately. Do not describe all backyard accommodation as unlawful, all landlords as title holders, or all occupants as rent-paying tenants. A GPS coordinate and an account registration do not establish authority to let.

### 3.2 Cash and electronic methods coexist

The Palm Park survey documents cash, EFT, debit order and bank-app payments. Its Table 35 records **78 cash responses and one EFT response among 79 backyarder-household responses**; the table also includes separate main-house-tenant and landlord-household categories. Table 36 documents widespread absence of signed rental agreements. These findings support including cash and informal-agreement scenarios, but not a national or East London percentage [S4, printed p. 42; PDF p. 43].

Source-quality caution: the narrative summaries, category denominators and some sample descriptions in this report are not entirely consistent. For example, the executive summary and the detailed payment table must not be combined into a claim that a fixed percentage of all South African backyard tenants pay cash. Use the exact table/category if quoting counts; otherwise describe the finding qualitatively. The sample table distinguishes 257 households from the number of erven surveyed [S4, printed p. 10; PDF p. 11].

The same profile reports generally friendly relationships. It does not support claiming that informal agreements inevitably produce disputes [S4, printed pp. 41–43]. A useful system should support existing relationships and provide traceability when needed, rather than assume dishonesty.

### 3.3 Candidate payment workflows to validate locally

| Method or situation | What happens outside BackyardPay | What the rental record should show |
|---|---|---|
| Cash handed to landlord/authorised collector | Money changes hands directly. | Recipient, date, amount, payer/tenant, dwelling, payment purpose and rental period; issue the landlord's receipt when receipt of cash is established. |
| Cash deposited into a bank account | Cash enters banking channels through a permitted bank facility. | Record as a bank cash deposit rather than a direct cash handover; match the deposit to the beneficiary's account and the rental charge. Confirm each bank's actual procedure. |
| EFT | Payer instructs a bank transfer to the agreed beneficiary. | Bank reference and transaction date, payer where needed, amount received and allocation. A payer's upload and a beneficiary's reconciliation are different events. |
| PayShap | Payer uses their bank's supported PayShap function and beneficiary details/ShapID. | Transaction reference, amount and recipient-side confirmation, then rental allocation. Capitec describes real-time payments and checking transaction history/recipient information if a payment has not reflected [S7]. |
| Debit order / standing arrangement | Bank/payment provider executes an agreed instruction where available. | Actual transactions and reversals, not just the existence of an instruction. A collection mandate is not implemented by an ordinary rent-record form. |
| A relative or employer pays | Payment comes from someone other than the tenant. | Keep payer distinct from tenant; link it to the correct tenancy without disclosing unnecessary information about the payer. |
| One payment covers arrears and current rent | One transfer or cash amount is received. | Keep one payment event with multiple explicit allocations; do not invent additional bank transfers. |
| Tenant pays before installing the app | Money has already been received. | Landlord can record it and supply a receipt; tenant self-submission must not be the only entry route. |

The survey demonstrates methods used in its sample. The table's detailed recordkeeping workflow is a proposed design to be checked with intended users; it is not a measured account of every East London transaction.

## 4. The bank question: why have a landlord receipt?

### 4.1 Four different records answer four different questions

| Record | Question it answers | What it does not establish by itself |
|---|---|---|
| Bank proof/payment confirmation | What transaction the issuing bank reports from the payer's side. | Which rental charge the landlord has allocated it to; an image by itself does not establish authenticity or recipient-side reconciliation. |
| Beneficiary transaction record | What the landlord's bank records as received, subject to that payment method's status. | How the landlord has split it between rent, arrears, deposit or other agreed amounts. |
| Landlord's rental receipt | What the landlord acknowledges receiving for the identified dwelling, purpose and period. | That BackyardPay itself transferred money, or that the bank independently verified an app entry. |
| Rental account statement | Charges, allocations, adjustments and balance over time. | A new payment or an additional amount due merely because the statement exists. |

Section 5(3)(a) of the Rental Housing Act says the landlord must furnish a written receipt for payments received from the tenant. Section 5(3)(b) requires its date, dwelling address/further description, payment purpose and period. The 2007 amendment adds a limited tribunal exemption mechanism for the paragraph (b) information; it is not an app checkbox allowing a landlord to omit everything [S1–S2]. The receipt provisions do not state a cash-only exception.

Therefore, the answer to the lecturer is: **the bank record concerns the money transaction; the landlord's receipt acknowledges and allocates received money to the rental relationship. They refer to the same payment, not two payments.** A receipt should make that link clear. For EFT, a suitable proposed label is **“Rent receipt — payment received by EFT”**, including the bank reference and a separate receipt identifier. Merely renaming the PDF an “acknowledgement” does not establish that it contains all the receipt information required.

Capitec's safety guidance instructs a seller to confirm that money is actually in their account before releasing goods [S8]. That is banking-risk guidance in a selling context; applying its recipient-side check to rent reconciliation is a design recommendation, not evidence that backyard tenants commonly commit fraud. Capitec's PayShap FAQ also advises checking payer transaction history and recipient-side information when payment has not reflected [S7].

### 4.2 What banking details are useful?

For an agreed bank-payment method, the tenant needs the correct beneficiary name, bank and account/ShapID details, any bank-required account/branch information, and a stable rental reference. These are operational payment instructions, not all statutory lease fields. How to confirm beneficiary changes, display account details securely and maintain a change history should be agreed before implementation. They should not be exposed to unrelated tenants or made public on a map.

BackyardPay must not request bank PINs, OTPs or bank-login passwords. Payment should occur in the bank's own supported channel. Without a bank/provider integration, the app can record **landlord-confirmed receipt**, but cannot honestly display “bank verified”. Connecting to a database or accepting a screenshot does not connect the app to bank settlement systems.

For a future bank integration, separately investigate the provider, participant/merchant onboarding, authorisation, consent, transaction status/webhooks, duplicate events, settlement, failures/reversals, fees and applicable payment rules. The existence of PayShap in a bank app does not mean this project already has access to initiate PayShap requests or collect funds.

### 4.3 Do not equate an administrative status with a legal fact

A tenant may have paid correctly while the landlord has not reconciled it. Show the confirmed balance and the tenant-reported payment awaiting review separately. “Unconfirmed in the app” is not proof that no money was received. Provide a dispute/query path and show when the information was last updated. Likewise, a rejected app submission is not a tribunal judgment or eviction authorisation.

A PDF is a delivery format, not an automatic guarantee of legal compliance or a valid digital signature. Keep the receipt contents, issuer, transaction linkage and correction history clear. A “read” acknowledgement of rental details must not be misrepresented as both parties signing a lease.

## 5. Critical information when renting or leasing

### 5.1 Legal position must not be guessed

The statutory definition of a dwelling includes rooms, outbuildings and shacks; a backyard setting is not automatically outside the Act [S1, s. 1]. The original Act's s. 5(1)–(2) allows an oral lease but requires it to be put in writing if the tenant requests. The government's page for the 2014 Amendment Act states that commencement is to be proclaimed. This review did not verify a later commencement proclamation; do **not** claim, on the basis of that amendment's publication alone, that its universal written-lease provision is already in force [S3]. Written terms remain a sensible design recommendation.

The checklist below uses the Act's baseline alongside the enacted 2007 changes. A final lease template and any disputed applicability should be checked with the Eastern Cape tribunal or a qualified adviser. The Consumer Protection Act may affect a fixed-term rental supplied in the ordinary course of business; its s. 14 should not be applied indiscriminately to every private arrangement [S12].

### 5.2 Checklist, classified by purpose

| Information | Classification / reason | Suggested record |
|---|---|---|
| Parties and authority | Names and addresses for formal communication are part of the written-lease particulars under s. 5(6). The statutory landlord includes an authorised agent or other person with a lawful right to let. | Tenant(s), landlord/authorised agent, roles and formal-notice addresses; contact methods separately. Do not treat a map pin as ownership proof. |
| What is rented | Description of the dwelling is a written-lease particular. | Street/stand description, area, city, room/unit identifier and whether the rental is a structure, room or yard space; describe shared facilities. GPS is supplementary. |
| Rental price and escalation | Written-lease particulars include rental and reasonable escalation, if any, payment frequency where not monthly, and additional charges [s. 5(6)]. | Agreed amount, frequency, due date/payment arrangements and effective dates of changes. Retain past terms. Due date and payment instructions are recommended explicit operational fields. |
| Duration and notice | Lease period or applicable notice particulars are included in s. 5(6); periodic continuation is addressed in s. 5(5). Other applicable law can change cancellation rules. | Start, fixed term or periodic arrangement, notices, extension/continuation and actual move-out/handover. Do not automatically erase obligations or history at an end date. |
| Deposit | Agreed deposit, if any, is part of the particulars. The Act addresses investment, interest, evidence, deductions and refunds [s. 5(3)(c)–(n), as amended]. | Agreed amount, actual receipts, interest evidence, supported deductions and refund events. Keep deposit funds distinct from rental income. |
| Entry and exit inspections | Joint inspection and defects procedures support deposit accounting [s. 5(3), (7)]. | Date, participants, defects/inventory, photographs where appropriate, rectification and exit comparison; attach agreed defect list. |
| House rules and responsibilities | Written-lease obligations, applicable house rules and defects annexures are covered by s. 5(6)–(9). | Utilities/shared facilities, access, maintenance responsibilities, lawful rules and attached terms. A vague “utilities included” switch may be insufficient. |
| Receipts | Written receipts for payments received, with dwelling, purpose and period [s. 5(3)(a)–(b)]. | Issuer, payer/tenant, date, amount, method, rental purpose/period, property/room, receipt ID and linked bank/app references. Some of these are recommended clarity fields beyond the paragraph's express list. |
| Rights and dispute route | Privacy, reasonable inspection notice and tribunal processes matter [s. 4 and ch. 4]. | Maintenance/query history, notices and exportable records; Eastern Cape tribunal information. No automatic lockout or utilities shutoff. |
| Optional contact information | Useful only where a clear purpose exists; not every desirable field is mandatory. | Optional emergency contact with an explained purpose, if needed. Avoid unnecessary ID copies and complete bank statements. |

### 5.3 Deposit and inspection details cannot be reduced to a single number

The 2007 amendment to s. 5(3)(d) refers to interest at the applicable account rate, not less than the savings-account rate at that financial institution, and to proof of accrued interest on request. Do not invent one universal interest rate in the app. Special rules may apply where a regulated property practitioner holds funds [S1–S2].

The Act distinguishes refund situations: no amounts owing, deductions supported by costs, and a tenant who does not respond to the exit inspection request. The baseline provisions use different deadlines—seven, fourteen or twenty-one days depending on the circumstances. A universal “refund after 30 days” rule would be unjustified [S1, s. 5(3)(f)–(n)]. Final workflow/legal review must retain the conditions, not just select one deadline.

The 2007 amendment also expressly addresses unlawful lockout/utilities shutoff and excludes eviction applications from tribunal jurisdiction [S2, ss. 6, 8]. The Eastern Cape tribunal's general webpage describes its dispute services, but it should not be read as giving it unlimited magistrates' court jurisdiction [S10]. A warning or balance in BackyardPay must not trigger automatic eviction.

### 5.4 Utilities and maintenance require understanding, not immediate feature expansion

The Palm Park study documents services delivered through the main house and discusses uncertainty about maintenance responsibilities [S4, services and maintenance chapters]. Renting a tenant-owned structure differs from renting a landlord-owned room: responsibilities cannot be inferred from occupancy alone.

Record who pays for water/electricity, whether included or separate, shared versus individual metering, agreed calculation/evidence, maintenance reporting and access arrangements. A prepaid top-up is not by itself evidence of that tenant's electricity consumption or a legal basis for an extra rent charge. Decide whether detailed meter accounting belongs in scope only after studying local arrangements and tariffs. Basic maintenance reporting/inspection evidence may be more central to the lease than a sophisticated electricity-loading feature.

## 6. Complete monthly accounts, not a list of submitted payments

A payment-history list cannot identify everyone who owes rent because people who submit nothing may disappear. Begin with the tenancy and agreed charges for the relevant dates. Recommended distinct records are: property/unit; tenancy/parties; dated rental terms; charge; payment event; allocation; receipt; deposit account; adjustment/refund; and relevant evidence/queries. These are design recommendations, not a demand to implement a large accounting package immediately.

For each tenancy, the proposed statement calculation is:

**Closing balance = opening balance + charges + justified debit adjustments − allocated confirmed payments − justified credits.**

Do not add last month's arrears a second time if it is already in the opening balance. Keep deposits separate. A historic rent amount must not change merely because the property default is edited today. Mid-month charging, advance payments, changes of tenant and final bills must follow the actual agreement and applicable rules; a universal full-month charge is a product limitation, not a legal conclusion.

### Worked example — hypothetical, not participant data

Assume rent was R1,500 for September and October and changes by recorded agreement to R1,600 from 1 November 2026. Ignore utilities/adjustments for this example.

| Statement period | Opening debt | Rent charge | Confirmed money allocated in period | Closing debt at period end / reporting date |
|---|---:|---:|---:|---:|
| September | R0 | R1,500 | R900 | R600 |
| October | R600 | R1,500 | R2,100 | R0 |
| November, as at 6 November | R0 | R1,600 | R1,000 | R600 |

The October R2,100 is **one payment**: allocate R600 to September arrears and R1,500 to October. As at 6 November, September and October charges are settled. September's historical month-end balance was still R600; an as-of-today charge view and a historical month-end statement must not be confused.

A further R400 reported by the tenant but awaiting reconciliation is shown separately. The confirmed-record balance remains R600, with R400 awaiting review; the app should not assert that the tenant definitely failed to pay it. A separate R1,500 deposit is excluded from these rent totals. If more money is actually received than can be allocated, retain an unallocated credit/refund workflow rather than pretend that the bank could not receive an overpayment.

This exposes requirements the old single-month form did not establish: one payment to multiple periods; historical terms; pending reconciliation; advances/credits; and the ability to record money received without requiring the tenant to initiate an app submission.

## 7. Property location and evidence

The rental record should identify **the exact accommodation**, not just “East London”. Use the available street/stand description, locality, municipality and a stable room/unit description, including shared facilities and what is excluded. Where an address is incomplete, record a useful supplementary description and validate it with the parties. Do not invent a postal code or stand number.

A map point may help locate a property, but it cannot identify a particular room in a shared yard, establish ownership, certify building approval or replace the lease's dwelling description. Avoid continuous location collection; provide permission-based capture and correction if needed. Retain historic tenancy/address associations so a person who moves can still identify old receipts. Location and financial information fall within personal-information considerations [S11].

## 8. Distinct dashboards, derived from decisions

The fields below are recommendations justified by the rental workflow and receipt/lease requirements. Test their priority with intended users before designing more screens.

| Landlord question | Recommended information/action | Tenant question | Recommended information/action |
|---|---|---|---|
| Who is due to pay? | All relevant tenancies, amount/due date, property/unit and period; no-submission tenants remain visible. | What am I expected to pay? | Current agreed charge, due date and a clear breakdown of rent versus other charges. |
| What money has been received? | Reconciled receipts, separately from submissions awaiting review; bank/cash method and payer/reference where relevant. | Was my payment recorded? | Submitted/received/allocated status, linked receipt and a query route. |
| Who has an outstanding recorded balance? | Named tenant list, current and older debt, credits and unresolved queries. Avoid treating pending as proven default. | How was my payment used? | Charge-period allocations and a continuous downloadable statement. |
| What needs attention? | Unreconciled payments, expiring/continuing terms, missing inspections/terms, deposits/refunds and open repairs. | What are my rental conditions? | Dwelling/room, landlord contact, terms/house rules, deposit statement and inspection/repair records. |
| What changed over time? | Dated rent terms, occupancy and auditable adjustments, with historical reporting. | Can I retrieve my evidence after moving? | Historic statements, receipts, notices and documents for that tenancy, with appropriate access/retention. |

A trend chart and portfolio total can help, but cannot replace the named records behind the numbers. A tenant dashboard must not simply reproduce the landlord's collection dashboard.

## 9. What already exists, and the gap that still needs proof

A bank app offers payment facilities and transaction records. Notebooks/messages can provide flexible, low-cost records and social communication. PayProp advertises bank-integrated collection/reconciliation, arrears management, accounting, reporting and maintenance for rental agents [S13]. These are vendor descriptions, not an independent evaluation or proof that its price and onboarding suit a landlord with a few rooms.

BackyardPay cannot claim novelty just because it records rent digitally. Its proposed niche is a simpler shared record for small backyard landlords and their tenants, supporting cash as well as externally paid electronic money, complete tenancy-linked statements, rental receipts and essential lease evidence. Whether that niche is valuable and affordable in East London must be checked. Do not claim that an app will solve housing shortages, insecure title, inadequate infrastructure, inability to pay rent, or all landlord–tenant conflict.

### Proposed problem statement — a research-informed hypothesis

> Small backyard rental arrangements can involve cash or electronic payments, verbal or written terms, shared addresses and payments contributed by more than one household member. Bank transaction records alone do not describe the full tenancy, agreed rental charges, allocation across months, deposit position or the landlord's receipt of money. BackyardPay proposes a shared tenancy-linked record that makes these matters traceable for the landlord and tenant. The frequency and practical consequences of these recordkeeping gaps among the intended East London users will be validated through local interviews and walkthroughs.

This statement explains the proposed gap without asserting that all target users keep poor records. After primary investigation, revise it to name the actual recurring problem, affected users, current alternatives and demonstrated consequences.

## 10. Response to every lecturer comment

| ID and lecturer comment | Research answer | Proposed requirement / acceptance check | Remaining uncertainty |
|---|---|---|---|
| C1: “What is the problem to be addressed? The problem should come out clearly” | Rental transaction evidence, lease particulars and a complete rental account are distinct. Backyard relationships vary and may work well already [S1, S4–S5]. | Use the hypothesis above, then support it with local findings. A reader should understand the user, context, problem and gap before seeing screenshots. | Do East London users actually experience the proposed gap often enough to justify an app? |
| C2: “This has incomplete records. How does he know the tenant who has paid or has not paid from this?” | A submitted-payment list is incomplete; obligations and allocations must be recorded separately. | Show every tenancy/charge for a selected period, including zero submissions. Demonstrate partial payment, late allocation, old debt, credit and changing rent without rewriting history. | Local billing/allocation conventions, proration and who maintains the records. |
| C3: “How does this work with a bank? … Why would someone getting another receipt from the landlord when you have proof of payment from the bank?” | Bank evidence and a landlord receipt answer different questions; statutory receipt obligations remain [S1–S2, S6–S8]. | One payment, bank reference plus rental receipt ID, explicit allocation and issuer. No “bank verified” label without integration. Demonstrate cash and EFT. | Accepted beneficiary instructions, local methods, third-party payers, reconciliation times and integration costs/requirements. |
| C4: “This is poorly done. This lacks critical details required when renting or leasing property” | Names/formal addresses, dwelling, rent/escalation/frequency, deposit, period/notice, obligations/extra charges, defects and house rules are substantial requirements [S1–S3]. | Review the classified checklist; demonstrate deposit/inspection evidence and historical terms. Do not claim a read button signs a legal lease. | Final legal template, commencement checks and arrangement-specific obligations. |
| C5: “Where is this property? How does it account for monthly history in the tenant’s account?” | A town name or GPS pin is insufficient. The unit and a continuous account need explicit identification. | Property/stand plus room and agreed description on tenancy and receipts; all charged months visible, even without a payment. Carry forward once and preserve previous tenancies. | Address formats, yard-space versus room leasing, final billing and retention needs. |
| C6: “So far the functionality of the app is limited … proper dashboard for landlord and another for the tenant … critical information relevant to each stakeholder.” | Each dashboard should support different decisions, not display an identical summary [S1, S4–S5, S13]. | Landlord has a named actionable overview; tenant has their own charges, allocations, receipts, deposit/terms and repair/query access. Test decision completion, not just appearance. | Which functions are genuinely most useful, affordable and understandable to intended users? |

The comments on “future features” do not automatically require every proposed electricity or incident feature. Assess them against the lease, services and maintenance evidence and the project's achievable scope.

## 11. Local validation before the next building phase

No interviews were conducted for this desk review. Proposed next research: an exploratory set of, for example, five backyard landlords and five tenants in selected East London/nearby Buffalo City areas, with a mix of payment methods and dwelling arrangements. This is a small convenience/purposive sample, not a representative city survey. Obtain consent and anonymise notes. Do not request passwords, PINs or whole financial statements.

Ask each participant to describe a recent real transaction without disclosing sensitive details: method, payer, recipient, reference, period, amount, how it was acknowledged and where it was recorded. Ask what happens with cash, partial/late payments, payments made by another person, money covering two months and disagreement about allocation. Ask how deposits, inspections, utilities, repairs, notices and move-out are handled. Ask to describe any actual difficulty, rather than assuming one. Compare their existing methods with a paper prototype of the proposed statement.

For each interview record: anonymised participant ID; date; role; broad area; dwelling/tenure type; method; recurring task; actual reported difficulty or absence of difficulty; requested improvement; relevant quote with consent; and implications. Never invent names, quotes, counts or percentages. Test phone access, data costs, language, readability and willingness to use a separate app.

Suggested walkthrough checks: can a landlord find who has a confirmed outstanding record for a month in under a minute; can a tenant explain an allocation and retrieve its receipt; can both explain a pending payment without assuming nonpayment; can a person identify their room/terms and deposit position? Set final success thresholds after a small pilot, not as fabricated results.

## 12. Recommended scope and decisions before coding resumes

**Foundation to prioritise:** accurate property/unit and tenancy identification; essential recorded terms and attachments; dated charges; payment events and allocations; landlord-originated cash/bank records and tenant-reported submissions; clear reconciliation; compliant receipt content; complete statements; deposit/inspection records; role-appropriate access and exports. Include a basic repair/query trail if local validation shows it is central.

**Investigate separately:** detailed electricity consumption/meter integration, automated bank feeds/collections, credit reporting, public rental listings, automatic penalties/proration, legal e-signatures and notices. Each involves more than adding a button. Property registration in the app is not land-use/building approval.

**Privacy and retention:** POPIA s. 10 requires information to be relevant and not excessive; s. 11 provides several lawful processing grounds, not consent alone; ss. 13–14 concern purpose/retention and s. 19 security [S11]. Collect only what the rental workflow needs, explain its purpose, restrict access by tenancy, protect stored evidence and agree retention/correction/export procedures. A contract record and a public profile should not share all fields.

**Existing work is not proof that these requirements are met.** The modern interface and shared database can be retained, but the subsequent audit should specifically examine: charge/payment/allocation separation; landlord-originated receipts; multi-period and third-party payments; real overpayments/credits; historical rent terms; deposit interest/refunds; inspections; address/authority details; and pending/dispute wording. This report has not audited or changed the deployed database or application.

Before implementation, review these requirements and the local findings with the lecturer. Present the research, the six-comment matrix, one worked cash/EFT flow and the monthly account example. The next build should follow that understanding, rather than adding features merely to make the app look more complete. No mark is guaranteed by this research or the proposed design.

## Source register

All URLs below were retrieved and read on **6 November 2026**. PDF references identify the reader's PDF page separately from a publication's printed page where relevant.

**S1. Republic of South Africa (1999). Rental Housing Act 50 of 1999.** Government publication, particularly s. 1 and ss. 4–5; PDF pp. 3, 5–7. Primary source for dwelling/landlord definitions, privacy, receipts, deposits, inspections and written-lease particulars. Read with S2; the original PDF alone is not a current consolidation. Government page records initial commencement as 1 August 2000.
https://www.gov.za/documents/rental-housing-act
https://www.gov.za/sites/default/files/gcis_document/201409/a50-99.pdf

**S2. Republic of South Africa (2007; published/commenced 2008). Rental Housing Amendment Act 43 of 2007.** Government page records commencement 13 May 2008. PDF pp. 3–4, especially amendments to s. 5, tribunal eviction jurisdiction and unlawful lockout/utilities shutoff. Primary amendment text.
https://www.gov.za/documents/rental-housing-amendment-act
https://www.gov.za/sites/default/files/gcis_document/201409/gg31051nn539pg1-6.pdf

**S3. South African Government (n.d.). Rental Housing Amendment Act 35 of 2014: document and commencement listing.** The retrieved listing states commencement is to be proclaimed. The listing is not proof that no later proclamation exists; this investigation did not verify one. Used to avoid assuming enactment equals commencement.
https://www.gov.za/documents/rental-housing-amendment-act-0

**S4. Backyard Matters / Development Action Group, VPUU and Isandla Institute (December 2020). Neighbourhood Profile: Palm Park, Eerste River.** Published neighbourhood survey; printed pp. 10, 29–31, 41–43 and services/maintenance chapters; PDF pp. 11, 30–32, 42–44 and related chapters. Table 35 documents payment methods and Table 36 rental agreements. Cape Town case evidence, not East London or a national estimate. Some summary/denominator inconsistencies require caution; this report relies on the named table categories and qualitative findings.
https://www.dag.org.za/wp-content/uploads/2023/10/dag-np-palm-park-eerste-river-lr-1.pdf

**S5. Scheba, A., Turok, I. and du Trevou, C. (April 2022). Small-scale Rental Housing: Moving from the Low Road to the High Road. Development Action Group.** Scope printed p. 9; methods pp. 16–17; PDF pp. 11, 18–19. Primary mixed-method research report commissioned by DAG, with 30 expert and 21 developer interviews plus other methods. Focuses on Cape Town small-scale brick-and-mortar development, which is not identical to all backyard arrangements.
https://www.dag.org.za/wp-content/uploads/2022/04/Small-Scale-Rental-Housing-Moving-From-the-Low-Road-to-the-High-Road.pdf

**S6. Capitec Bank (n.d.). Make a payment.** Bank's own operational guidance distinguishes EFT, immediate payments, PayShap and other options. It is one bank's guidance, not a survey of tenants or universal banking procedures. Unrelated product/fee information on the page is not used.
https://www.capitecbank.co.za/personal/transact/pay/

**S7. Capitec Bank (n.d.). Pay smart with PayShap.** Bank's description and FAQ on ShapID, supported channels, real-time payments, availability and a payment not reflecting. Product availability, fees and limits should be rechecked for the payer/beneficiary's actual bank.
https://www.capitecbank.co.za/personal/transact/payshap/

**S8. Capitec Bank (2026 context; no precise publication date displayed). Stay ahead of scammers this year.** Bank guidance explicitly recommends checking money is in the recipient's account before releasing goods. Applied here as a recipient-side reconciliation principle; not a claim about fraud prevalence among tenants.
https://www.capitecbank.co.za/fraud-centre/stay-ahead-of-scammers-this-year-4-tips-to-protect-yourself/

**S9. Buffalo City Metropolitan Municipality (2021). Integrated Development Plan 2021–2026.** Local official planning context, pp. 85 and 221. Identifies backyard dwelling types and acknowledges backyard dwellers in housing-policy challenges. It is historical planning material, not a current transaction survey.
https://www.buffalocity.gov.za/CM/uploads/documents/20211006061623317063BCMM2021_26IDP31MAY2021FINAL.pdf

**S10. Eastern Cape Department of Human Settlements (n.d.). Rental Housing Tribunal.** Current retrieved provincial service description: complaint process, investigation, mediation/hearing and free service. Jurisdiction must be read subject to the Act; do not treat its broad summary as authorising eviction orders.
https://www.ecdhs.gov.za/index.php/tribunal/

**S11. Republic of South Africa (2013). Protection of Personal Information Act 4 of 2013.** Primary text, particularly ss. 10–14, 18–19. The government listing supplies commencement information. Used for necessary information, purpose, lawful processing, retention and safeguards; not a complete compliance assessment.
https://www.gov.za/documents/protection-personal-information-act
https://www.gov.za/sites/default/files/gcis_document/201409/3706726-11act4of2013protectionofpersonalinforcorrect.pdf

**S12. Republic of South Africa (2008; published 2009). Consumer Protection Act 68 of 2008.** Primary text, definitions/application and s. 14 (PDF pp. 25–26). General commencement listed as 31 March 2011. Applicability to a rental arrangement must be assessed; the report does not assert every backyard lease falls under s. 14.
https://www.gov.za/documents/consumer-protection-act
https://www.gov.za/sites/default/files/gcis_document/201409/321864670.pdf

**S13. PayProp (n.d.). Rental property management software, South Africa.** Retrieved vendor product descriptions of bank-linked reconciliation, accounting, arrears, reporting and maintenance for rental agents. Used only as a product comparator. Marketing performance claims and testimonials are not treated as independent evidence of effectiveness or suitability for backyard landlords.
https://www.payprop.com/za
