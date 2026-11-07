# BackyardPay

> **Latest release: 1.1.0, build 7.** [Rebuilt Netlify ZIP](downloads/BackyardPay-Netlify-web.zip) · [Source ZIP](downloads/BackyardPay-Netlify-source.zip) · [Changes and checks](docs/releases/Netlify-1.1.0.md). The old Research web ZIP remains on hold after a Defender detection; keep it quarantined. The new release has source, build, browser and independent scanner checks; no Microsoft clearance is claimed. Let Windows check the new download normally.

Flutter rental record application for APT 41P2 using Supabase Auth and PostgreSQL. Browser development is the current target; Android location permissions are configured for later device testing. The app records payments and never transfers money.

## Research-aligned update — 6 November 2026

The black/gold design is retained. See the [research implementation audit](docs/research/Implementation-Audit-2026-11-06.md) for every lecturer comment, evidence limits and the project marking-guide crosswalk.

- Landlords create tenant/room records without creating passwords or requiring the tenant to install the app. A private invitation links a tenant account to existing history; tenants retain previous rentals when joining another after handover.
- One actual payment has an actual payer and explicit allocations across charge months, with unallocated credit. Landlords record received cash/bank money; tenant reports await reconciliation. Deposits are separate.
- Monthly account statements retain charges, partial payments, unpaid months, dated rates and documented adjustments. Planned lease expiry and actual handover are separate.
- Full lease particulars, formal addresses, payment instructions, deposit receipts/interest/refunds/deductions, inspection records, repairs/account queries, audit history and private PDF/image evidence are supported.
- Rental receipts identify the same money as bank evidence and explain allocation; they do not claim bank verification. Original issue details remain fixed. Evidenced full returns/reversals retain the record and update balances.
- Separate stakeholder dashboards show relevant records, credit, attention items and actions. Location, optional active-browser alerts and in-app notifications remain.

## Activate the update

**For 1.1.0:** Run [Simple rentals SQL](downloads/BackyardPay-Simple-Rentals-Update.sql), then upload the latest web ZIP. Includes custom room rents and compact rental/deposit/report/move-out controls. [Instructions](docs/releases/Netlify-1.1.0.md).

**For 1.0.5:** Run [Invitation update SQL](downloads/BackyardPay-Invitation-Update.sql) in Supabase before uploading the latest web ZIP. This preserves existing accounts and rentals and makes room assignment landlord-only. [Instructions](docs/releases/Netlify-1.0.5.md).

**For 1.0.4:** room availability needs only the latest web ZIP on an already activated 1.0.3 backend; no additional SQL. [Room inventory and onboarding rules](docs/releases/Netlify-1.0.4.md).

**For 1.0.3:** after the Research Update, run [BackyardPay-Deposit-Reports-Update.sql](downloads/BackyardPay-Deposit-Reports-Update.sql) before publishing the latest ZIP. This includes the prior Proration update. [Deposit, onboarding and report workflows](docs/releases/Netlify-1.0.3.md).

1. Export/back up the existing Supabase database. Run [BackyardPay-Research-Update.sql](downloads/BackyardPay-Research-Update.sql) in that project's SQL Editor. It is additive and retains existing accounts/payments. Do not rerun the original migration afterwards, which would restore old RPC definitions.
2. Use the rebuilt [BackyardPay-Netlify-web.zip](downloads/BackyardPay-Netlify-web.zip) for Netlify after its normal browser/Windows checks. The ZIP has `index.html` at its root.
3. Use existing email/password accounts. Keep **Confirm email off** in Supabase's email provider during development if signup must not send confirmation email. This release does not change that project setting.
4. Check hosted signup, two-account sharing, private file transfer and phone permissions with owner-controlled accounts before inviting others.

For a brand-new database, run `202610240001_backyardpay.sql` once before the Research Update. Never put service/admin credentials into Flutter.

## Service boundaries

The app records money already paid; it does not transfer money, initiate debit orders, reconcile a bank feed or verify an uploaded proof. The supported charging model is monthly rent with documented agreed adjustments. Lease acknowledgement is a read acknowledgement, not a legal signature. Inspection/deposit records do not decide legal rights. Background push, SMS, electricity vending and non-monthly billing are outside this release. Phone installation/location/alerts, hosted Storage and local East London usability research still need direct validation.

