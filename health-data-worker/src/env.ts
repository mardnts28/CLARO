// src/env.ts — shared type for this Worker's secrets/bindings. Import
// this everywhere `env` is used instead of redefining it per-file, so
// index.ts, firestore.ts, and verifyToken.ts all agree on its shape.

export interface Env {
  HEALTH_ENCRYPTION_KEY: string;
  GCP_CLIENT_EMAIL: string;
  GCP_PRIVATE_KEY: string;
  FIREBASE_PROJECT_ID: string;
}