# BackyardPay: lecturer remarks audit and rental-rule research

Prepared 12 November 2026 (South Africa). Research and review only. No application source, Git index, commits, branches or remote repository changed by this research task.

## Evidence and limits

The uploaded `BackyardPay remarks.docx` is an older project review with six Word comments attributed to Anonymous, dated 23 October 2026. Its old screenshots and local-demo statements are historical evidence, not proof of the present release. The user's latest prompt separately adds operational and usability requirements. The older lecturer comments do not themselves request a colour/theme change, a universal annual increase, identical rents for every room, or a universal ten-day deposit law.

Baseline for the status assessment is release 1.4.0 / source commit 87ce034, with the later portfolio-only commit 2ed66d4. Active repair work must be verified separately before changing a status to fixed. The supplied deployed screenshots were reviewed alongside source; no real hosted account was signed into or mutated during this research.

Primary texts freshly downloaded and read on 12 November 2026:

1. Rental Housing Act 50 of 1999 (original published text), https://www.gov.za/sites/default/files/gcis_document/201409/a50-99.pdf — HTTP 200.
2. Rental Housing Amendment Act 43 of 2007, https://www.gov.za/sites/default/files/gcis_document/201409/gg31051nn539pg1-6.pdf — HTTP 200. The retained official Act page records commencement on 13 May 2008: https://www.gov.za/documents/rental-housing-amendment-act .
3. Consumer Protection Act 68 of 2008, https://www.gov.za/sites/default/files/gcis_document/201409/321864670.pdf — HTTP 200.
4. Official page for Rental Housing Amendment Act 35 of 2014, https://www.gov.za/documents/rental-housing-amendment-act-0 — HTTP 200. The page still says: **“Commencement to be proclaimed in a Government Gazette.”** No later commencement proclamation was verified here. Do not describe every enacted 2014 amendment as automatically in force.
5. Eastern Cape Department of Human Settlements, Rental Housing Tribunal, https://www.ecdhs.gov.za/index.php/tribunal/ — HTTP 200. It describes a free provincial service for landlord/tenant disputes, including investigation, mediation and hearings.

Saved retrievals and extracts are beside this report. Search-engine responses were not reliable evidence: Bing returned unrelated results and Google returned a JavaScript/interstitial page. SAFLII returned HTTP 403; the NCC host was unavailable through the configured proxy. No provincial regulation establishing a universal fixed annual rent-increase interval/percentage for this East London use case was verified. Do not invent one.

## All six original lecturer comments

Exact text extracted from `word/comments.xml`; the companion `lecturer-comments.tsv` preserves IDs and timestamps.