## Develop in the cloud

Use the existing checkout; do not create a worktree unless requested. The current cloud SDK is Flutter 3.47.5 / Dart 3.13.4 at `/workspace/.tools/flutter`.

```bash
export PATH="/workspace/.tools/flutter/bin:$PATH"
export PUB_CACHE=/workspace/.cache/pub
export XDG_CONFIG_HOME=/workspace/.config
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
flutter test --no-pub
flutter build web --release --no-pub --csp --pwa-strategy=none --no-web-resources-cdn --no-wasm-dry-run
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

The build bundles the Flutter renderer, avoiding a runtime dependency on the external renderer CDN. Upload the **contents** of `build/web` to static hosting such as Netlify. It is a compiled static app; do not configure Netlify to execute Dart source without provisioning Flutter. The public client URL and publishable key are in `lib/data/cloud_config.dart`; never include database passwords or service-role keys. Apply the migration and configure Auth as described in the cloud setup guide. Processes must restart after cloud restoration. The onboarding screen does not expose local web servers as user previews.

For normal machines, `flutter analyze` and `dart format lib test tool` are standard. This cloud machine has a read-only home directory that prevents the default analyzer and formatter from writing their caches. The repository includes a direct Dart helper using a writable project cache:

```bash
/workspace/.tools/flutter/bin/cache/dart-sdk/bin/dart --disable-dart-dev \
  --packages=.dart_tool/package_config.json tool/check.dart
/workspace/.tools/flutter/bin/cache/dart-sdk/bin/dart --disable-dart-dev \
  --packages=.dart_tool/package_config.json tool/check.dart format
```

## Create real accounts

For the reproducible release use `FLUTTER_BIN=/path/to/flutter tool/build_netlify.sh` (Flutter 3.47.5, Python 3), then the browser checks described in the release notes.

See [cloud setup](docs/cloud-setup.md) for the SQL migration, Auth URLs, email sender and deployment steps. Create a landlord account and a property, then create the tenant record and share its private invitation. Tenant registration requires that private invitation; tenants cannot select a room or register using a property code. With Confirm email disabled for development, account creation does not wait for confirmation mail. Landlords can record received money directly; tenant-reported money awaits landlord reconciliation. No sample accounts or seed records are created by the application.

## Architecture and tests

- `lib/models/models.dart`: typed models, rent periods and integer-cent money parsing.
- `lib/data/store.dart`: cloud Auth/server-command integration and balance calculations. The local storage implementation is used by isolated domain tests, not as a cloud fallback.
- `lib/screens/`: responsive forms and role-specific journeys.
- `lib/services/`: location is invoked from the property screen; PDF receipts and conditional browser alerts are separate services.
- `test/store_test.dart`: account isolation, saved-data reload, payment states, partial/overpayment rules, duplicates, failures, reminders, password changes, rent-term stability and registration rollback.
- `test/widget_test.dart`: opening the app, selecting a role and back navigation.
- `tool/browser_smoke.cjs`: Chromium browser/API contract checks with simulated Supabase transport and two isolated browser sessions. PostgreSQL access rules are tested separately by `bash tool/test_database.sh`. Requires Playwright and Chromium. With a served web build, run `node tool/browser_smoke.cjs`; set `APP_URL` and `CHROME_BIN` to override defaults. It uses isolated test-only fixtures and does not contact or seed the hosted project.

Hosted signup, confirmation/reset email delivery and a real landlord/tenant journey must be checked after the database upgrade and Auth configuration. System notification appearance and print dialogs also require manual checks in the user's browser.

## Sources

Implementation uses Flutter/Dart, shared_preferences, cryptography, geolocator, pdf, printing, url_launcher, uuid and web. Consult their official pub.dev documentation for the academic technical appendix. Bundled DejaVu fonts retain their license in `assets/fonts/LICENSE.txt`.

## Download the prepared app

- [Compiled website ZIP](https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay/blob/main/downloads/BackyardPay-Netlify-web.zip?raw=true) — upload the ZIP using the existing Netlify project’s **Already built it? → choose a file** control. Flutter is not required on your PC.
- [Source backup ZIP](https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay/blob/main/downloads/BackyardPay-Netlify-source.zip?raw=true) — editable Flutter project.

The website is not deployed by uploading these files to GitHub. Hosting and Android testing are separate steps.
