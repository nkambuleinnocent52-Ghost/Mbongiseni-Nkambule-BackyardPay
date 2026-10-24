# Cloud integration validation — 24 October 2026

## Verified in this workspace

- 21 existing domain/widget tests passed after removing application demo seeding and moving fixture creation into `test/`.
- 6 new Supabase client contract tests passed: no upload/read of old browser records, signup via Auth, confirmation-required handling, scoped server-command saves, role mismatch sign-out, saved-command/refresh failure distinction, password recovery and logout.
- Static analysis: 28 Dart files, zero issues.
- Release web build passed. An earlier build also passed the WebAssembly dry run; the final rebuild used `--no-wasm-dry-run` because the shipped target is JavaScript.
- PostgreSQL 17 disposable database checks passed. The migration was applied twice. Checks cover RLS profile/tenancy/payment isolation, unauthorized and anonymous operations, forbidden direct writes, tenant signup/room allocation, occupied-room rollback, bank reference validation, partial/pending payment totals, landlord-only approval, double review prevention, rental terms and tenant acknowledgement. The local Auth schema is a test harness, not a replacement for Supabase Auth.
- Chromium browser/API contract passed with an isolated simulated Supabase transport: two separate browser sessions register a landlord and tenant, create property and room records, submit/approve payment, refresh balances, download a valid confirmed PDF, restore the saved Auth session, request password recovery, process its callback, remove the one-use callback code from the URL, set a new password, reload and sign in. Browser errors were checked and none were reported.

## Not yet verified remotely

The hosted project's database setup, email confirmation/reset delivery, SMTP configuration, real cross-device requests and deployment of this cloud build still require owner setup. Network access from this workspace to the project's hostname was blocked by the environment's allowlist. Its hostname and updated startup instructions were saved in the environment configuration draft; saving a draft does not activate access. Review/save and publish that environment configuration before requesting live checks from the workspace.

The publishable client key cannot execute database DDL or administer Auth/email settings. No service-role key or database password was requested or embedded. No test users or sample records were created in the hosted project.

Do not describe local or simulated checks as proof that hosted signup or email delivery already works. Follow [cloud-setup.md](cloud-setup.md), then verify with owner-controlled accounts before inviting other users. Android builds, native alerts, bank APIs, SMS and proof-file uploads are outside this integration.
