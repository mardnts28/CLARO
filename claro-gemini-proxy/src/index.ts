export interface Env {
  GEMINI_API_KEY: string;
  APP_SHARED_SECRET: string;
  EMAILJS_SERVICE_ID: string;
  EMAILJS_TEMPLATE_ID: string;
  EMAILJS_PUBLIC_KEY: string;
  EMAILJS_PRIVATE_KEY: string;
}

function addCorsHeaders(response: Response): Response {
  const newResponse = new Response(response.body, response);
  newResponse.headers.set("Access-Control-Allow-Origin", "*");
  newResponse.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  newResponse.headers.set("Access-Control-Allow-Headers", "Content-Type, X-App-Secret");
  return newResponse;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight requests
    if (request.method === "OPTIONS") {
      return addCorsHeaders(new Response(null, { status: 204 }));
    }

    // Only allow POST requests
    if (request.method !== "POST") {
      return addCorsHeaders(new Response("Method not allowed", { status: 405 }));
    }

    // Shared secret header from the app -- so randoms on the internet
    // can't use this Worker as a free Gemini/EmailJS relay. Same secret
    // gates every route below; it just proves "this call came from my
    // app build", not which route it's for.
    const appSecret = request.headers.get("X-App-Secret");
    if (appSecret !== env.APP_SHARED_SECRET) {
      return addCorsHeaders(new Response("Unauthorized", { status: 401 }));
    }

    const url = new URL(request.url);
    let response: Response;
    if (url.pathname === "/email") {
      response = await handleEmail(request, env);
    } else {
      response = await handleGemini(request, env);
    }

    return addCorsHeaders(response);
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

      // Retry logic for geographic restrictions and transient errors
      const maxRetries = 3;
      let lastError: Error | null = null;

      for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
          const geminiResponse = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${env.GEMINI_API_KEY}`,
            {
              method: "POST",
              headers: { 
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
              },
              body: JSON.stringify(geminiBody),
            }
          );

          const data = await geminiResponse.json();

          // If successful, return immediately
          if (geminiResponse.status === 200) {
            return new Response(JSON.stringify(data), {
              status: geminiResponse.status,
              headers: { "Content-Type": "application/json" },
            });
          }

          // If it's a geographic restriction error, retry with exponential backoff
          if (geminiResponse.status === 400 && data.error?.message?.includes("location")) {
            console.log(`Geographic restriction on attempt ${attempt + 1}, retrying...`);
            lastError = new Error(data.error?.message || "Geographic restriction");
            if (attempt < maxRetries - 1) {
              // Exponential backoff: 1s, 2s, 4s
              const delay = Math.pow(2, attempt) * 1000;
              await new Promise(resolve => setTimeout(resolve, delay));
              continue;
            }
          }

          // For other errors, return immediately
          return new Response(JSON.stringify(data), {
            status: geminiResponse.status,
            headers: { "Content-Type": "application/json" },
          });
        } catch (fetchErr) {
          lastError = fetchErr instanceof Error ? fetchErr : new Error("Unknown fetch error");
          console.log(`Fetch error on attempt ${attempt + 1}:`, lastError.message);
          if (attempt < maxRetries - 1) {
            const delay = Math.pow(2, attempt) * 1000;
            await new Promise(resolve => setTimeout(resolve, delay));
            continue;
          }
        }
      }

      // All retries exhausted
      return new Response(JSON.stringify({
        error: {
          code: 400,
          message: lastError?.message || "Failed after multiple retries",
          status: "FAILED_PRECONDITION"
        }
      }), {
        status: 400,
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