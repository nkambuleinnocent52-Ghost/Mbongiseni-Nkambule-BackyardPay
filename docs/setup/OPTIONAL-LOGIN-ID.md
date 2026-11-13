# Optional Login ID sign-in

Email and password continue to work without this optional feature. Sessions already persist on the device/browser and refresh their tokens. The explicit Log out control ends the session. Clearing site storage, using a private window, a revoked/expired session or changing device can require sign-in again. Two roles can be tested in separate browser profiles or separate browsers without logging each other out.

A Login ID is a nine-digit account identifier displayed as three groups, for example `321 654 987`. It is not a password or an extra authentication factor. The same account password is required whether signing in with email or ID. Password requirements and password reset are unchanged.

## Activation on the existing Supabase project

The code and scripts are prepared locally; no hosted function or setting has been changed by the development tools.

1. Apply `supabase/migrations/202611120003_login_ids.sql` after the ordinary application updates. It assigns unique IDs to existing and new accounts without changing emails, passwords, tenancies or payments. The feature starts **disabled**.
2. Deploy the server-side function from this source project:

   ```sh
   supabase functions deploy login-with-id --project-ref YOUR_PROJECT_REF --no-verify-jwt
   ```

   `--no-verify-jwt` is required because this endpoint handles sign-in before a session exists. The function itself requires a Login ID and password and verifies them with Supabase Auth. It does not authorise access to rental data.
3. Supabase supplies the runtime `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY`. Keep the service-role key exclusively in the server environment; do not put it in Dart, a website bundle, Git or a chat. If needed, configure `LOGIN_ID_ALLOWED_ORIGINS` as a comma-separated list of the actual site origins. The default is `https://quiet-pastelito-19fa50.netlify.app`.
4. Confirm the deployed function responds to an allowed-origin `GET` with `{"enabled":false}`. This checks deployment without exposing account information.
5. Only after deployment is verified, activate it in the project's SQL editor:

   ```sql
   update public.bp_login_id_config set enabled = true where singleton;
   ```

6. Refresh the application and open the profile. The current user's Login ID is shown. At login, **Email or Login ID** appears only after the status check and the function health check both succeed. Test the ID with the same password, then test email sign-in and password reset.

To disable the feature while keeping email login, set `enabled = false`. Existing account IDs stay assigned; they do not change on each login.

## Security boundaries

The browser has no ID-to-email lookup. A private ID mapping and an atomic shared limiter are accessible only to the server function. Anonymous/authenticated clients cannot read the mapping table or execute the resolving function. The server verifies the password through the standard Supabase Auth endpoint and returns only session tokens, never the account email. Unknown IDs and wrong passwords use the same response message.

The limiter permits at most ten ID attempts and sixty hashed-client attempts per ten-minute window, with a shared global cap to limit ID spraying. The ID/IP/global counters are database-backed across concurrent function instances. A failed or missing endpoint hides the optional login choice; email sign-in remains available. The limiter uses a keyed hash rather than storing raw IP addresses. No password, account mapping or session token is logged by this function.

## Prepared checks

- `test/login_id_session_test.dart`: saved session restart, explicit logout, alias uniqueness/format, unchanged password requirement, ID preserved across contact/password edits, role validation, anchored confirmation and Cancel on a 320-pixel phone.
- `test/cloud_store_test.dart`: optional activation/health gating and normal Auth session adoption.
- `node tool/login_id_endpoint_test.cjs`: isolated server contract with mocked fetch; no live credentials or network.
- `supabase/tests/login_ids.sql`: disabled default, private mapping/resolve permissions, recipient-only ID visibility and atomic attempt limit. The disposable test harness must provide the `service_role` database role; hosted Supabase already has it.

These checks do not establish that the optional function has been deployed or activated on the live project. Ordinary email sign-in and persistent sessions do not require the optional deployment.
