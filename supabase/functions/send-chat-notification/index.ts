import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Json = Record<string, unknown>;

type NotificationEvent = {
  id: string;
  event_type: string;
  source_message_id: string;
  sender_id: string;
  recipient_id: string;
  order_id: string;
  title: string;
  body: string;
  data: Record<string, string>;
  status: "pending" | "processing" | "sent" | "failed";
  processing_started_at: string | null;
  attempts: number;
  updated_at: string;
};

type PushToken = { id: string; token: string };

const jsonHeaders = { "Content-Type": "application/json" };

function response(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function defaultEnvironmentKey(name: string): string | undefined {
  const raw = Deno.env.get(name);
  if (!raw) return undefined;
  try {
    return JSON.parse(raw).default as string | undefined;
  } catch {
    return undefined;
  }
}

function adminHeaders(): Record<string, string> {
  const key =
    defaultEnvironmentKey("SUPABASE_SECRET_KEYS") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key) throw new Error("supabase_admin_key_missing");
  const headers: Record<string, string> = {
    apikey: key,
    "Content-Type": "application/json",
  };
  if (key.split(".").length === 3) headers.Authorization = `Bearer ${key}`;
  return headers;
}

function publicApiKey(): string {
  const key =
    defaultEnvironmentKey("SUPABASE_PUBLISHABLE_KEYS") ??
    Deno.env.get("SUPABASE_ANON_KEY");
  if (!key) throw new Error("supabase_publishable_key_missing");
  return key;
}

async function authenticatedUserId(
  supabaseUrl: string,
  authorization: string,
): Promise<string | null> {
  const result = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: publicApiKey(), Authorization: authorization },
  });
  if (!result.ok) return null;
  const user = (await result.json()) as { id?: string };
  return user.id ?? null;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function stringToBase64Url(value: string): string {
  return bytesToBase64Url(new TextEncoder().encode(value));
}

