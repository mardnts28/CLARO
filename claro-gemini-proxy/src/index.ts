export interface Env {
  GEMINI_API_KEY: string;
  APP_SHARED_SECRET: string;
  EMAILJS_SERVICE_ID: string;
  EMAILJS_TEMPLATE_ID: string;
  EMAILJS_PUBLIC_KEY: string;
  EMAILJS_PRIVATE_KEY: string;
  // New secrets for password reset. Set with:
  //   wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON   (paste the whole JSON key file contents)
  //   wrangler secret put FIREBASE_WEB_API_KEY             (Firebase Console -> Project Settings -> General -> Web API Key)
  //   wrangler secret put EMAILJS_PASSWORD_RESET_TEMPLATE_ID
  FIREBASE_SERVICE_ACCOUNT_JSON: string;
  FIREBASE_WEB_API_KEY: string;
  EMAILJS_PASSWORD_RESET_TEMPLATE_ID: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Only allow POST requests
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Shared secret header from the app -- so randoms on the internet
    // can't use this Worker as a free Gemini/EmailJS relay. Same secret
    // gates every route below; it just proves "this call came from my
    // app build", not which route it's for.
    const appSecret = request.headers.get("X-App-Secret");
    if (appSecret !== env.APP_SHARED_SECRET) {
      return new Response("Unauthorized", { status: 401 });
    }

    const url = new URL(request.url);
    if (url.pathname === "/email") {
      return handleEmail(request, env);
    }
    if (url.pathname === "/password-reset") {
      return handlePasswordReset(request, env);
    }

    return handleGemini(request, env);
  },
};

async function handleEmail(request: Request, env: Env): Promise<Response> {
  try {
    // The app only sends the parts that change per-request (recipient,
    // OTP code, expiry time). service_id/template_id/user_id/accessToken
    // never leave this Worker.
    const { template_params } = (await request.json()) as {
      template_params: Record<string, unknown>;
    };

    const body = {
      service_id: env.EMAILJS_SERVICE_ID,
      template_id: env.EMAILJS_TEMPLATE_ID,
      user_id: env.EMAILJS_PUBLIC_KEY,
      accessToken: env.EMAILJS_PRIVATE_KEY,
      template_params,
    };

    const emailResponse = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
      method: "POST",
      headers: { "Content-Type": "application/json", origin: "http://localhost" },
      body: JSON.stringify(body),
    });

    const text = await emailResponse.text();
    return new Response(text, {
      status: emailResponse.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}

// ---------------------------------------------------------------------------
// Password reset via EmailJS (mirrors the OTP flow: generate the real
// Firebase reset link server-side using a service account, then hand the
// link to EmailJS instead of letting Firebase send its own default email).
// ---------------------------------------------------------------------------

interface FirebaseServiceAccount {
  client_email: string;
  private_key: string;
}

function base64UrlEncode(bytes: ArrayBuffer | string): string {
  let binary: string;
  if (typeof bytes === "string") {
    binary = btoa(bytes);
  } else {
    binary = btoa(String.fromCharCode(...new Uint8Array(bytes)));
  }
  return binary.replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// Signs a JWT with the Firebase service account's private key and
// exchanges it for a short-lived Google OAuth access token (the standard
// "JWT bearer" flow), scoped just for the Identity Toolkit (Firebase Auth
// admin) API -- nothing broader than what's needed to generate a reset link.
async function getGoogleAccessToken(env: Env): Promise<string> {
  const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON) as FirebaseServiceAccount;
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/identitytoolkit",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const unsignedJwt = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claimSet))}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt),
  );

  const jwt = `${unsignedJwt}.${base64UrlEncode(signature)}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = (await tokenResponse.json()) as { access_token?: string; error?: string; error_description?: string };

  if (!tokenResponse.ok || !tokenData.access_token) {
    throw new Error(
      `Failed to obtain Google access token: ${tokenData.error ?? tokenResponse.status} ${tokenData.error_description ?? ""}`,
    );
  }

  return tokenData.access_token;
}

async function handlePasswordReset(request: Request, env: Env): Promise<Response> {
  try {
    const { email } = (await request.json()) as { email?: string };

    if (!email || typeof email !== "string") {
      return new Response(JSON.stringify({ success: false, error: "invalid-email" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const accessToken = await getGoogleAccessToken(env);

    // Ask Identity Toolkit to GENERATE the reset link without emailing it
    // itself -- returnOobLink requires the admin-scoped access token above.
    const linkResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${env.FIREBASE_WEB_API_KEY}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          requestType: "PASSWORD_RESET",
          email,
          returnOobLink: true,
        }),
      },
    );

    const linkData = (await linkResponse.json()) as { oobLink?: string; error?: { message?: string } };

    if (!linkResponse.ok || !linkData.oobLink) {
      const message = linkData.error?.message ?? "";
      const code = message === "EMAIL_NOT_FOUND" ? "user-not-found" : "invalid-email";
      return new Response(JSON.stringify({ success: false, error: code }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Hand off to EmailJS exactly like the OTP email does -- same
    // service_id/public key, different template with a {{reset_link}}
    // variable instead of {{passcode}}.
    const emailBody = {
      service_id: env.EMAILJS_SERVICE_ID,
      template_id: env.EMAILJS_PASSWORD_RESET_TEMPLATE_ID,
      user_id: env.EMAILJS_PUBLIC_KEY,
      accessToken: env.EMAILJS_PRIVATE_KEY,
      template_params: {
        to_email: email,
        reset_link: linkData.oobLink,
      },
    };

    const emailResponse = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
      method: "POST",
      headers: { "Content-Type": "application/json", origin: "http://localhost" },
      body: JSON.stringify(emailBody),
    });

    if (!emailResponse.ok) {
      const detail = await emailResponse.text();
      return new Response(JSON.stringify({ success: false, error: "email-send-failed", detail }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}

async function handleGemini(request: Request, env: Env): Promise<Response> {
    try {
      const incoming = await request.json() as Record<string, unknown>;

      // "model" is sent by the app to pick which Gemini model to call
      // (e.g. "gemini-3.5-flash"). It's not sensitive, so it travels in
      // the request body. Everything else in the body (contents,
      // generationConfig, etc.) is forwarded to Gemini exactly as-is.
      const { model, ...geminiBody } = incoming;
      const modelName = typeof model === "string" && model.length > 0
        ? model
        : "gemini-1.5-flash";

      const geminiResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${env.GEMINI_API_KEY}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(geminiBody),
        }
      );

      const data = await geminiResponse.json();

      return new Response(JSON.stringify(data), {
        status: geminiResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      return new Response(JSON.stringify({ error: message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
}