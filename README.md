# BackyardPay

Flutter rental payment-record prototype for APT 41P2. Browser development is the current target; Android location permissions are configured for later device testing. The app records payments and never transfers money.

## Black and gold redesign

The responsive charcoal and gold interface includes separate landlord/tenant dashboards, collection trends, room occupancy, unpaid tenant status, and a monthly rental ledger with downloadable account statements. Rental records include dates, deposits, utilities, rules, contact details and a tenant read acknowledgement. EFT/PayShap bank references are separate from app references; a rent allocation acknowledgement does not replace bank proof. Existing browser records migrate without being replaced by demo data.

See [the lecturer feedback response](docs/lecturer-feedback-response.md) for the problem statement, implemented improvements and remaining limitations.

## Working features

- Landlord and tenant registration, password verification, profile editing, password changes and logout. Passwords use PBKDF2-HMAC-SHA256 with a separate random salt per account.
- Persistent accounts, properties, room assignments, payment records and notifications through a versioned local data store.
- Property creation/editing/deletion of empty properties; property codes and occupied-room validation.
- Tenant payment submission by rent month and method; all methods await landlord review. Landlords confirm or reject with a reason.
- Partial payments, month balances, duplicate-reference and overpayment prevention. Pending/rejected submissions never count as collections. Existing tenancy rent and due day remain fixed when property defaults change.
- Tenant search, payment filters, reminders, notification read status, property location capture and external map view.
- PDF receipts only for confirmed payments, with bundled Unicode fonts, browser download and platform-supported print/share.
- Optional demo accounts created only in an empty store. Browser notification permission is optional; in-app notification records always remain available.

## Local prototype boundaries

Both accounts must use the same browser profile/origin (or the same installed app/device). Sign out and switch roles in the same tab. No cloud database, cross-device synchronization, real banking, SMS, background push or email password recovery is implemented. Browser data can be lost if site storage is cleared. Local role checks protect application operations but are not a substitute for server-side access controls in a production service. Use fictional demo information.

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

The build bundles the Flutter renderer, avoiding a runtime dependency on the external renderer CDN. Upload the **contents** of `build/web` to static hosting such as Netlify. It is a compiled static app; do not configure Netlify to execute Dart source without provisioning Flutter. No backend keys are needed. Processes must restart after cloud restoration. The onboarding screen does not expose local web servers as user previews.

For normal machines, `flutter analyze` and `dart format lib test tool` are standard. This cloud machine has a read-only home directory that prevents the default analyzer and formatter from writing their caches. The repository includes a direct Dart helper using a writable project cache:

```bash
/workspace/.tools/flutter/bin/cache/dart-sdk/bin/dart --disable-dart-dev \
  --packages=.dart_tool/package_config.json tool/check.dart
/workspace/.tools/flutter/bin/cache/dart-sdk/bin/dart --disable-dart-dev \
  --packages=.dart_tool/package_config.json tool/check.dart format
```

## Demo

1. On a new browser profile, choose **Try with demo accounts**.
2. Select **Tenant**; sign in with `tenant@demo.test` / `DemoPass123!`.
3. Record rent for this month. It appears as **Pending**, with no confirmed receipt.
4. Return to the dashboard, open Profile, and log out.
5. Select **Landlord**; sign in with `landlord@demo.test` / `DemoPass123!`.
6. Open Payment records, select the payment, verify receipt of funds, and confirm. The dashboard balance updates.
7. From My tenants, send a reminder. From My properties, capture location while at the property and allow device/browser permission.
8. Log out and return to the tenant. Open Notifications and Payment history, then download the confirmed PDF receipt.
9. Refresh the browser. Records and the current session persist.

For your own fictional dataset, create the landlord account and property first, copy the generated property code, log out, then register a tenant with that code and an available room number.

## Architecture and tests

- `lib/models/models.dart`: typed models, rent periods and integer-cent money parsing.
- `lib/data/store.dart`: authentication, ownership checks, balances and transaction rollback on storage failure; `DataStorage` allows isolated tests.
- `lib/screens/`: responsive forms and role-specific journeys.
- `lib/services/`: location is invoked from the property screen; PDF receipts and conditional browser alerts are separate services.
- `test/store_test.dart`: account isolation, saved-data reload, payment states, partial/overpayment rules, duplicates, failures, reminders, password changes, rent-term stability and demo rollback.
- `test/widget_test.dart`: opening the app, selecting a role and back navigation.
- `tool/browser_smoke.cjs`: real Chromium browser journey, including simulated location and downloaded PDF. Requires Playwright and Chromium. With a served web build, run `node tool/browser_smoke.cjs`; set `APP_URL` and `CHROME_BIN` to override defaults. It creates fictional data in a fresh isolated browser context.

Simulated browser geolocation verifies the permission/API/save flow; it does not verify real GPS hardware. System notification appearance and print dialogs also require manual checks in the user's browser.

## Sources

Implementation uses Flutter/Dart, shared_preferences, cryptography, geolocator, pdf, printing, url_launcher, uuid and web. Consult their official pub.dev documentation for the academic technical appendix. Bundled DejaVu fonts retain their license in `assets/fonts/LICENSE.txt`.

## Download the prepared app

- [Compiled website ZIP](https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay/blob/main/downloads/BackyardPay-BlackGold-web.zip?raw=true) — upload the ZIP using the existing Netlify project’s **Already built it? → choose a file** control. Flutter is not required on your PC.
- [Source backup ZIP](https://github.com/nkambuleinnocent52-Ghost/Mbongiseni-Nkambule-BackyardPay/blob/main/downloads/BackyardPay-BlackGold-source.zip?raw=true) — editable Flutter project.

The website is not deployed by uploading these files to GitHub. Hosting and Android testing are separate steps.
