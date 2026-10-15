import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically
// by Supabase to every Edge Function — no need to set them ourselves
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// This one we DO set ourselves (the Firebase service account JSON, as text).
// Read on first use, so a missing or broken secret answers with a clear
// error instead of crashing the whole function with a bare WORKER_ERROR.
type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};
let serviceAccount: ServiceAccount | null = null;

function getServiceAccount(): ServiceAccount {
  if (serviceAccount) return serviceAccount;

  // Either name works (the dashboard secret may be saved with "_JSON")
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ??
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT (or FIREBASE_SERVICE_ACCOUNT_JSON) secret is not set (Edge Functions -> Secrets)",
    );
  }

  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(raw);
  } catch (_) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT is not valid JSON - paste the whole .json file, from { to }",
    );
  }
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT is missing project_id, client_email or private_key",
    );
  }

  // Some editors turn the key's line breaks into a literal "\n"
  parsed.private_key = parsed.private_key.replace(/\\n/g, "\n");
  serviceAccount = parsed;
  return parsed;
}

// Exchanges the service account key for a short-lived FCM access token
async function getAccessToken(): Promise<string> {
  const account = getServiceAccount();
  const privateKey = await importPKCS8(account.private_key, "RS256");
  const now = Math.floor(Date.now() / 1000);

  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!data.access_token) {
    throw new Error("Failed to get FCM access token: " + JSON.stringify(data));
  }
  return data.access_token;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status });
}

// Called by the app (SupabaseCallPushSender) to wake the other phone:
//   { action: "invite" | "cancel", call: CallModel.toJson() }
// The Flutter side reads these keys in CallModel.fromPushData and
// firebaseMessagingBackgroundHandler (type "call" / "call_cancel").
Deno.serve(async (req) => {
  try {
    // Fails fast with a readable reason if the Firebase secret is broken
    getServiceAccount();

    const { action, call } = await req.json();
    if (
      (action !== "invite" && action !== "cancel") ||
      !call?.callId || !call?.callerId || !call?.receiverId
    ) {
      return json({ error: "action and call are required" }, 400);
    }

    // Service role key = ignores RLS, so we can read the other person's tokens
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Only someone who is part of this call may ring / cancel it
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await supabase.auth.getUser(jwt);
    if (!user || (user.id !== call.callerId && user.id !== call.receiverId)) {
      return json({ error: "not allowed" }, 401);
    }

    // The push always goes to the OTHER person in the call
    const targetId = user.id === call.callerId ? call.receiverId : call.callerId;

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", targetId);

    if (!tokens || tokens.length === 0) {
      return json({ sent: 0 });
    }

    // All FCM data values must be strings
    const data: Record<string, string> = action === "invite"
      ? {
        type: "call",
        call_id: String(call.callId),
        caller_id: String(call.callerId),
        receiver_id: String(call.receiverId),
        channel_id: String(call.channelId ?? ""),
        call_type: call.type === "video" ? "video" : "audio",
        caller_name: String(call.callerName ?? ""),
        receiver_name: String(call.receiverName ?? ""),
      }
      : {
        type: "call_cancel",
        call_id: String(call.callId),
      };

    const accessToken = await getAccessToken();

    // Data-only, high priority, short TTL: a call that rang a minute ago
    // should never show up later
    const results = await Promise.allSettled(
      tokens.map((t) =>
        fetch(
          `https://fcm.googleapis.com/v1/projects/${getServiceAccount().project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: t.token,
                data,
                android: { priority: "high", ttl: "45s" },
                apns: {
                  headers: { "apns-priority": "10" },
                  payload: { aps: { "content-available": 1 } },
                },
              },
            }),
          },
        ).then(async (r) => {
          if (!r.ok) {
            const errText = await r.text();
            // Token is no longer valid on Firebase's side -> clean it up
            if (errText.includes("UNREGISTERED") || errText.includes("NOT_FOUND")) {
              await supabase.from("device_tokens").delete().eq("token", t.token);
            }
            throw new Error(errText);
          }
          return r.json();
        }),
      ),
    );

    const sentCount = results.filter((r) => r.status === "fulfilled").length;
    return json({ sent: sentCount, total: tokens.length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
