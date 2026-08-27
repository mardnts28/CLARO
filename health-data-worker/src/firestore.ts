import { Env } from "./env";

import { SignJWT, importPKCS8 } from "jose";

async function getAccessToken(env: Env): Promise<string> {
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
    error?: string;
    error_description?: string;
  }>();

  if (!data.access_token) {
    throw new Error(
      `OAuth token exchange failed: ${data.error ?? "unknown"} — ${data.error_description ?? ""}`
    );
  }

  return data.access_token;
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