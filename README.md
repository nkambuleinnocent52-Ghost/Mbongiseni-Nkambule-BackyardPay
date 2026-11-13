# BackyardPay

Rental records for backyard landlords and tenants in East London, Eastern Cape.

**Mbongiseni Nkambule · 231064977 · Application Technology IV (APT41P2)**

The deployed release is **1.5.0 (build 14)**. The application records cash and bank payments; it does not transfer money. Tenant reports remain pending until the landlord confirms receipt. Rent and security deposits are recorded separately.

## Project report — lecturer review

**[Read the updated project report (PDF)](downloads/Mbongiseni%20Nkambule%20231064977%20Updated%20Version.pdf)** · [Word document](downloads/BackyardPay-Project-Report-231064977.docx)

This is the current project report, updated on 13 November 2026. Development has continued since the original submission: release 1.4.0 had 84 passing Flutter tests, and release 1.5.0 has 105. The report covers the problem, objectives, screenshot manual, selected code, folder structure and references. It retains the original cover page.

## Application

[Open BackyardPay](https://quiet-pastelito-19fa50.netlify.app)

- Landlord and tenant accounts with private tenant invitations.
- Properties, room availability and room-specific rent.
- Calendar-day first-month rent, payment history and PDF receipts.
- Separate deposits, ten-day deposit reminders and problem reports.

## Project files

| Folder | Contents |
| --- | --- |
| `lib/` | Flutter source, organised by role and feature |
| `supabase/migrations/` | Database changes in execution order |
| `supabase/tests/` | Database permission and accounting checks |
| `test/` | Flutter unit and widget tests |
| `tool/` | Build, browser and validation scripts |
| `web/`, `assets/` | Browser entry files and bundled assets |
| `downloads/` | Current project report, web ZIP, source ZIP and database setup |

[Source structure](docs/PROJECT-STRUCTURE.md)

## Downloads

- [Web ZIP for Netlify](downloads/BackyardPay-Netlify-web.zip)
- [Editable source ZIP](downloads/BackyardPay-Netlify-source.zip)
- [Database setup](downloads/BackyardPay-Database.sql)

Upload the web ZIP to the existing Netlify project. The source ZIP is for editing. Existing databases should apply only missing migrations, in order; do not reset a database containing rental records.

## Run and check

Use Flutter with the locked dependencies in `pubspec.lock`:

```sh
flutter pub get
flutter test
flutter run -d chrome
```

Release 1.5.0 passed 105 Flutter tests and static analysis. Chromium checks used a simulated backend to exercise both roles, payments, deposits, receipts and account recovery. These checks do not establish native Android behaviour or live email delivery.

`tool/build_netlify.sh` builds and packages the website. `tool/browser_smoke.cjs` checks the served application with isolated test data. `tool/test_database.sh` uses a disposable PostgreSQL database; it must not seed the live project.

## Current update

[Changes and lecturer-remarks review](docs/REVIEW.md). Existing 1.4.0 databases: apply [Review update SQL](downloads/BackyardPay-Review-Update.sql), then upload the web ZIP. [Optional Login ID setup](docs/setup/OPTIONAL-LOGIN-ID.md). Email login stays available.