| ID | Lecturer's exact concern | Baseline assessment | What establishes a satisfactory response |
| --- | --- | --- | --- |
| 0 | “What is the problem to be addressed? The problem should come out clearly” | Addressed in the later portfolio's context and source research, provided the updated wording is submitted. A visual theme change alone does not address it. | State the concrete reconciliation problem: which tenant/room/month is paid, what remains due, how a bank reference maps to a rent record, and the difference between a reported and a received payment. Do not present fictional personas as actual field interviews or invent local prevalence figures. |
| 1 | “This has incomplete records. How does he know the tenant who has paid or has not paid from this?” | Core functionality addressed: `TenantsScreen` lists every tenancy for the chosen month, with name, room, property, balance and Paid/Partially paid/Outstanding/Overdue/Pending filters. Landlord home summarises and links to named records. Usability still needs clear notification destinations and rent/deposit labels. | Demonstrate a tenant with no submission remaining visible; a partial payment; a confirmed payment; and a pending report that does not reduce confirmed debt. All-month history belongs in Monthly rental account. |
| 2 | “How does this work with a bank? Some tenants pay through the bank. Your app should be clear on how this relate to the bank payment. Why would someone getting another receipt from the landlord when you have proof of payment from the bank?” | Core distinction addressed: bank payments happen outside the application, bank reference is captured, landlord checks actual funds, confirmed receipts acknowledge the same money. PDF receipt text expressly says it does not independently verify a bank transaction or create a second payment. Remaining work is clearer purpose/person labels and overpayment explanation. | Show one EFT/PayShap payment and the same bank reference on its rental acknowledgement. Say “the bank proof records the bank transfer; the landlord's receipt acknowledges receipt and the rental month/purpose.” Never claim bank API integration or automatic settlement verification. |
| 3 | “This is poorly done. This lacks critical details required when renting or leasing property” | Substantial fields implemented, but only partially satisfactory in usability and record integrity. The long generic agreement form makes users repeatedly enter property-wide information and makes already established values appear editable. Storing fields does not certify a legal lease. | Retain actual parties, notice addresses, dwelling/room, rental amount/escalation, deposit, duration/notice, responsibilities/extra charges and house rules; enter property-wide terms once; preserve each tenancy's terms; clarify optional tenant-specific contacts. Keep move-in/deposit snapshots protected. A read acknowledgement is not a signed lease. |
| 4 | “Where is this property? How does it account for monthly history in the tenant’s account?” | Address and monthly account/history implemented. Maps access is incomplete for address-only records because the baseline emphasises capture-current-location. Existing rent histories, dates, allocations and cumulative balances are present. | Both roles see the linked property name/address directly. An address-based Google Maps search should work without GPS permission. A captured/verified pin is a separate optional source, not something inferred as exact from text alone. Demonstrate several months, including a month with no submission and advance rent allocated to the right month. |
| 5 | “So far the functionality of the app is limited. This could have proper dashboard for landlord and another for the tenant. The dashboard should be showing critical information relevant to each stakeholder.” | Separate role dashboards and core task flows implemented. 1.4.0 removes the oversized hero/chart and explanatory wall. Remaining workflow shortcomings described in the new prompt are real: notifications not actionable, verbose legal-field form, reporting/thread clutter and logout only through Account. | Show the different role pages and explain the task hierarchy. Landlord: collections, availability and payments to check. Tenant: own balance, payment/deposit state, issue reports and rental account. Verify phone navigation and successful feedback with normal user tasks. |

### Documentation defect found

`docs/lecturer-feedback-response.md` is stale. It still states local-only storage, no backend, no first-month proration or rent variations, old dashboard charts and 21 tests. Those statements conflict with the actual 1.4.0 Supabase implementation, proration, dated rent terms and later tests. It should be replaced or explicitly superseded; it is not reliable current completion evidence. Earlier release-specific documents should remain historical rather than being relabelled as current.

## Research conclusions for the new questions

### 1. The payment due day and the rent-change effective month are different

“Due on the 1st” is the recurring payment day. The “Effective month (YYYY-MM)” field records the month from which a *different rent amount* begins; it is not permission to choose a different monthly due day. For example, a new rent of R1,650 effective December 2026 means the December charge is R1,650 and remains due on 1 December. Past charges are not rewritten.

This is a genuine wording/input-design problem. Replace raw YYYY-MM entry with a labelled month chooser, e.g. **“New rent starts in”**, then show **Current rent / New rent / Change in rand and percent / Rent remains due on the 1st**. Identify the selected tenant and room. Save only a real documented agreement/notice basis; saving an app record does not itself make an increase lawful.

### 2. Must every room or tenant get the same increase for a whole year?

No verified source supports the user's proposed blanket rule. A property can have differently sized rooms and separate agreements starting on different dates. A selected tenancy's rent can differ from another tenancy's rent. The Act specifically contemplates the rent of the particular dwelling and its reasonable escalation, if any, as terms of the lease [s. 5(6)(c)]. Section 4(1) prohibits unfair discrimination on listed grounds; that is different from requiring identical prices for objectively different rooms or contracts.

A property default for **new tenants** and a change to an **existing tenant's** agreed rent are different actions. The former must not silently overwrite current tenants' historical or future agreements. If a landlord wants to change several existing tenancies, any bulk operation should identify each affected tenancy, new amount, effective month and actual notice/agreement separately. It should not assume one property's default automatically changes everyone.

