export interface Env {
  GEMINI_API_KEY: string;
  APP_SHARED_SECRET: string;
  EMAILJS_SERVICE_ID: string;
  EMAILJS_TEMPLATE_ID: string;
  EMAILJS_PUBLIC_KEY: string;
  EMAILJS_PRIVATE_KEY: string;
  EMAILJS_CONTACT_SERVICE_ID?: string; // Optional service for contact form
  EMAILJS_CONTACT_TEMPLATE_ID?: string; // Optional template for contact form
  EMAILJS_CONTACT_PUBLIC_KEY?: string; // Optional public key for contact form account
  EMAILJS_CONTACT_PRIVATE_KEY?: string; // Optional private key for contact form account
  CORS_ALLOWED_ORIGINS?: string; // Comma-separated list of allowed origins
}

function addCorsHeaders(response: Response, origin: string | null, env: Env): Response {
  const newResponse = new Response(response.body, response);
  
  // Check if we have allowed origins configured
  const allowedOrigins = env.CORS_ALLOWED_ORIGINS
    ? env.CORS_ALLOWED_ORIGINS.split(',').map(o => o.trim())
    : [];

  // CORS logic:
  // 1. If no origins configured: use wildcard (backward compatibility)
  // 2. If no Origin header: assume native app (no CORS needed), use wildcard
  // 3. If Origin header present: check against allowed list
  let allowedOrigin = '*';

  if (allowedOrigins.length > 0) {
    if (!origin) {
      // No Origin header = native mobile app (Flutter, iOS, Android)
      // Native apps don't have CORS, so we allow them with wildcard
      allowedOrigin = '*';
    } else if (allowedOrigins.includes(origin)) {
      // Origin is in allowed list (web browser from allowed domain)
      allowedOrigin = origin;
    } else {
      // Origin not in allowed list (web browser from disallowed domain)
      // Don't set CORS headers to block the request
      return newResponse(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      });
    }
  }
  
  newResponse.headers.set("Access-Control-Allow-Origin", allowedOrigin);
  newResponse.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  newResponse.headers.set("Access-Control-Allow-Headers", "Content-Type, X-App-Secret");
  if (allowedOrigin !== '*') {
    newResponse.headers.set("Access-Control-Allow-Credentials", "true");
    newResponse.headers.set("Vary", "Origin");
  }
  return newResponse;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get("Origin");

    // Handle CORS preflight requests
    if (request.method === "OPTIONS") {
      return addCorsHeaders(new Response(null, { status: 204 }), origin, env);
    }

    // Only allow POST requests
    if (request.method !== "POST") {
      return addCorsHeaders(new Response("Method not allowed", { status: 405 }), origin, env);
    }

    // Shared secret header from the app -- so randoms on the internet
    // can't use this Worker as a free Gemini/EmailJS relay. Same secret
    // gates every route below; it just proves "this call came from my
    // app build", not which route it's for.
    const appSecret = request.headers.get("X-App-Secret");
    if (appSecret !== env.APP_SHARED_SECRET) {
      return addCorsHeaders(new Response("Unauthorized", { status: 401 }), origin, env);
    }

    const url = new URL(request.url);
    let response: Response;
    if (url.pathname === "/email") {
      response = await handleEmail(request, env);
    } else {
      response = await handleGemini(request, env);
    }

    return addCorsHeaders(response, origin, env);
  },
};

async function handleEmail(request: Request, env: Env): Promise<Response> {
  try {
    const { template_params } = (await request.json()) as {
      template_params: Record<string, unknown>;
    };

    // Detect if this is a contact form email or OTP email
    // Contact form has: from_name, from_email, message
    // OTP email has: passcode, time
    const isContactForm = !!(template_params.from_name && template_params.from_email && template_params.message);

    // Use appropriate service, template, and keys
    const serviceId = isContactForm && env.EMAILJS_CONTACT_SERVICE_ID
      ? env.EMAILJS_CONTACT_SERVICE_ID
      : env.EMAILJS_SERVICE_ID;
    const templateId = isContactForm && env.EMAILJS_CONTACT_TEMPLATE_ID
      ? env.EMAILJS_CONTACT_TEMPLATE_ID
      : env.EMAILJS_TEMPLATE_ID;
    const publicKey = isContactForm && env.EMAILJS_CONTACT_PUBLIC_KEY
      ? env.EMAILJS_CONTACT_PUBLIC_KEY
      : env.EMAILJS_PUBLIC_KEY;
    const privateKey = isContactForm && env.EMAILJS_CONTACT_PRIVATE_KEY
      ? env.EMAILJS_CONTACT_PRIVATE_KEY
      : env.EMAILJS_PRIVATE_KEY;

    console.log(`Email request: isContactForm=${isContactForm}, serviceId=${serviceId}, templateId=${templateId}`);
    console.log(`Template params:`, JSON.stringify(template_params));

    const body = {
      service_id: serviceId,
      template_id: templateId,
      user_id: publicKey,
      accessToken: privateKey,
      template_params,
    };

    const emailResponse = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
      method: "POST",
      headers: { "Content-Type": "application/json", origin: "http://localhost" },
      body: JSON.stringify(body),
    });

    const text = await emailResponse.text();
    console.log(`EmailJS response: ${emailResponse.status} - ${text}`);

    return new Response(text, {
      status: emailResponse.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error(`Email error: ${message}`);
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