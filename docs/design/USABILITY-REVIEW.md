# BackyardPay usability revision — 1.4.0

## Scope and users

The supplied nine lecture PDFs were reviewed as design references. Their examples and old assessment instructions are not application requirements. The user's requirement is a simpler rental-record application for ordinary landlords and tenants.

Landlords need to see rent received, available rooms, payments needing confirmation and tenant issues. Tenants need to understand rent/deposit balances, report a payment already made and contact their landlord. The app records cash and bank payments; it does not transfer money.

## How the slides informed the changes

Page numbers below refer to PDF pages, counting the cover as page 1.

| Supplied document | Principle | Application |
| --- | --- | --- |
| Chapter 1 – Part 1, pp. 15, 17, 41 | Limited working memory; individual differences | Remove repeated explanations and duplicate totals. Keep clear labels and support larger text rather than expecting users to remember accounting terminology. |
| Chapter 2 – Part 1, pp. 2, 7, 28 | Small screens, feedback, imprecise touch | Responsive summaries, phone navigation menu, labelled controls and Material touch targets. |
| Chapter 3 – Part 1, pp. 11–12 | Execution/evaluation gulfs; slips and mistakes | Task wording such as “Rent still due” and “Payments to check”; pending payments stay visibly distinct from confirmed receipts. |
| Chapter 5, pp. 28–30 | Local and global navigation; screen structure | Role-specific task hierarchy, consistent navigation, quiet secondary rows and expandable optional detail. |
| Chapter 6, pp. 7, 11 | Iteration and measurable usability | Widget/browser checks plus a task walkthrough; propose observed user-task measures rather than claiming an unperformed user study. |
| Chapter 7, pp. 4, 15 | Learnability, flexibility, robustness; consistency and feedback | Common styling, plain labels, stable navigation, optional payment details, unchanged validation and confirmation feedback. |
| Chapter 9 – Part 1, pp. 6–8 | Cognitive walkthrough and heuristic evaluation | Walk through onboarding, payment reporting, landlord review, deposit follow-up and issue acknowledgement. |
| Chapter 12, pp. 32–33 | Network latency and feedback | Preserve saving states, disabled duplicate submissions, refresh/error feedback and startup recovery. This file's internal title is “chapter 21: Hypertext, multimedia and the WWW”. |
| Chapter 13, pp. 2, 4, 12 | Stakeholders and real work practices | Separate landlord authority from tenant reporting. Preserve private invitations, assigned rooms and cash/EFT/PayShap recording. |

## Visible changes

- Landlord home: three summaries, one main onboarding action, pending payment rows and a short destination list. The large decorative hero, chart, repetitive metrics, compliance counters and explanatory wall are removed.
- Tenant home: selected month's rent balance, confirmation status, one “Record payment” action and short links to deposit, history, account, issues and rental details. Deadline warnings remain when relevant.
- Both homes: concise payment rules, month selection, notification indicator and profile access. Phones have a navigation menu; desktops retain the sidebar.
- Payment forms: a short instruction at the point of action; payer identity and generated record number are under optional details. The payer defaults to the tenant and can be corrected when someone else pays. Rent months remain explicit; December and later advance months remain available.
- Deposit reminders: shorter amount/deadline messages. Reported money is labelled as waiting for confirmation, with a clear warning against paying it again.
- Rental details retain expandable sections for occasional tasks instead of a wall of competing yellow buttons.

## Architecture and scalability

Role/feature folders separate authentication, landlord, tenant, properties, payments and rentals. The former dashboard `part` library is replaced with normal imports; rental summary, deposit, move-out, forms and reports have separate implementation files. Data models, server access and financial calculations remain outside the views. The tenant list keeps search/filters; home avoids rendering every tenant and a full chart as the portfolio grows. This improves maintainability and home rendering, but is not a claim of backend load testing or server pagination.

## Task walkthrough and acceptance criteria

| Task | Expected path and observable result |
| --- | --- |
| Add a tenant | Landlord home → Add tenant record → available room → tenant details; move-in costs previewed before save. |
| Record November or December rent | Tenant home → Record payment → rent month → submit; payment is pending until landlord confirms. |
| Confirm money received | Landlord home pending row → check payment → confirmation checkbox → confirm; rent balance changes once. |
| Report a deposit payment | Record payment → Security deposit; deposit record remains separate from rent. |
| Follow up unpaid deposit | Deadline warning identifies amount/date; a pending report does not ask for the same money again. |
| Report a leaking tap | Tenant problem link → location/issue → send; landlord acknowledgement appears for both roles. |
| Navigate on a phone | Open navigation menu → labelled destination; no desktop-width sidebar squeezed into the screen. |

Automated checks verify functionality and layout, not human learnability. Before a final usability claim, ask representative landlords and tenants to perform these tasks without coaching. Record completion rate, time, wrong turns and their explanations of “pending” versus “paid”. Suggested target: each core task completed by at least 4 of 5 participants without help; revise the labels where confusion remains. No participant results are invented here.