function privateKeyBytes(pem: string): Uint8Array {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function googleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${stringToBase64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${stringToBase64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${bytesToBase64Url(new Uint8Array(signature))}`;
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenResponse.ok) throw new Error("fcm_oauth_failed");
  const payload = (await tokenResponse.json()) as { access_token?: string };
  if (!payload.access_token) throw new Error("fcm_oauth_failed");
  return payload.access_token;
}

async function restRows<T>(
  supabaseUrl: string,
  path: string,
  init: RequestInit = {},
): Promise<T[]> {
  const result = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: { ...adminHeaders(), ...(init.headers ?? {}) },
  });
  if (!result.ok) throw new Error(`database_request_failed_${result.status}`);
  if (result.status === 204) return [];
  return (await result.json()) as T[];
}

async function updateEvent(
  supabaseUrl: string,
  eventId: string,
  values: Json,
  filter = "",
): Promise<NotificationEvent[]> {
  return restRows<NotificationEvent>(
    supabaseUrl,
    `notification_events?id=eq.${eventId}${filter}&select=*`,
    {
      method: "PATCH",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ ...values, updated_at: new Date().toISOString() }),
    },
  );
}

async function removeInvalidToken(
  supabaseUrl: string,
  tokenId: string,
): Promise<void> {
  await restRows(
    supabaseUrl,
    `push_tokens?id=eq.${tokenId}`,
    { method: "DELETE", headers: { Prefer: "return=minimal" } },
  );
}

function invalidFcmToken(payload: unknown): boolean {
  const serialized = JSON.stringify(payload);
  return serialized.includes("UNREGISTERED") || serialized.includes("INVALID_ARGUMENT");
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return response(405, { error: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const authorization = request.headers.get("Authorization");
  if (!supabaseUrl || !authorization?.startsWith("Bearer ")) {
    return response(401, { error: "authentication_required" });
  }

  const callerId = await authenticatedUserId(supabaseUrl, authorization);
  if (!callerId) return response(401, { error: "authentication_required" });

  let messageId: string | undefined;
  let processingEventId: string | null = null;
  try {
    const body = (await request.json()) as { message_id?: string };
    messageId = body.message_id;
  } catch {
    return response(400, { error: "invalid_request" });
  }
  if (!messageId || !/^[0-9a-f-]{36}$/i.test(messageId)) {
    return response(400, { error: "invalid_message_id" });
  }

  try {
    const events = await restRows<NotificationEvent>(
      supabaseUrl,
      `notification_events?source_message_id=eq.${messageId}&event_type=eq.chat_message&select=*`,
    );
    const event = events[0];
    if (!event || event.sender_id !== callerId || event.recipient_id === callerId) {
      return response(403, { error: "notification_access_denied" });
    }
    if (event.status === "sent") return response(200, { status: "already_dispatched" });

    const rawServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!rawServiceAccount) return response(503, { error: "fcm_not_configured" });
    const serviceAccount = JSON.parse(rawServiceAccount) as {
      project_id?: string;
      client_email?: string;
      private_key?: string;
    };
    if (!serviceAccount.project_id || !serviceAccount.client_email || !serviceAccount.private_key) {
      return response(503, { error: "fcm_not_configured" });
    }

    if (event.status === "processing") {
      const started = event.processing_started_at
        ? Date.parse(event.processing_started_at)
        : Date.now();
      if (Date.now() - started < 5 * 60 * 1000) {
        return response(202, { status: "dispatch_in_progress" });
      }
    }

    const claimStatus = event.status === "processing" ? "processing" : event.status;
    const claimed = await updateEvent(
      supabaseUrl,
      event.id,
      {
        status: "processing",
        attempts: event.attempts + 1,
        processing_started_at: new Date().toISOString(),
        last_error: null,
      },
      `&status=eq.${claimStatus}&updated_at=eq.${encodeURIComponent(event.updated_at)}`,
    );
    if (claimed.length === 0) return response(202, { status: "dispatch_in_progress" });
    processingEventId = event.id;

    const tokens = await restRows<PushToken>(
      supabaseUrl,
      `push_tokens?user_id=eq.${event.recipient_id}&select=id,token`,
    );
    if (tokens.length === 0) {
      await updateEvent(supabaseUrl, event.id, {
        status: "sent",
        dispatched_at: new Date().toISOString(),
        processing_started_at: null,
        last_error: null,
      });
      return response(200, { status: "no_registered_devices", sent: 0 });
    }

    const accessToken = await googleAccessToken({
      client_email: serviceAccount.client_email,
      private_key: serviceAccount.private_key,
    });
    let sent = 0;
    let lastError = "fcm_delivery_failed";
    for (const device of tokens) {
      const fcmResponse = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: { title: event.title, body: event.body },
              data: { ...event.data, event_id: event.id },
              android: {
                priority: "high",
                notification: { channel_id: "cloud_kitchen_messages" },
              },
            },
          }),
        },
      );
      if (fcmResponse.ok) {
        sent++;
      } else {
        const errorPayload = await fcmResponse.json().catch(() => ({}));
        lastError = `fcm_delivery_failed_${fcmResponse.status}`;
        if (invalidFcmToken(errorPayload)) await removeInvalidToken(supabaseUrl, device.id);
      }
    }

    if (sent > 0) {
      await updateEvent(supabaseUrl, event.id, {
        status: "sent",
        dispatched_at: new Date().toISOString(),
        processing_started_at: null,
        last_error: null,
      });
      processingEventId = null;
      return response(200, { status: "sent", sent });
    }

    await updateEvent(supabaseUrl, event.id, {
      status: "failed",
      processing_started_at: null,
      last_error: lastError,
    });
    processingEventId = null;
    return response(502, { error: "fcm_delivery_failed" });
  } catch (error) {
    if (processingEventId && supabaseUrl) {
      await updateEvent(supabaseUrl, processingEventId, {
        status: "failed",
        processing_started_at: null,
        last_error: error instanceof Error ? error.message : "notification_dispatch_failed",
      }).catch(() => undefined);
    }
    return response(500, {
      error: error instanceof Error ? error.message : "notification_dispatch_failed",
    });
  }
});
