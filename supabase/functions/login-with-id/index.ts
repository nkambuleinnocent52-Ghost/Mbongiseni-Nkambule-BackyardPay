// Optional public password endpoint. ID never replaces the password, and the
// service role is confined to the server. No account email is returned to callers.
const jsonHeaders = { "content-type": "application/json", "cache-control": "no-store" };
const apiUrl = Deno.env.get("SUPABASE_URL")!;
const publicKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const allowedOrigins = (Deno.env.get("LOGIN_ID_ALLOWED_ORIGINS") || "https://quiet-pastelito-19fa50.netlify.app").split(",").map((s) => s.trim());

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  const cors = origin && allowedOrigins.includes(origin) ? {
    "access-control-allow-origin": origin,
    "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
    "access-control-allow-methods": "GET, POST, OPTIONS", "vary": "Origin",
  } : {};
  const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers: { ...jsonHeaders, ...cors } });
  const failure = () => reply(400, { message: "The Login ID or password is incorrect, or sign-in is temporarily unavailable. Use your email or try again later." });
  if (origin && !allowedOrigins.includes(origin)) return reply(403, { message: "Sign-in is unavailable." });
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (!apiUrl || !publicKey || !serviceKey) return reply(503, { enabled: false });
  try {
    const adminHeaders = { "content-type": "application/json", "apikey": serviceKey, "authorization": `Bearer ${serviceKey}` };
    if (request.method === "GET") {
      const status = await fetch(`${apiUrl}/rest/v1/rpc/bp_login_id_enabled`, { method: "POST", headers: adminHeaders, body: "{}" });
      return reply(200, { enabled: status.ok && await status.json() === true });
    }
    if (request.method !== "POST" || Number(request.headers.get("content-length") || "0") > 4096) return failure();
    const raw = await request.text();
    if (raw.length > 4096) return failure();
    const body = JSON.parse(raw);
    const id = typeof body.loginId === "string" ? body.loginId.replace(/[ -]/g, "") : "";
    const password = typeof body.password === "string" ? body.password : "";
    if (!/^[1-9][0-9]{8}$/.test(id) || password.length < 1 || password.length > 1024) return failure();
    // Proxy IP is only one limiter. Per-ID and global DB limits still apply if
    // a gateway omits or rewrites a client address; raw IPs are never stored.
    const forwarded = request.headers.get("x-forwarded-for")?.split(",").pop()?.trim() || "unknown";
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(serviceKey), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(forwarded));
    const clientHash = Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
    const attempt = await fetch(`${apiUrl}/rest/v1/rpc/bp_begin_login_id_attempt`, { method: "POST", headers: adminHeaders, body: JSON.stringify({ requested_id: id, client_hash: clientHash }) });
    if (!attempt.ok) return failure();
    const resolved = await attempt.json();
    if (resolved.allowed !== true) return failure();
    // Unknown IDs still take the Auth password path; do not reveal an email or
    // distinguish unknown-ID from wrong-password through response messages.
    const auth = await fetch(`${apiUrl}/auth/v1/token?grant_type=password`, { method: "POST", headers: { "content-type": "application/json", "apikey": publicKey }, body: JSON.stringify({ email: resolved.email || "unknown-login-id@example.invalid", password }) });
    if (!auth.ok) return failure();
    const session = await auth.json();
    if (!session.refresh_token || !session.access_token) return failure();
    return reply(200, { access_token: session.access_token, refresh_token: session.refresh_token });
  } catch (_) {
    // Never log a request body, password, ID/email mapping or session token.
    return failure();
  }
});