A fixed-term agreement may contain an agreed escalation provision; absent the applicable contractual/legal basis, the landlord cannot simply override it mid-term by typing a number. A periodic arrangement also does not give the application authority to impose arbitrary changes. The agreement, applicable unfair-practice rules, notice and any tribunal/court decision matter.

Annual review is a common contractual arrangement, not a universal rule established by the researched baseline text. Do not build a “law requires all rents to change only yearly” message or “same percentage for everyone” constraint. Do not hardcode a universal 10% ceiling: the original Act's s. 19(1)(b) 10%-per-annum wording concerned controlled premises for a **three-year transitional period from commencement**, not a general current cap on every rental.

Section 13(4)–(6) empowers the tribunal to address unfair practices and make just/equitable rental determinations with regard to factors including supply/demand and a realistic investment return. The Eastern Cape tribunal is the relevant provincial dispute route. The app should record an agreed change rather than purport to decide a disputed increase.

### 3. Notice periods: do not mix different events

- RHA s. 5(5) addresses continued occupation with the landlord's consent after lease expiry, deemed a periodic lease on the existing terms except at least one month's written notice of termination. It is not a blanket one-month statutory rent-increase rule.
- CPA s. 14, **where applicable**, addresses fixed-term consumer agreements. Its 40–80 business-day notice concerns impending fixed-term expiry and material changes on renewal/continuation, not every rent increase in every private backyard arrangement. Its 20-business-day early-cancellation provision is a different event again.
- CPA applicability depends on the transaction/supplier context and exclusions, including ordinary-course-of-business context and s. 14's exclusion for transactions between juristic persons. Do not apply it indiscriminately to all private arrangements.
- No universal ten-day deposit grace period or app reminder deadline is established by these sources. The app's new-tenancy ten-day policy is a stated rental/product policy, with existing actual legacy agreements preserved.

### 4. Month-to-month versus fixed term

These describe **how long the rental arrangement runs**, not who can set the rent or how often the tenant pays.

- **Month-to-month:** an ongoing periodic arrangement without a fixed final date, ended with the required notice under the actual agreement/applicable law.
- **Fixed term:** agreed start and end dates. Changing rent still depends on the actual terms, any escalation clause, notice and applicable law.

Both can charge monthly rent due on the 1st. Use these plain-language descriptions near the selector. Do not remove duration just because the rental is a backyard room: it affects termination/continuation, one of the lecturer's missing-particulars concerns.

### 5. Move-in date: actual occupation, not account creation

“Onboarded” can mean a record was created before the tenant actually moves in. The calculation must use the actual agreed move-in date, not signup time or when a landlord happened to enter the form. A 15 January move-in at R1,500 monthly with actual-day proration is 17 inclusive days / 31: R822.58.

Once confirmed/saved as the actual start, casually editing it can change first rent, deposit deadline and room availability. Show it read-only in the ordinary agreement editor. Any genuine correction should be explicit, authorised and preserve evidence/history, rather than silently rewriting prior payments and deadlines. A property address/room in a rental summary should already identify the home; it should not require a large property-overview button just to discover the name.

### 6. Why “agreed deposit” if the property requires R2,000?

RHA s. 5(3)(c) permits the landlord to require a deposit in the amount specified in the agreement or otherwise agreed between the parties. A landlord can offer this particular room on a R2,000-deposit condition; accepting that rental makes it part of the agreement. “Agreed” does not mean the app must negotiate it or that every property legally charges the same amount.

Use plain labels: **“Security deposit: R2,000 — set for this property”** on new onboarding, and keep the tenancy's amount stable once created. Separate amount required, money received, pending report, supported deduction and refund. Changing a property's deposit default later must not rewrite existing tenancy deposits. Damage does not automatically forfeit the whole deposit; proper liability, cost support and remaining balance matter.

