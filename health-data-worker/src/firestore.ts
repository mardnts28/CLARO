// src/firestore.ts
//
// CORRECTED Phase 6 addition. Everything above the line marked below is
// your existing file, completely untouched. Added: two generic
// path-based helpers (getDocByPath/patchDocByPath) that getUserDoc/
// patchUserDoc could in principle be rewritten in terms of -- but I've
// left those two alone rather than risk touching something that already
// works. The new group-scoped functions below just call the generic
// helpers directly.

import { Env } from "./env";

import { SignJWT, importPKCS8 } from "jose";

// Every Firestore REST call needs a Google OAuth access token. Minting one
// means parsing the RSA private key, signing a JWT and making a network
// round-trip to oauth2.googleapis.com -- and this file used to do that on
// EVERY call. A single group-member health read makes 3-5 Firestore calls,
// so it minted 3-5 tokens per request (vs. 1 for the plain /health-profile
// route), which is what pushed the group routes over the Worker's CPU
// budget for exactly the "someone else's linked profile" cases. The token
// is valid for an hour, so keep it per isolate and reuse it.
let cachedToken: { value: string; expiresAtMs: number } | null = null;
let inflightToken: Promise<string> | null = null;

async function getAccessToken(env: Env): Promise<string> {
  if (cachedToken && cachedToken.expiresAtMs - 60_000 > Date.now()) {
    return cachedToken.value;
  }
  if (!inflightToken) {
    inflightToken = mintAccessToken(env)
      .then(t => {
        cachedToken = { value: t.token, expiresAtMs: Date.now() + t.expiresInSec * 1000 };
        return t.token;
      })
      .finally(() => {
        inflightToken = null;
      });
  }
  return inflightToken;
}

async function mintAccessToken(env: Env): Promise<{ token: string; expiresInSec: number }> {
  const privateKey = await importPKCS8(env.GCP_PRIVATE_KEY, "RS256");
  const now = Math.floor(Date.now() / 1000);
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(env.GCP_CLIENT_EMAIL)
    .setSubject(env.GCP_CLIENT_EMAIL)
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
  const data = await res.json<{
    access_token: string;
    expires_in?: number;
    error?: string;
    error_description?: string;
  }>();

  if (!data.access_token) {
    throw new Error(
      `OAuth token exchange failed: ${data.error ?? "unknown"} — ${data.error_description ?? ""}`
    );
  }

  return { token: data.access_token, expiresInSec: data.expires_in ?? 3600 };
}

const FIRESTORE_BASE = (projectId: string) =>
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

export async function getUserDoc(env: Env, uid: string): Promise<Record<string, any>> {
  const token = await getAccessToken(env);
  const res = await fetch(`${FIRESTORE_BASE(env.FIREBASE_PROJECT_ID)}/users/${uid}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (res.status === 404) return {};

  const doc = await res.json<{ fields?: Record<string, any>; error?: any }>();

  if (!res.ok) {
    throw new Error(`Firestore read failed: ${res.status} — ${JSON.stringify(doc)}`);
  }

  return unwrapFirestoreFields(doc.fields ?? {});
}

export async function patchUserDoc(env: Env, uid: string, fields: Record<string, string>) {
  const token = await getAccessToken(env);
  const mask = Object.keys(fields).map(k => `updateMask.fieldPaths=${k}`).join("&");
  const res = await fetch(`${FIRESTORE_BASE(env.FIREBASE_PROJECT_ID)}/users/${uid}?${mask}`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ fields: wrapFirestoreFields(fields) }),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`Firestore write failed: ${res.status} — ${errBody}`);
  }
}

// Firestore REST wraps every value in a type descriptor, e.g. {"stringValue": "..."}
function wrapFirestoreFields(obj: Record<string, string>) {
  const out: Record<string, any> = {};
  for (const [k, v] of Object.entries(obj)) out[k] = { stringValue: v };
  return out;
}
function unwrapFirestoreFields(fields: Record<string, any>) {
  const out: Record<string, any> = {};
  for (const [k, v] of Object.entries(fields)) {
    out[k] =
      v.stringValue ??
      v.arrayValue?.values?.map((x: any) => x.stringValue) ??
      v.booleanValue ??
      null;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// NEW (Phase 6) below this line. Generic versions of the two functions
// above, parameterized by document path instead of hardcoded to
// `users/{uid}`, so they can read/write `groups/{id}` and
// `groups/{id}/members/{memberId}` too without duplicating the OAuth +
// wrap/unwrap logic a third and fourth time.
// ─────────────────────────────────────────────────────────────────────

export async function getDocByPath(env: Env, path: string): Promise<Record<string, any> | null> {
  const token = await getAccessToken(env);
  const res = await fetch(`${FIRESTORE_BASE(env.FIREBASE_PROJECT_ID)}/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (res.status === 404) return null;

  const doc = await res.json<{ fields?: Record<string, any>; error?: any }>();
  if (!res.ok) {
    throw new Error(`Firestore read failed (${path}): ${res.status} — ${JSON.stringify(doc)}`);
  }
  return unwrapFirestoreFields(doc.fields ?? {});
}

export async function patchDocByPath(
  env: Env,
  path: string,
  fields: Record<string, string>,
  // Fields written as real Firestore timestampValue (ISO-8601 input), so
  // the Flutter client's `as Timestamp` reads work.
  timestampFields: Record<string, string> = {}
) {
  const token = await getAccessToken(env);
  const mask = [...Object.keys(fields), ...Object.keys(timestampFields)]
    .map(k => `updateMask.fieldPaths=${k}`)
    .join("&");
  const wrapped: Record<string, any> = wrapFirestoreFields(fields);
  for (const [k, iso] of Object.entries(timestampFields)) {
    wrapped[k] = { timestampValue: iso };
  }
  const res = await fetch(`${FIRESTORE_BASE(env.FIREBASE_PROJECT_ID)}/${path}?${mask}`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ fields: wrapped }),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`Firestore write failed (${path}): ${res.status} — ${errBody}`);
  }
}

/** Reads `groups/{groupId}` -- used to check `ownerUid` before any
 * group-member write/read is allowed. */
export async function getGroupDoc(env: Env, groupId: string) {
  return getDocByPath(env, `groups/${groupId}`);
}

/** Reads `groups/{groupId}/members/{memberId}` -- used to check
 * `sourceType === "managed"` (never "linked") before allowing a write. */
export async function getGroupMemberDoc(env: Env, groupId: string, memberId: string) {
  return getDocByPath(env, `groups/${groupId}/members/${memberId}`);
}

/** Writes conditionsEncrypted/allergensEncrypted onto a managed member's
 * doc. `updatedAt` is stored as an ISO string (not a Firestore
 * timestampValue) so this can reuse wrapFirestoreFields' plain-string
 * wrapping without extending it for a second value type. */
export async function patchGroupMemberHealthDoc(
  env: Env,
  groupId: string,
  memberId: string,
  fields: { conditionsEncrypted: string; allergensEncrypted: string }
) {
  return patchDocByPath(
    env,
    `groups/${groupId}/members/${memberId}`,
    {
      conditionsEncrypted: fields.conditionsEncrypted,
      allergensEncrypted: fields.allergensEncrypted,
    },
    { updatedAt: new Date().toISOString() }
  );
}