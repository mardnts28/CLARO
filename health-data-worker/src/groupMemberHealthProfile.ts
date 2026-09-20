// src/groupMemberHealthProfile.ts
//
// CORRECTED Phase 6. Unlike the first draft, this uses your actual
// verifyToken.ts / firestore.ts / crypto.ts -- no firebase-admin (which
// doesn't run in the Workers runtime), no combined
// encryptHealthFields/decryptHealthFields (your crypto.ts encrypts one
// field at a time, matching how /health-profile already calls it).
//
// index.ts already verifies the caller's token and extracts `uid` before
// routing (see the patch to index.ts below) -- these handlers take that
// already-verified `uid` as a parameter instead of re-verifying the
// token themselves, matching the existing /health-profile handlers'
// shape exactly.
//
// THIS IS THE ONE PIECE OF THE WHOLE FEATURE WHERE A MISTAKE EXPOSES
// REAL HEALTH DATA. The entire security boundary for "Option B" (owner
// manages a member with no account) is the check in
// `assertOwnerCanManageMember()` below. Get this reviewed before
// shipping -- specifically: it must reject both (a) a caller who isn't
// the group's ownerUid, and (b) an attempt to write a "linked" member's
// doc (that data belongs only to that member's own token, via the
// existing /health-profile endpoint).

import { Env } from "./env";
import { encryptField, decryptField } from "./crypto";
import { getGroupDoc, getGroupMemberDoc, getUserDoc, patchGroupMemberHealthDoc } from "./firestore";

type AuthResult = { ok: true } | { ok: false; status: number; message: string };

async function assertOwnerCanManageMember(
  env: Env,
  callerUid: string,
  groupId: string,
  memberId: string
): Promise<AuthResult> {
  const group = await getGroupDoc(env, groupId);
  if (!group) {
    return { ok: false, status: 404, message: "Group not found." };
  }
  if (group.ownerUid !== callerUid) {
    // Same generic message whether the group doesn't exist or the caller
    // isn't the owner -- don't leak which one it was.
    return { ok: false, status: 403, message: "Not authorized for this group." };
  }

  const member = await getGroupMemberDoc(env, groupId, memberId);
  if (!member) {
    return { ok: false, status: 404, message: "Member not found." };
  }
  if (member.sourceType !== "managed") {
    return {
      ok: false,
      status: 403,
      message: "This member manages their own health data and cannot be edited here.",
    };
  }

  return { ok: true };
}

// READ access: the group owner OR any active member of the group may read
// any active member's health profile (members consent to this when they
// join; the owner is a member too). Writes never go through this check --
// they stay owner-only for managed members (assertOwnerCanManageMember).
async function assertCanReadMember(
  env: Env,
  callerUid: string,
  groupId: string,
  memberId: string
): Promise<AuthResult> {
  const group = await getGroupDoc(env, groupId);
  if (!group) {
    return { ok: false, status: 404, message: "Group not found." };
  }
  if (group.ownerUid !== callerUid) {
    const caller = await getGroupMemberDoc(env, groupId, callerUid);
    if (!caller || caller.status !== "active") {
      return { ok: false, status: 403, message: "Not authorized for this group." };
    }
  }
  const member = await getGroupMemberDoc(env, groupId, memberId);
  if (!member || member.status !== "active") {
    return { ok: false, status: 404, message: "Member not found." };
  }
  return { ok: true };
}

export async function handleGroupMemberHealthProfilePost(
  env: Env,
  uid: string,
  request: Request
): Promise<Response> {
  try {
    return await postImpl(env, uid, request);
  } catch (e) {
    console.error("group-member-health-profile POST failed:", e);
    return new Response(`Server error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
}

async function postImpl(env: Env, uid: string, request: Request): Promise<Response> {
  const body = await request.json<{
    groupId?: string;
    memberId?: string;
    conditions?: string[];
    allergens?: string[];
  }>();

  const { groupId, memberId, conditions = [], allergens = [] } = body;
  if (!groupId || !memberId) {
    return new Response("groupId and memberId are required", { status: 400 });
  }

  const authCheck = await assertOwnerCanManageMember(env, uid, groupId, memberId);
  if (!authCheck.ok) {
    return new Response(authCheck.message, { status: authCheck.status });
  }

  // Same per-field encryption used by the existing /health-profile POST
  // handler for users/{uid}.conditions/allergens -- one encryptField()
  // call per field, same as index.ts already does.
  const conditionsEncrypted = await encryptField(env, conditions);
  const allergensEncrypted = await encryptField(env, allergens);

  await patchGroupMemberHealthDoc(env, groupId, memberId, {
    conditionsEncrypted,
    allergensEncrypted,
  });

  return Response.json({ success: true });
}

export async function handleGroupMemberHealthProfileGet(
  env: Env,
  uid: string,
  url: URL
): Promise<Response> {
  try {
    return await getImpl(env, uid, url);
  } catch (e) {
    console.error("group-member-health-profile GET failed:", e);
    return new Response(`Server error: ${e instanceof Error ? e.message : String(e)}`, { status: 500 });
  }
}

async function getImpl(env: Env, uid: string, url: URL): Promise<Response> {
  const groupId = url.searchParams.get("groupId");
  const memberId = url.searchParams.get("memberId");
  if (!groupId || !memberId) {
    return new Response("groupId and memberId are required", { status: 400 });
  }

  const authCheck = await assertCanReadMember(env, uid, groupId, memberId);
  if (!authCheck.ok) {
    return new Response(authCheck.message, { status: authCheck.status });
  }

  const member = await getGroupMemberDoc(env, groupId, memberId);

  // Linked member: their health data lives on users/{linkedUid}, encrypted
  // the same way /health-profile stores it. Owner-only read, checked above.
  if (member?.sourceType === "linked" && member.linkedUid) {
    const userDoc = await getUserDoc(env, member.linkedUid);
    return Response.json({
      conditions: await decryptField(env, userDoc.conditions),
      allergens: await decryptField(env, userDoc.allergens),
    });
  }

  return Response.json({
    conditions: await decryptField(env, member?.conditionsEncrypted),
    allergens: await decryptField(env, member?.allergensEncrypted),
  });
}