### 7. What do the difficult agreement fields mean, and which should be entered once?

The baseline RHA s. 5(6) lists written-lease particulars including parties and their South African addresses for formal communication, dwelling description, rent/reasonable escalation, non-monthly frequency if relevant, deposit, period/termination notice, obligations and additional charges. House rules and recorded defects are also addressed. The app's labels should help fulfil these particulars without making every tenant repeat the whole property setup.

| Existing label | Plain meaning | Sensible entry scope |
| --- | --- | --- |
| Landlord formal-notice address | The South African address chosen for written rental notices/letters to the landlord. It need not be the rented room's street address. | Landlord/property setup once, then copy actual terms into each rental; genuine later changes recorded explicitly. |
| Tenant formal-notice address | The agreed address where written notices to this tenant should be delivered; often the property plus room, unless another address is agreed. | Default from property/assigned room, editable only for a genuine tenant-specific communication arrangement. |
| Owner / agent / lawful authority to let | Whether the person renting the room is the owner or has authority to act for the owner/sublet. It is a capacity/authority record, not automatic ownership verification. | Once for the landlord/property; no need to retype for every tenant. Avoid claiming a checkbox verifies title. |
| Exact dwelling / room / yard-space description | Which property and specific space the tenant rents. | Property description plus assigned room, with tenant-specific differences only where needed. |
| Shared facilities and access | Shared tap, bathroom, gate, access arrangements, etc. | Property-wide template, copied into each rental and changed only if that agreement differs. |
| Payment instructions | Agreed payment method/account or reference instructions; never PINs/passwords. | Property/landlord-wide default; tenant-specific reference can be derived from room/account. |
| Notice / termination / continuation | What happens when ending/renewing this arrangement and how notice is given. | Property default where appropriate, but duration/individual agreement and law can differ; do not silently override existing contracts. |
| Escalation | An actual agreed rent-review/increase provision and notice basis, if any. | Property default plus an actual tenancy agreement; effective changes are separate dated records. |
| Additional charges and calculation | Charges besides rent and how they are calculated. | Property default; only collect tenant-specific differences. “None” should be an explicit valid choice rather than an invented obligation. |
| Utilities | Who pays water/electricity and how. | Property-wide default unless this tenancy genuinely differs. |
| Emergency contact | A person to contact in an emergency, not the landlord or the tenant's password/login. | Optional and tenant-specific; avoid making it a compulsory broad personal-data collection. |

“Enter once” should mean reusable defaults and stable rental snapshots, not that a genuine address, responsibility or contact can never change. Do not silently overwrite an old agreement when updating a property template.

### 8. Bank proof versus landlord receipt; actual payer versus tenant

The primary Act says: **“the landlord must furnish the tenant with a written receipt for all payments received by the landlord from the tenant”** [s. 5(3)(a)]. Receipt particulars include the dwelling address, whether the payment is for rental/arrears/deposit/other and the period covered [s. 5(3)(b), read with the 2007 amendment]. The bank's proof and the rental acknowledgement have different jobs: the bank describes its transaction; the landlord acknowledges the money received and its rental allocation. It must be the same payment, not an invented second transfer.

The tenancy identity must remain fixed as **“Paid for: [tenant], Room [number]”**. An optional actual-payer name can help reconcile a relative's EFT from a different bank account; it does not rename the tenant. Default it to the tenant and make it a quiet **“Someone else paid?”** detail rather than another required name to rewrite.

### 9. The R2,000 payment / R1,200 rent / R800 advance example

The user's arithmetic is correct: R2,000 rent payment minus R1,200 first rent leaves R800. If the tenant allocates the R800 to the following month's R1,500 charge and the landlord confirms actual receipt, the following month has R700 remaining.

The tenant should propose the purpose and months: **Rent → R1,200 this month + R800 next month**. The landlord checks actual receipt and the proposed allocation, rather than silently changing what the tenant intended. A separate R2,000 deposit payment must not be counted again as rent. A larger rent payment is not inherently invalid just because this month's balance is smaller; accept an explicit permissible future allocation or retain a visible credit. Before asking for more money, check pending reports and confirmed credit.

