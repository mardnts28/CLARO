import { verifyFirebaseToken } from "./verifyToken";
import { encryptField, decryptField } from "./crypto";
import { getUserDoc, patchUserDoc } from "./firestore";
import {
  handleGroupMemberHealthProfileGet,
  handleGroupMemberHealthProfilePost,
} from "./groupMemberHealthProfile"; // Phase 6

import { Env } from "./env";

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
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      });
    }
  }
  
  newResponse.headers.set("Access-Control-Allow-Origin", allowedOrigin);
  newResponse.headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  newResponse.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
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

    const auth = request.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) {
      return addCorsHeaders(new Response("Unauthorized", { status: 401 }), origin, env);
    }
    let uid: string;
    try {
  uid = await verifyFirebaseToken(auth.slice(7), env.FIREBASE_PROJECT_ID);
} catch (e) {
  console.error("Token verification failed:", e);
  return addCorsHeaders(new Response("Invalid token", { status: 401 }), origin, env);
}

    const url = new URL(request.url);

    if (url.pathname === "/health-profile" && request.method === "GET") {
      const data = await getUserDoc(env, uid);
      return addCorsHeaders(Response.json({
        conditions: await decryptField(env, data.conditions),
        allergens: await decryptField(env, data.allergens),
      }), origin, env);
    }

    if (url.pathname === "/health-profile" && request.method === "POST") {
      const body = await request.json<{ conditions?: string[]; allergens?: string[] }>();
      const update: Record<string, string> = {};
      if (body.conditions) update.conditions = await encryptField(env, body.conditions);
      if (body.allergens) update.allergens = await encryptField(env, body.allergens);
      await patchUserDoc(env, uid, update);
      return addCorsHeaders(Response.json({ success: true }), origin, env);
    }

    // Phase 6 -- group-managed ("Option B") member health data. uid here
    // is already verified above, same as every other route in this file;
    // the group-ownership + sourceType==="managed" checks happen inside
    // these handlers (see groupMemberHealthProfile.ts).
    if (url.pathname === "/group-member-health-profile" && request.method === "POST") {
      const response = await handleGroupMemberHealthProfilePost(env, uid, request);
      return addCorsHeaders(response, origin, env);
    }
    if (url.pathname === "/group-member-health-profile" && request.method === "GET") {
      const response = await handleGroupMemberHealthProfileGet(env, uid, url);
      return addCorsHeaders(response, origin, env);
    }

    return addCorsHeaders(new Response("Not found", { status: 404 }), origin, env);
  },
};