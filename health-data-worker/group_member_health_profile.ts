// health-data-worker/group_member_health_profile.ts
//
// Phase 6 — new endpoint for the Cloudflare Worker referenced throughout
// the Flutter app (const _workerUrl = 'https://health-data-worker.claro-app.workers.dev').
// That Worker's source isn't part of the provided Flutter project, so this
// file is written as a drop-in module for it, following the same shape as
// its existing `/health-profile` endpoint (Bearer-token auth, server-side
// AES encryption before writing to Firestore, decryption only ever
// happening here -- never on-device).
//
// THIS IS THE ONE PIECE OF THE WHOLE FEATURE WHERE A MISTAKE EXPOSES REAL
// HEALTH DATA. The entire security boundary for "Option B" (owner manages
// a member with no account) is the authorization check in
// `assertOwnerCanManage()` below. Get this reviewed before shipping.
//
// Routes added:
//   POST /group-member-health-profile   { groupId, memberId, conditions, allergens }
//   GET  /group-member-health-profile?groupId=...&memberId=...

import { getFirestore } from 'firebase-admin/firestore'; // same Admin SDK the existing /health-profile handler presumably already uses
import { getAuth } from 'firebase-admin/auth';
import { encryptHealthFields, decryptHealthFields } from './crypto'; // reuse whatever the existing /health-profile handler uses for users/{uid}.conditions/allergens -- do not introduce a second encryption scheme

interface GroupMemberHealthRequest {
  groupId: string;
  memberId: string;
  conditions?: string[];
  allergens?: string[];
}

/**
 * Verifies the request's bearer token belongs to the group's owner, and
 * that the target member is actually a "managed" (no-account) member --
 * never a "linked" member, whose data must only ever be written by their
 * own token via the existing /health-profile endpoint. This second check
 * matters: without it, an owner could otherwise overwrite a *linked*
 * member's real account data through this endpoint, which would silently
 * break that member's own control over their own profile.
 */
async function assertOwnerCanManage(
  idToken: string,
  groupId: string,
  memberId: string
): Promise<{ ok: true } | { ok: false; status: number; message: string }> {
  let decoded;
  try {
    decoded = await getAuth().verifyIdToken(idToken);
  } catch {
    return { ok: false, status: 401, message: 'Invalid or expired token.' };
  }

  const db = getFirestore();
  const groupSnap = await db.collection('groups').doc(groupId).get();
  if (!groupSnap.exists) {
    return { ok: false, status: 404, message: 'Group not found.' };
  }
  if (groupSnap.data()?.ownerUid !== decoded.uid) {
    // Deliberately the same generic message whether the group doesn't
    // exist or the caller isn't the owner -- don't leak which one it was.
    return { ok: false, status: 403, message: 'Not authorized for this group.' };
  }

  const memberSnap = await db
    .collection('groups')
    .doc(groupId)
    .collection('members')
    .doc(memberId)
    .get();
  if (!memberSnap.exists) {
    return { ok: false, status: 404, message: 'Member not found.' };
  }
  if (memberSnap.data()?.sourceType !== 'managed') {
    return {
      ok: false,
      status: 403,
      message: 'This member manages their own health data and cannot be edited here.',
    };
  }

  return { ok: true };
}

export async function handleGroupMemberHealthProfilePost(request: Request): Promise<Response> {
  const authHeader = request.headers.get('Authorization') ?? '';
  const idToken = authHeader.replace(/^Bearer /, '');
  if (!idToken) {
    return new Response('Missing Authorization header', { status: 401 });
  }

  let body: GroupMemberHealthRequest;
  try {
    body = await request.json();
  } catch {
    return new Response('Invalid JSON body', { status: 400 });
  }
  const { groupId, memberId, conditions = [], allergens = [] } = body;
  if (!groupId || !memberId) {
    return new Response('groupId and memberId are required', { status: 400 });
  }

  const authCheck = await assertOwnerCanManage(idToken, groupId, memberId);
  if (!authCheck.ok) {
    return new Response(authCheck.message, { status: authCheck.status });
  }

  // Same server-side encryption path as the existing /health-profile
  // POST handler for users/{uid}.conditions/allergens -- the key never
  // reaches the client either way.
  const { conditionsEncrypted, allergensEncrypted } = await encryptHealthFields({
    conditions,
    allergens,
  });

  const db = getFirestore();
  await db
    .collection('groups')
    .doc(groupId)
    .collection('members')
    .doc(memberId)
    .set(
      {
        conditionsEncrypted,
        allergensEncrypted,
        updatedAt: new Date(),
      },
      { merge: true }
    );

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

export async function handleGroupMemberHealthProfileGet(request: Request): Promise<Response> {
  const authHeader = request.headers.get('Authorization') ?? '';
  const idToken = authHeader.replace(/^Bearer /, '');
  if (!idToken) {
    return new Response('Missing Authorization header', { status: 401 });
  }

  const url = new URL(request.url);
  const groupId = url.searchParams.get('groupId');
  const memberId = url.searchParams.get('memberId');
  if (!groupId || !memberId) {
    return new Response('groupId and memberId are required', { status: 400 });
  }

  const authCheck = await assertOwnerCanManage(idToken, groupId, memberId);
  if (!authCheck.ok) {
    return new Response(authCheck.message, { status: authCheck.status });
  }

  const db = getFirestore();
  const memberSnap = await db
    .collection('groups')
    .doc(groupId)
    .collection('members')
    .doc(memberId)
    .get();

  const data = memberSnap.data() ?? {};
  const { conditions, allergens } = await decryptHealthFields({
    conditionsEncrypted: data.conditionsEncrypted,
    allergensEncrypted: data.allergensEncrypted,
  });

  return new Response(JSON.stringify({ conditions, allergens }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

// Wire these into the Worker's existing router alongside the current
// `/health-profile` GET/POST handlers, e.g.:
//
//   if (url.pathname === '/group-member-health-profile') {
//     return request.method === 'POST'
//       ? handleGroupMemberHealthProfilePost(request)
//       : handleGroupMemberHealthProfileGet(request);
//   }