If the user chooses no month for a genuine remainder, show it as **“Rent credit waiting to be assigned”**. Do not silently extinguish debt or invent a future payment. If the app automatically suggests the next month, make that suggestion visible and editable before submission.

### 10. Address-based map navigation

It is reasonable to open Google Maps with the property's entered full address without requiring Capture current location. The supported Maps URL form is an address query, for example `https://www.google.com/maps/search/?api=1&query=<encoded full address>`. The address remains visible in the tenant's rental details. Optional GPS is a different, permission-based feature and should not be required just to view a street address.

The user's claim that 19 St Georges Road, Southernwood, East London resolves to Anfield Residence was **not independently verified**: the available Google request returned a JavaScript/interstitial response rather than usable place details. Do not invent coordinates or claim an exact pin has been verified. A Google Maps search can let the user inspect the result. Preserve the full suburb/city/postcode and property label to reduce ambiguous matches.

## Latest prompt: acceptance checklist (baseline gaps, not completed-work claims)

| Requested outcome | Baseline state / required check |
| --- | --- |
| Rent always due on 1st | Already server-enforced for new/future terms in 1.3+; first partial rent at move-in remains a separate exception. Confirm no due-day editor is accidentally exposed. |
| Effective month understandable | Gap: raw YYYY-MM looks like payment-date editing. Replace with future month chooser and amount-change summary. |
| One-tenant vs whole-property scope | Gap: make selected tenant/room explicit; retain different room rates and actual agreements. |
| Shared agreement terms entered once | Gap: long repeated fields need property-wide templates and plain labels. |
| Actual start/deposit stable | Gap: ordinary editor should display established values read-only and server should reject casual rewrites. |
| Tenant selects purpose and rent months | Partly supported, but overpayment/next-month flow needs a visible suggestion and tests for the R1,200 + R800 case. |
| Explicit Rent / Deposit labels on owner review | Gap: generic “payment” wording obscures purpose. Name purpose, tenant and room. |
| Tenant fixed; optional actual payer | Baseline stores payer separately, but label/design should make the difference clearer. |
| Address shown inline and opens Maps | Address exists; address-only Maps navigation needed; do not require GPS. |
| Problem location, description, acknowledgement and status | Core backend/thread exists; repeated form/message presentation and duplicate submissions need a cleaner issue list/detail flow. Preserve old records rather than deleting genuine history. |
| Clickable contextual notifications | Baseline gap: generic notices and mark-read actions do not take users to the exact issue/payment. Need entity links, names/rooms/purpose, access checks and graceful historic fallback. |
| Logout from every authenticated page | Baseline gap: only Account logout. Add global icon with an anchored Log out / Cancel prompt, including phone layout. |
| Standard icons | Material icons are already used. Review the distinctive BrandMark/emojis and replace unwanted decorative identity/icons without promising to remove external Netlify/browser overlays that are not in app source. |
| Short account/login ID | New feature, not lecturer requirement. It is an alternate identifier with the SAME password, not a second security factor or secret. No anonymous ID-to-email enumeration. |
| Stay signed in | Supabase already supports persisted sessions; verify startup/session refresh and reload/close/reopen behaviour. Explicit logout/revocation/cleared browser data still ends a session. Use separate browser profiles for developer role testing; two tabs in the same shared session are not independent accounts. |
| Do not change Git now | No commits/pushes/repository cleanup. Local authorised app fixes and deliverables only. |
| Current portfolio accuracy | The existing PDF describes 1.4.0/GPS capture and old screens. Once functional changes are verified, it needs a separately labelled update before resubmission; do not claim it already reflects new changes. |

The final response should distinguish already implemented features, tested fixes, deployment/database activation still required, and legal/research limits. No mark, comprehensive legal compliance, real user satisfaction or real bank verification can be guaranteed by changing the theme.
