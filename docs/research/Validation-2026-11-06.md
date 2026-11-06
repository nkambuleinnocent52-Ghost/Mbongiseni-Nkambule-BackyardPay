# Research update validation — 6 November 2026

## Passed locally

- 34 Flutter domain, cloud-client and widget tests. These include dated rates/adjustments and planned expiry versus actual handover; deposit receipts/interest/returns; multi-month serialization and credit; legacy records, access/session behaviour; 320-pixel payment, deposit, inspection and monthly-account screens.
- Static analysis: 34 Dart files, zero issues.
- Release JavaScript web build passed with bundled local web resources. No final Android or WebAssembly build is claimed.
- PostgreSQL 17 disposable harness passed original access/payment checks, two applications of the research migrations, preservation of synthetic old accounts/payments/deposit balances, offline tenant creation and private claim, multi-month allocation, payer, credit, frozen receipt, adjustments, future rates, deposit retry protection/interest/return/deduction prerequisites, inspections, repair/query permissions, payment reversal, actual handover and joining another rental with retained history.
- Private-document SQL contract checks passed: linked access, denied unrelated reads, registration requires the caller's uploaded object, registered evidence cannot be deleted through the app. A minimal Storage schema models policy tests; this does not prove hosted file transfer, MIME enforcement or signed-link delivery.
- Chromium browser/API contract passed using simulated Supabase transport and two isolated browser sessions: registration, property, tenant joining, report/confirmation, balance refresh, receipt download, restored Auth session, password recovery and subsequent login. The final receipt PDF was parsed and contains issuer/address, tenant, payer, dwelling, amount, method and allocation. Browser errors: none. Server authorization is tested independently using PostgreSQL, not inferred from the simulation.

Screenshots under `docs/screenshots/research/` are captured from the release with isolated synthetic fixtures. They are implementation evidence, not real research participants or evidence of hosted deployment.

## Still requires direct acceptance

Apply the additive SQL to the owner-controlled Supabase project, publish the new ZIP, and check actual signup without confirmation mail, two real accounts/devices, private document upload/open and the resulting stored records. Test installation, GPS permission and relevant alerts on the intended Android phone. In-app notifications/optional active-browser alerts are implemented; background mobile push is not.

The Netlify hostname is not allowed by this environment's network policy, so the currently hosted app was not audited directly. No test accounts or sample records were inserted into the live project. No administrator/database password was requested. Email-confirmation configuration was not changed.

Local East London research, arrangement-specific legal/lease validation, the final page-limited manual/code appendix and a rehearsed 20-minute presentation remain distinct from software test results. The audit gives a marking-guide plan, not a promised grade.
