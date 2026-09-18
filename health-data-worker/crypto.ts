// crypto.ts — Encryption utilities for group member health profiles
// This module provides the interface expected by group_member_health_profile.ts
// using Web Crypto API (available in Cloudflare Workers)

const ALGORITHM = 'AES-GCM';
const KEY_LENGTH = 32;
const IV_LENGTH = 12;

// In production, this should come from environment variables or Cloudflare secrets
// For now, using a placeholder that should be replaced with proper secret management
const ENCRYPTION_KEY_BASE64 = (typeof process !== 'undefined' && process.env?.HEALTH_ENCRYPTION_KEY) || 
  'base64-encoded-32-byte-key-replace-in-production';

async function getKey(): Promise<CryptoKey> {
  const rawKey = Uint8Array.from(atob(ENCRYPTION_KEY_BASE64), c => c.charCodeAt(0));
  return crypto.subtle.importKey('raw', rawKey, ALGORITHM, false, ['encrypt', 'decrypt']);
}

function toBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function fromBase64(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0));
}

async function encryptArray(values: string[]): Promise<string> {
  if (!values || values.length === 0) return '';
  
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
  const plaintext = new TextEncoder().encode(JSON.stringify(values));
  
  const ciphertext = await crypto.subtle.encrypt(
    { name: ALGORITHM, iv },
    key,
    plaintext
  );
  
  // Combine IV + ciphertext (Web Crypto appends auth tag automatically)
  const combined = new Uint8Array(iv.length + ciphertext.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(ciphertext), iv.length);
  
  return toBase64(combined);
}

async function decryptArray(encrypted: string): Promise<string[]> {
  if (!encrypted) return [];
  
  const key = await getKey();
  const combined = fromBase64(encrypted);
  
  const iv = combined.slice(0, IV_LENGTH);
  const ciphertext = combined.slice(IV_LENGTH);
  
  const plaintext = await crypto.subtle.decrypt(
    { name: ALGORITHM, iv },
    key,
    ciphertext
  );
  
  return JSON.parse(new TextDecoder().decode(plaintext));
}

export async function encryptHealthFields({
  conditions,
  allergens,
}: {
  conditions?: string[];
  allergens?: string[];
}): Promise<{
  conditionsEncrypted: string;
  allergensEncrypted: string;
}> {
  return {
    conditionsEncrypted: await encryptArray(conditions || []),
    allergensEncrypted: await encryptArray(allergens || []),
  };
}

export async function decryptHealthFields({
  conditionsEncrypted,
  allergensEncrypted,
}: {
  conditionsEncrypted?: unknown;
  allergensEncrypted?: unknown;
}): Promise<{
  conditions: string[];
  allergens: string[];
}> {
  return {
    conditions: await decryptArray(conditionsEncrypted as string),
    allergens: await decryptArray(allergensEncrypted as string),
  };
}
