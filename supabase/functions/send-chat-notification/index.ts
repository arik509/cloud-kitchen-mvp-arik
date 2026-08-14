import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Json = Record<string, unknown>;
type NotificationEvent = {
  id: string; event_type: string; source_message_id: string | null;
  sender_id: string; recipient_id: string; order_id: string;
  title: string; body: string; data: Record<string, string>;
  status: "pending" | "processing" | "sent" | "failed";
  processing_started_at: string | null; attempts: number; updated_at: string;
};
type PushToken = { id: string; token: string };

const jsonHeaders = { "Content-Type": "application/json" };
const response = (status: number, body: Json) =>
  new Response(JSON.stringify(body), { status, headers: jsonHeaders });
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function defaultEnvironmentKey(name: string): string | undefined {
  const raw = Deno.env.get(name);
  if (!raw) return undefined;
  try { return JSON.parse(raw).default as string | undefined; } catch { return undefined; }
}

function adminHeaders(): Record<string, string> {
  const key = defaultEnvironmentKey("SUPABASE_SECRET_KEYS") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key) throw new Error("supabase_admin_key_missing");
  return {
    apikey: key,
    "Content-Type": "application/json",
    ...(key.split(".").length === 3 ? { Authorization: `Bearer ${key}` } : {}),
  };
}

function publicApiKey(): string {
  const key = defaultEnvironmentKey("SUPABASE_PUBLISHABLE_KEYS") ?? Deno.env.get("SUPABASE_ANON_KEY");
  if (!key) throw new Error("supabase_publishable_key_missing");
  return key;
}

async function authenticatedUserId(url: string, authorization: string): Promise<string | null> {
  const result = await fetch(`${url}/auth/v1/user`, { headers: { apikey: publicApiKey(), Authorization: authorization } });
  if (!result.ok) return null;
  return ((await result.json()) as { id?: string }).id ?? null;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
const stringToBase64Url = (value: string) => bytesToBase64Url(new TextEncoder().encode(value));
function privateKeyBytes(pem: string): Uint8Array {
  const binary = atob(pem.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").replaceAll(/\s/g, ""));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function googleAccessToken(account: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${stringToBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${stringToBase64Url(JSON.stringify({
    iss: account.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }))}`;
  const key = await crypto.subtle.importKey("pkcs8", privateKeyBytes(account.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${bytesToBase64Url(new Uint8Array(signature))}` }),
  });
  if (!tokenResponse.ok) throw new Error("fcm_oauth_failed");
  const payload = (await tokenResponse.json()) as { access_token?: string };
  if (!payload.access_token) throw new Error("fcm_oauth_failed");
  return payload.access_token;
}

async function restRows<T>(url: string, path: string, init: RequestInit = {}): Promise<T[]> {
  const result = await fetch(`${url}/rest/v1/${path}`, { ...init, headers: { ...adminHeaders(), ...(init.headers ?? {}) } });
  if (!result.ok) throw new Error(`database_request_failed_${result.status}`);
  return result.status === 204 ? [] : (await result.json()) as T[];
}

const updateEvent = (url: string, id: string, values: Json, filter = "") =>
  restRows<NotificationEvent>(url, `notification_events?id=eq.${id}${filter}&select=*`, {
    method: "PATCH", headers: { Prefer: "return=representation" },
    body: JSON.stringify({ ...values, updated_at: new Date().toISOString() }),
  });

function invalidFcmToken(payload: unknown): boolean {
  const value = JSON.stringify(payload);
  return value.includes("UNREGISTERED") || value.includes("INVALID_ARGUMENT");
}

async function dispatchEvent(url: string, event: NotificationEvent, accessToken: string, projectId: string): Promise<number> {
  if (event.status === "sent") return 0;
  if (event.status === "processing" && Date.now() - Date.parse(event.processing_started_at ?? event.updated_at) < 300000) return 0;
  const claimed = await updateEvent(url, event.id, {
    status: "processing", attempts: event.attempts + 1,
    processing_started_at: new Date().toISOString(), last_error: null,
  }, `&status=eq.${event.status}&updated_at=eq.${encodeURIComponent(event.updated_at)}`);
  if (claimed.length === 0) return 0;
  try {
    const tokens = await restRows<PushToken>(url, `push_tokens?user_id=eq.${event.recipient_id}&select=id,token`);
    let sent = 0;
    for (const device of tokens) {
      const result = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST", headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ message: {
          token: device.token, notification: { title: event.title, body: event.body },
          data: { ...event.data, event_id: event.id },
          android: { priority: "high", notification: { channel_id: "cloud_kitchen_messages" } },
        } }),
      });
      if (result.ok) sent++;
      else {
        const payload = await result.json().catch(() => ({}));
        if (invalidFcmToken(payload)) await restRows(url, `push_tokens?id=eq.${device.id}`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
      }
    }
    await updateEvent(url, event.id, {
      status: tokens.length === 0 || sent > 0 ? "sent" : "failed",
      dispatched_at: tokens.length === 0 || sent > 0 ? new Date().toISOString() : null,
      processing_started_at: null, last_error: tokens.length > 0 && sent === 0 ? "fcm_delivery_failed" : null,
    });
    return sent;
  } catch (error) {
    await updateEvent(url, event.id, { status: "failed", processing_started_at: null, last_error: error instanceof Error ? error.message : "notification_dispatch_failed" });
    return 0;
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return response(405, { error: "method_not_allowed" });
  const url = Deno.env.get("SUPABASE_URL");
  const authorization = request.headers.get("Authorization");
  if (!url || !authorization?.startsWith("Bearer ")) return response(401, { error: "authentication_required" });
  const callerId = await authenticatedUserId(url, authorization);
  if (!callerId) return response(401, { error: "authentication_required" });
  let messageId: string | undefined;
  let orderId: string | undefined;
  try {
    const body = (await request.json()) as { message_id?: string; order_id?: string };
    messageId = body.message_id; orderId = body.order_id;
  } catch { return response(400, { error: "invalid_request" }); }
  if ((!messageId || !uuid.test(messageId)) && (!orderId || !uuid.test(orderId))) return response(400, { error: "invalid_notification_reference" });
  try {
    const filter = messageId
      ? `source_message_id=eq.${messageId}`
      : `order_id=eq.${orderId}&sender_id=eq.${callerId}&status=in.(pending,failed)`;
    const events = await restRows<NotificationEvent>(url, `notification_events?${filter}&select=*&order=created_at.asc`);
    const event = events[0];
    if (messageId && event && (event.sender_id !== callerId || event.recipient_id === callerId)) {
      return response(403, { error: "notification_access_denied" });
    }
    const authorized = events.filter((event) => event.sender_id === callerId && event.recipient_id !== callerId);
    if (authorized.length === 0) return response(200, { status: "nothing_to_dispatch", sent: 0 });
    const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!raw) return response(503, { error: "fcm_not_configured" });
    const account = JSON.parse(raw) as { project_id?: string; client_email?: string; private_key?: string };
    if (!account.project_id || !account.client_email || !account.private_key) return response(503, { error: "fcm_not_configured" });
    const accessToken = await googleAccessToken({ client_email: account.client_email, private_key: account.private_key });
    let sent = 0;
    for (const event of authorized) sent += await dispatchEvent(url, event, accessToken, account.project_id);
    return response(200, { status: "processed", events: authorized.length, sent });
  } catch (error) {
    return response(500, { error: error instanceof Error ? error.message : "notification_dispatch_failed" });
  }
});
