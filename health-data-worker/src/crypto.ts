import { Env } from "./env";

async function getKey(env: Env): Promise<CryptoKey> {
  const raw = Uint8Array.from(atob(env.HEALTH_ENCRYPTION_KEY), c => c.charCodeAt(0));
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

function toBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}
function fromBase64(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0));
}

export async function encryptField(env: Env, values: string[]): Promise<string> {
  if (!values || values.length === 0) return "";
  const key = await getKey(env);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plaintext = new TextEncoder().encode(JSON.stringify(values));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, plaintext)
  ); // Web Crypto appends the auth tag to the ciphertext automatically
  const combined = new Uint8Array(iv.length + ciphertext.length);
  combined.set(iv, 0);
  combined.set(ciphertext, iv.length);
  return toBase64(combined);
}

export async function decryptField(env: Env, stored: unknown): Promise<string[]> {
  if (stored == null) return [];
  if (Array.isArray(stored)) return stored.map(String); // legacy plaintext arrays
  if (typeof stored !== "string" || stored.length === 0) return [];

  const key = await getKey(env);
  const combined = fromBase64(stored);
  const iv = combined.slice(0, 12);
  const ciphertext = combined.slice(12);
  const plaintext = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, ciphertext);
  return JSON.parse(new TextDecoder().decode(plaintext));
}