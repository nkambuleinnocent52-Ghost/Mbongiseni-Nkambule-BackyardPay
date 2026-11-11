# BackyardPay 1.1.2 — clearer source organisation

The source is organised for reading, maintenance and project submission. `main.dart` contains startup only; app/session code is in `app.dart`. Login, password-reset request and password recovery are separate files. The dashboard has a small role router, separate landlord/tenant page files, a shared layout/widgets library and a tenant-list file.

The existing screen exports remain compatible with callers. The app keeps the same visual design, navigation, account and rental/payment behavior. This is a source refactor, not a new database setup. No SQL is needed.

Read [the project structure guide](../PROJECT-STRUCTURE.md). For submission/editing, download `BackyardPay-Netlify-source.zip`. To redeploy the rebuilt browser version, use `BackyardPay-Netlify-web.zip`. Flutter still generates `main.dart.js` in the web output; it is compiled output, not the source project.

[Recorded verification](Netlify-1.1.2-checks.md).
