# BackyardPay

Flutter rental record application for APT 41P2 using Supabase Auth and PostgreSQL. Browser development is the current target; Android location permissions are configured for later device testing. The app records payments and never transfers money.

## Black and gold redesign

The responsive charcoal and gold interface includes separate landlord/tenant dashboards, collection trends, room occupancy, unpaid tenant status, and a monthly rental ledger with downloadable account statements. Rental records include dates, deposits, utilities, rules, contact details and a tenant read acknowledgement. EFT/PayShap bank references are separate from app references; a rent allocation acknowledgement does not replace bank proof. The cloud version starts with your registered accounts; it does not upload old browser sample records.

See [the lecturer feedback response](docs/lecturer-feedback-response.md) for the problem statement, implemented improvements and remaining limitations.

## Working features

- Landlord and tenant registration with email confirmation, login, profile editing, password changes, email reset links and logout through Supabase Auth.
- Supabase authentication and shared PostgreSQL properties, room assignments, payments and notifications, protected by RLS and server-side commands.
- Property creation/editing/deletion of empty properties; property codes and occupied-room validation.
- Tenant payment submission by rent month and method; all methods await landlord review. Landlords confirm or reject with a reason.
- Partial payments, month balances, duplicate-reference and overpayment prevention. Pending/rejected submissions never count as collections. Existing tenancy rent and due day remain fixed when property defaults change.
- Tenant search, payment filters, reminders, notification read status, property location capture and external map view.
- PDF receipts only for confirmed payments, with bundled Unicode fonts, browser download and platform-supported print/share.
- Browser notification permission is optional; account notifications are saved in the database. Active screens refresh every 20 seconds and have a manual refresh action.

## Service boundaries

The application records payments and never transfers money. Bank transactions are manually matched by landlords. Supabase project setup and a working email sender are required before inviting real users. The public client key does not grant unrestricted data access: role/ownership rules and payment limits run on the server. No uploaded bank-proof files, background push, SMS or payment gateway are included. Existing browser data is retained locally but not imported into the shared database.

Device notification support is not yet implemented on Android. Android build, real GPS capture and phone print/share need testing on the final demonstration device. Browser location requires HTTPS or a permitted localhost origin, OS/browser permission and a location source; a denied request displays an error and does not invent coordinates.

## Develop in the cloud

Use the existing checkout; do not create a worktree unless requested. The current cloud SDK is Flutter 3.47.5 / Dart 3.13.4 at `/workspace/.tools/flutter`.

```bash
export PATH="/workspace/.tools/flutter/bin:$PATH"
export PUB_CACHE=/workspace/.cache/pub
export XDG_CONFIG_HOME=/workspace/.config
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get --enforce-lockfile
flutter test --no-pub
flutter build web --no-pub --no-web-resources-cdn
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

See [cloud setup](docs/cloud-setup.md) for the SQL migration, Auth URLs, email sender and deployment steps. Create a landlord account, confirm the email, create a property, then have the tenant register with its code and an available room. The tenant records payments; only the linked landlord can confirm or reject them. No sample accounts or seed records are created by the application.

## Architecture and tests

- `lib/models/models.dart`: typed models, rent periods and integer-cent money parsing.
- `lib/data/store.dart`: cloud Auth/server-command integration and balance calculations. The local storage implementation is used by isolated domain tests, not as a cloud fallback.
- `lib/screens/`: responsive forms and role-specific journeys.
- `lib/services/`: location is invoked from the property screen; PDF receipts and conditional browser alerts are separate services.
- `test/store_test.dart`: account isolation, saved-data reload, payment states, partial/overpayment rules, duplicates, failures, reminders, password changes, rent-term stability and registration rollback.
- `test/widget_test.dart`: opening the app, selecting a role and back navigation.
- `tool/browser_smoke.cjs`: Chromium browser/API contract checks with simulated Supabase transport and two isolated browser sessions. PostgreSQL access rules are tested separately by `bash tool/test_database.sh`. Requires Playwright and Chromium. With a served web build, run `node tool/browser_smoke.cjs`; set `APP_URL` and `CHROME_BIN` to override defaults. It uses isolated test-only fixtures and does not contact or seed the hosted project.

Hosted signup, confirmation/reset email delivery and a real landlord/tenant journey must be checked after the database and SMTP setup. System notification appearance and print dialogs also require manual checks in the user's browser.

## Sources

Implementation uses Flutter/Dart, shared_preferences, cryptography, geolocator, pdf, printing, url_launcher, uuid and web. Consult their official pub.dev documentation for the academic technical appendix. Bundled DejaVu fonts retain their license in `assets/fonts/LICENSE.txt`.

## Download the prepared app

- [Compiled website ZIP](https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay/blob/main/downloads/BackyardPay-Cloud-web.zip?raw=true) — upload the ZIP using the existing Netlify project’s **Already built it? → choose a file** control. Flutter is not required on your PC.
- [Source backup ZIP](https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay/blob/main/downloads/BackyardPay-Cloud-source.zip?raw=true) — editable Flutter project.

The website is not deployed by uploading these files to GitHub. Hosting and Android testing are separate steps.
