# Connect the real BackyardPay application

This version uses Supabase Auth and PostgreSQL. It contains no sample-account creation button, public sample credentials or seeded rental records. The black and gold interface is retained. Old local-browser sample records are not uploaded or silently treated as real records; they remain untouched in the old local storage.

## 1. Create the database tables and access rules

Open your **BackyardPay** project in Supabase, then **SQL Editor → New query**. Paste the complete contents of [202610240001_backyardpay.sql](../supabase/migrations/202610240001_backyardpay.sql), then **Run**. Successful output should say **Success. No rows returned**. The script creates tables, Auth signup handling, row-level access rules and checked commands. It does not insert any users or rental records. Re-running it does not drop the existing tables or their records.

Use only the migration file above in your real project. The files under `supabase/tests/` provide a disposable local testing harness and must not be run in hosted Supabase.

## 2. Set authentication URLs and email

Under **Authentication → URL Configuration** set:

- Site URL: `https://quiet-pastelito-19fa50.netlify.app`
- Redirect URLs: `https://quiet-pastelito-19fa50.netlify.app/`

Keep email confirmation enabled. Configure an SMTP provider in the project's Auth email settings for signups and password resets sent to real users. Supabase's default development email service has restricted recipients and rate limits; an app using only that service cannot be called ready for general public registration. Do not disable confirmation just to work around delivery restrictions. The app opens confirmation/reset links at the same site. A password reset link opens the dedicated new-password screen. Configure and test the email sender before inviting other people.

No service-role key or database password is required in Flutter or Netlify. The public project URL and publishable key supplied by the owner are in `lib/data/cloud_config.dart`. Database authorization comes from Auth sessions, RLS and server-side command checks. The project owner controls Supabase dashboard administration.

## 3. Deploy the cloud website ZIP

Upload **BackyardPay-Cloud-web.zip** to the existing Netlify project using **Project overview → Already built it? → choose a file**. Keep it zipped. This is a compiled Flutter app, so a build command is not needed. Press Ctrl+Shift+R once after publishing.

The old sample app remains the deployed version until this upload is complete. The app cannot create accounts until the SQL setup is applied. Do not upload the source ZIP as a website.

## 4. Start with your own accounts

1. Choose Landlord → Create an account. Use an email address you can open, a strong password, your name and contact number.
2. Confirm your email, then log in as Landlord.
3. Create a property: address, room count, default rent and deposit. Rent is due on the 1st. Assign an available room to the tenant using Add tenant record, then share that rental’s private JOIN- invitation. Property codes cannot register tenant accounts.
4. The tenant creates their own account using that private invitation; their room is already assigned. The tenant confirms their email and signs in as Tenant. Landlords should not collect tenants' passwords.
5. Complete Rental details as Landlord: dates, deposits, utilities, rules and contacts. The tenant can acknowledge reading those details.
6. Tenant records a payment. The landlord checks actual receipt of the money before confirming. Both accounts then show the updated balance and the confirmed PDF.
7. Accounts on separate browsers/devices share records. Active screens refresh every 20 seconds; the toolbar's Refresh records button loads changes immediately. Offline saves are not silently queued as successful.

The application records payments; it does not transfer money or automatically verify bank transactions. A downloaded receipt is an acknowledgement of landlord-confirmed funds. Background push/SMS, uploaded proof files and native Android delivery are not implemented by this change.

## Developer validation

- `flutter test --no-pub`: local domain and widget tests, with fixtures confined to `test/`.
- `bash tool/test_database.sh`: disposable PostgreSQL 17 with a minimal Supabase Auth test harness. Applies the migration twice and checks signup, RLS visibility, anonymous/direct-write denials, cross-landlord mutation denials, occupied rooms, bank references, partial/pending payments, landlord-only approval and rental acknowledgement. Docker is required; no real users are created.
- `node tool/browser_smoke.cjs`: browser checks against a controlled local test backend; see the script. Never run test seeding against the real database without explicit authorization.

Local checks do not prove email delivery or that the migration has been applied to the hosted project. Verify a real owner-controlled landlord/tenant journey after SQL, email and deployment setup. Do not claim production readiness solely from a build passing.

For existing installations, apply `downloads/BackyardPay-Invitation-Update.sql` before deploying version 1.0.5. A tenant uses the private invitation once; subsequent logins use email and password.
