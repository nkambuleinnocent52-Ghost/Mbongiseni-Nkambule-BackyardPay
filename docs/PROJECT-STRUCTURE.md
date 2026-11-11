# BackyardPay source guide

Open the source ZIP in VS Code. `main.dart` starts the app; it does not contain all its pages.

```text
lib/
  main.dart                    # Supabase startup
  app.dart                     # Session, theme and app routing
  screens/
    auth/                      # Welcome, login, registration, password reset
    landlord/                  # Landlord dashboard and tenant list
    tenant/                    # Tenant dashboard
    shared/                    # Role router, navigation, profile, reusable UI
    properties/                # Properties, room prices and availability
    payments/                  # Rent/deposit reporting, review and receipts
    rentals/                   # Rental account and agreement
      agreement_editor.dart    # Agreed terms editor
      rental_details.dart      # Rental summary and expandable sections
      rental_forms.dart        # Shared inline forms and section layout
      deposit_summary.dart     # Deposit receipt, returns and deductions
      move_out.dart            # Actual room/key return
      reports.dart             # Problems, acknowledgement and messages
      simple_rentals.dart      # Exports for the rental feature
  models/                      # Typed accounts, properties, tenancies, payments
  data/                        # Store, Supabase gateway and accounting rules
  services/                    # Receipts, alerts and authentication callbacks
  ui/                          # Colours, typography, shared visual components
supabase/migrations/           # Database rules and access controls
test/                         # Flutter unit and widget checks
tool/                         # Browser checks, build and packaging scripts
```

The role dashboards and rental components are independent Dart libraries with explicit imports. There are no dashboard `part` files. `screens/shared/dashboard.dart` chooses the page from the signed-in role; `shared_dashboard.dart` supplies only the common greeting, month selection and navigation helpers. Role content belongs to its own page.

`StoreScope` supplies shared state. Pages ask the store to perform an operation; Supabase validates permissions and persists shared records. Moving a screen does not create a second copy of the accounting rules.

Flutter compiles these files into `main.dart.js` for browsers. That generated filename does not mean the source is one page. Edit Dart source and rebuild; do not edit the generated JavaScript.

Use `BackyardPay-Netlify-source.zip` for editing/submission and `BackyardPay-Netlify-web.zip` for Netlify deployment. Version 1.4.0 is a UI/source organisation update and needs no additional SQL if the previous payment-rule migrations are already installed.
