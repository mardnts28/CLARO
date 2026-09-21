import { verifyFirebaseToken } from "./verifyToken";
import { encryptField, decryptField } from "./crypto";
import { getUserDoc, patchUserDoc } from "./firestore";
import {
  handleGroupMemberHealthProfileGet,
  handleGroupMemberHealthProfilePost,
} from "./groupMemberHealthProfile"; // Phase 6

import { Env } from "./env";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const auth = request.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) {
      return new Response("Unauthorized", { status: 401 });
    }
    let uid: string;
    try {
  uid = await verifyFirebaseToken(auth.slice(7), env.FIREBASE_PROJECT_ID);
} catch (e) {
  console.error("Token verification failed:", e);
  return new Response("Invalid token", { status: 401 });
}

    const url = new URL(request.url);

    if (url.pathname === "/health-profile" && request.method === "GET") {
      const data = await getUserDoc(env, uid);
      return Response.json({
        conditions: await decryptField(env, data.conditions),
        allergens: await decryptField(env, data.allergens),
      });
    }

    if (url.pathname === "/health-profile" && request.method === "POST") {
      const body = await request.json<{ conditions?: string[]; allergens?: string[] }>();
      const update: Record<string, string> = {};
      if (body.conditions) update.conditions = await encryptField(env, body.conditions);
      if (body.allergens) update.allergens = await encryptField(env, body.allergens);
      await patchUserDoc(env, uid, update);
      return Response.json({ success: true });
    }

    // Phase 6 -- group-managed ("Option B") member health data. uid here
    // is already verified above, same as every other route in this file;
    // the group-ownership + sourceType==="managed" checks happen inside
    // these handlers (see groupMemberHealthProfile.ts).
    if (url.pathname === "/group-member-health-profile" && request.method === "POST") {
      return handleGroupMemberHealthProfilePost(env, uid, request);
    }
    if (url.pathname === "/group-member-health-profile" && request.method === "GET") {
      return handleGroupMemberHealthProfileGet(env, uid, url);
    }

    return new Response("Not found", { status: 404 });
  },
};