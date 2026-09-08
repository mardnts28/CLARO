export interface Env {
  GEMINI_API_KEY: string;
  APP_SHARED_SECRET: string;
  EMAILJS_SERVICE_ID: string;
  EMAILJS_TEMPLATE_ID: string;
  EMAILJS_PUBLIC_KEY: string;
  EMAILJS_PRIVATE_KEY: string;
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