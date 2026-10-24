/// Public client configuration. Database access is controlled by Auth and RLS,
/// never by keeping the publishable key secret. Do not add service-role keys.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://zmxxgetndtcyuwzwwjbd.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_j6yDJrang5-Gii3z0vQ0gw_ouAsfZuQ',
);
