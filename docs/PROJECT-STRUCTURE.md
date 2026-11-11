# BackyardPay source-code guide

Open the source project in Visual Studio Code and expand `lib`. The compiled Netlify ZIP is for deployment, not for editing or presenting the Dart source.

| File or folder | Responsibility |
| --- | --- |
| `lib/main.dart` | Small entry point: initialise Supabase, then start the app. |
| `lib/app.dart` | App theme, session loading, password-recovery routing, refresh and top-level navigation. |
| `lib/screens/auth.dart` | Welcome screen and landlord/tenant role selection. |
| `lib/screens/login_page.dart` | Login and account-registration form. Uses the selected role; tenant registration requires a private invitation. |
| `lib/screens/password_reset_request.dart` | Request a password-reset link. |
| `lib/screens/password_recovery.dart` | Set a new password after opening a reset link. |
| `lib/screens/dashboard.dart` | Choose the landlord or tenant dashboard from the signed-in account's role. |
| `lib/screens/landlord_dashboard.dart` | Landlord-specific portfolio, room occupancy, pending payments and tenant overview. |
| `lib/screens/tenant_dashboard.dart` | Tenant-specific rental and landlord-contact section. |
| `lib/screens/shared_dashboard.dart` | Shared month selection, rent totals, summary cards and navigation. Shared calculations/layout are maintained once. |
| `lib/screens/dashboard_widgets.dart` | Reusable rental cards, collection chart, month selector and date labels. |
| `lib/screens/tenants_page.dart` | Landlord tenant list, rental-detail entry and rent-reminder form. |
| `lib/screens/properties.dart`, `room_rents.dart`, `room_availability.dart` | Property details, custom room prices and availability. |
| `lib/screens/payment_entry.dart`, `payments.dart`, `deposit_payments.dart` | Rent/deposit payment reporting, landlord confirmation, payment history and receipts. |
| `lib/screens/simple_rentals.dart`, `rental_account.dart`, `research_records.dart` | Rental details, deposits, problems, rent changes, move-out and supporting rental records. |
| `lib/screens/profile.dart` | Profile and notifications. |
| `lib/screens/common.dart`, `lib/ui/design.dart` | Shared page layout, navigation helpers, styling and components. |
| `lib/models/` | Data classes for properties, tenants, payments and other records. |
| `lib/data/` | App state, Supabase access, room availability and rental accounting. |
| `lib/data/deposit_reminders.dart`, `lib/screens/deposit_reminder_notice.dart` | Ten-day deposit status calculation, visible warnings and agreed deadline controls. Server scheduling is in migration `202611110003_deposit_reminders.sql`. |
| `lib/services/` | PDF receipts, alerts and authentication callback handling. |
| `supabase/migrations/` | Database structure, authorization and server-side validation. |
| `test/`, `supabase/tests/`, `tool/` | Automated checks and release/build tools. |

## How the app opens

`main.dart` starts `BackyardPayApp` in `app.dart`. Without a signed-in account, the welcome and login flow is shown. With an account, `dashboard.dart` chooses `LandlordDashboardScreen` or `TenantDashboardScreen`. Each uses the shared dashboard layout and supplies its own role-specific content.

The dashboard files use Dart's standard `part` / `part of` feature. They are separate source files belonging to one dashboard library, so they can reuse private widgets and helpers without copying them. Import `dashboard.dart` when accessing these screens from elsewhere; do not import a dashboard part directly.

## Why the web download contains main.dart.js

Flutter compiles the Dart source and its dependencies into JavaScript for a browser. `main.dart.js` is generated output, even when the source has many separate page files. Do not split or edit it by hand. Change files under `lib`, then rebuild using `tool/build_netlify.sh`.

The `main` label on GitHub is also the branch name: it identifies the project version, not a single source file.

## Submission and deployment

Submit the source project (`BackyardPay-Netlify-source.zip`) when code is required. Use the web ZIP (`BackyardPay-Netlify-web.zip`) only to deploy to Netlify. The 1.1.2 organisation update needs no SQL. Later functional releases can include database migrations; check their release instructions. Version 1.2.0 adds advance rent and deposit reports, with its own additive SQL update.

Suggested explanation for a demonstration: “main.dart starts the application. Authentication lives in its own screen files. The signed-in role selects a separate landlord or tenant dashboard. Both reuse shared UI and accounting code. Supabase enforces access and stores the shared records.”
