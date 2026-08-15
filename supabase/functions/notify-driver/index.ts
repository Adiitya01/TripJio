// ============================================================
// TripJio — notify-driver Edge Function
// ============================================================
// Triggered by Supabase Database Webhook when a new row is
// inserted in `requests`. Looks up the driver's FCM token and
// sends a push notification via Firebase Cloud Messaging.
// ============================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface RequestPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: {
    id: string;
    driver_id: string;
    load_owner_id: string;
    pickup_address: string;
    drop_address: string;
    status: string;
    weight_kg: number | null;
  };
  old_record: unknown;
  schema: string;
}

// Read Firebase service account from Supabase secret
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
const FCM_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "tripjio-dev";

if (!FIREBASE_SERVICE_ACCOUNT) {
  console.error("Missing FIREBASE_SERVICE_ACCOUNT secret");
}

// Cache OAuth token between invocations
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  // Reuse cached token if still valid
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.token;
  }

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT!);

  // Build JWT for OAuth
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const header = { alg: "RS256", typ: "JWT" };

  const encoder = new TextEncoder();
  const b64Url = (data: string) =>
    btoa(data).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const headerB64 = b64Url(JSON.stringify(header));
  const claimB64 = b64Url(JSON.stringify(claim));
  const signInput = `${headerB64}.${claimB64}`;

  // Import RSA private key
  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(signInput)
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${signInput}.${sigB64}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error(`OAuth failed: ${JSON.stringify(tokenData)}`);
  }

  cachedToken = {
    token: tokenData.access_token,
    expiresAt: Date.now() + tokenData.expires_in * 1000,
  };
  return cachedToken.token;
}

async function sendFcm(token: string, title: string, body: string, data: Record<string, string>) {
  const accessToken = await getAccessToken();

  const message = {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        priority: "HIGH",
        notification: {
          channel_id: "tripjio_main",
          sound: "default",
          icon: "ic_stat_notification",
        },
      },
    },
  };

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    }
  );

  const result = await res.json();
  console.log("FCM result:", JSON.stringify(result));
  return result;
}

Deno.serve(async (req) => {
  try {
    const payload: RequestPayload = await req.json();
    console.log("Webhook payload:", JSON.stringify(payload).slice(0, 200));

    if (payload.type !== "INSERT" || payload.table !== "requests") {
      return new Response("Ignored — not a request INSERT", { status: 200 });
    }

    const request = payload.record;

    // Connect to Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Look up driver's FCM token
    const { data: session, error: sessionError } = await supabase
      .from("active_sessions")
      .select("fcm_token")
      .eq("user_id", request.driver_id)
      .single();

    if (sessionError || !session?.fcm_token) {
      console.log("No FCM token for driver:", request.driver_id);
      return new Response("No FCM token", { status: 200 });
    }

    // Look up load owner name (for personalized notification)
    const { data: loadOwner } = await supabase
      .from("users")
      .select("name")
      .eq("id", request.load_owner_id)
      .single();

    const ownerName = loadOwner?.name ?? "Load Owner";

    // Send FCM
    const result = await sendFcm(
      session.fcm_token,
      "🚛 New Load Request!",
      `${ownerName} · ${request.pickup_address} → ${request.drop_address}`,
      {
        type: "incoming_request",
        request_id: request.id,
        load_owner_id: request.load_owner_id,
      }
    );

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Edge function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
