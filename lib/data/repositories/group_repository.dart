// lib/data/repositories/group_repository.dart
//
// Phase 2 — Firestore-backed group repository, following the same
// interface-first pattern as UserRepository / HistoryRepository /
// FavoritesRepository: screens never talk to Firestore directly, they
// talk to this.
//
// getGroupHealthProfiles() is the important one for Phase 7: it returns
// every active member's health data as a plain List<UserHealthProfile> --
// "linked" members via the existing UserRepository.getHealthProfile() path
// (their own data, untouched), "managed" members via a new Worker read
// endpoint (Phase 6). Callers (ProductDetailScreen) don't need to know
// which is which; they just get a list and evaluate each one, exactly as
// WhoCalculator/ProductRankingService already support (see
// product_evaluation.dart -- no changes needed there).

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/health_group.dart';
import '../models/health_profile.dart';
import 'firestore_label_mappings.dart';
import 'user_repository.dart';

const _groupWorkerUrl = 'https://health-data-worker.claro-app.workers.dev';

abstract class GroupRepository {
  /// The current user's active group, or null if they aren't in one
  /// (as owner OR as a linked member). Reads users/{uid}.primaryGroupId
  /// first, then falls back to the first entry of memberOfGroupIds.
  ///
  /// This stays a *single* group on purpose -- it backs the product-scan
  /// evaluation flow (ProductDetailScreen), which evaluates against one
  /// group at a time. It's unrelated to the Group tab's list of groups
  /// (see getGroups() below), which supports a user owning/joining any
  /// number of groups.
  Future<HealthGroup?> getActiveGroup(String uid);

  /// Every group [uid] belongs to, whether as owner or as a linked
  /// member -- users can own and/or join multiple health groups. Used by
  /// the Group tab (GroupScreen) to render the full list of group cards.
  /// Ordered oldest-created first.
  Future<List<HealthGroup>> getGroups(String uid);

  Future<HealthGroup> createGroup({
    required String ownerUid,
    required String name,
    GroupType? groupType,
  });

  Stream<List<GroupMember>> watchMembers(String groupId);

  Future<GroupInvite> createInvite({required String groupId, required String ownerUid});

  /// Redeems [code] for [joiningUid], adding them as a "linked" member.
  /// Throws if the invite is missing/expired/already used.
  Future<void> redeemInvite({required String code, required String joiningUid});

  Future<void> revokeInvite({required String groupId, required String code});

  /// Adds a "managed" member with no health data yet -- the caller should
  /// follow up with saveManagedMemberHealthData() once the owner fills in
  /// the form (Phase 5).
  Future<GroupMember> addManagedMember({
    required String groupId,
    required String displayName,
    String? avatar,
  });

  /// Updates the avatar of an existing managed member (edit flow).
  Future<void> updateMemberAvatar({
    required String groupId,
    required String memberId,
    required String? avatar,
  });

  /// Phase 6: writes a managed member's conditions/allergens through the
  /// Worker's group-scoped endpoint (never directly to Firestore -- see
  /// firestore/group_rules_addition.rules, which rejects direct client
  /// writes to these two fields).
  Future<bool> saveManagedMemberHealthData({
    required String groupId,
    required String memberId,
    required List<String> conditions,
    required List<String> allergens,
  });

  /// Phase 8: member leaves (linked) or is removed (managed/linked, by
  /// the owner). Does NOT touch a linked member's own users/{uid} data.
  Future<void> removeMember({required String groupId, required String memberId});

  /// Fetches every ACTIVE member's health profile as a plain
  /// UserHealthProfile list, ready to hand to WhoCalculator/
  /// ProductRankingService exactly like today's single-profile call.
  Future<List<UserHealthProfile>> getGroupHealthProfiles(String groupId);

  /// Deletes [groupId]. Only the group's owner may call this
  /// ([requestingUid] must equal HealthGroup.ownerUid), and only once
  /// every member has left/been removed -- GroupDetailsScreen keeps its
  /// "Delete Group" button disabled while any active member remains, but
  /// this is enforced here too so the rule holds regardless of caller.
  /// Throws if the requester isn't the owner, or if active members remain.
  Future<void> deleteGroup({required String groupId, required String requestingUid});

  /// Phase 8: cleans up group membership when an account is deleted.
  /// If [uid] owns a group, dissolves it. If they're a linked member of
  /// any groups, marks those memberships "left". Called from
  /// AuthService.deleteAccount() -- see patches/auth_service_patch.md.
  Future<void> cleanupMembershipsForDeletedAccount(String uid);
}

class FirebaseGroupRepository implements GroupRepository {
  FirebaseGroupRepository({FirebaseFirestore? firestore, UserRepository? userRepository})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _userRepository = userRepository;

  final FirebaseFirestore _firestore;
  // Injected lazily via BackendLocator (see backend_locator.dart patch) to
  // avoid a circular static-init order issue between the two locators.
  final UserRepository? _userRepository;

  CollectionReference<Map<String, dynamic>> get _groups => _firestore.collection('groups');

  @override
  Future<HealthGroup?> getActiveGroup(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data();
    if (data == null) return null;

    final primaryGroupId = data['primaryGroupId'] as String?;
    if (primaryGroupId != null && primaryGroupId.isNotEmpty) {
      final doc = await _groups.doc(primaryGroupId).get();
      if (doc.exists) return HealthGroup.fromFirestore(doc.id, doc.data()!);
    }

    final memberOfGroupIds = List<String>.from(data['memberOfGroupIds'] as List? ?? []);
    if (memberOfGroupIds.isNotEmpty) {
      final doc = await _groups.doc(memberOfGroupIds.first).get();
      if (doc.exists) return HealthGroup.fromFirestore(doc.id, doc.data()!);
    }

    return null;
  }

  @override
  Future<List<HealthGroup>> getGroups(String uid) async {
    // Owned groups: direct query.
    final ownedSnap = await _groups.where('ownerUid', isEqualTo: uid).get();
    final owned = ownedSnap.docs
        .map((d) => HealthGroup.fromFirestore(d.id, d.data()))
        .toList();
    final ownedIds = owned.map((g) => g.id).toSet();

    // Joined groups: users/{uid}.memberOfGroupIds, populated by
    // redeemInvite(). Fetched individually rather than via a
    // whereIn/collectionGroup query to keep this working the same way
    // regardless of list length or Firestore Rules shape.
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final memberOfGroupIds =
        List<String>.from(userDoc.data()?['memberOfGroupIds'] as List? ?? []);

    final joined = <HealthGroup>[];
    for (final groupId in memberOfGroupIds) {
      if (ownedIds.contains(groupId)) continue; // shouldn't happen, but avoid dupes
      final doc = await _groups.doc(groupId).get();
      if (doc.exists) {
        joined.add(HealthGroup.fromFirestore(doc.id, doc.data()!));
      }
    }

    final all = [...owned, ...joined]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  @override
  Future<HealthGroup> createGroup({
    required String ownerUid,
    required String name,
    GroupType? groupType,
  }) async {
    final docRef = _groups.doc();
    final group = HealthGroup(
      id: docRef.id,
      ownerUid: ownerUid,
      name: name,
      createdAt: DateTime.now(),
      groupType: groupType,
    );
    await docRef.set(group.toFirestore());

    // Only claim this as the "active" group (used by the product-scan
    // evaluation flow -- see getActiveGroup()) if the user doesn't
    // already have one. Users can create/join further groups after that
    // purely to organize them in the Group tab, without changing which
    // group their scans get evaluated against.
    final userRef = _firestore.collection('users').doc(ownerUid);
    final userDoc = await userRef.get();
    final hasPrimary =
        (userDoc.data()?['primaryGroupId'] as String?)?.isNotEmpty ?? false;
    if (!hasPrimary) {
      await userRef.set({'primaryGroupId': docRef.id}, SetOptions(merge: true));
    }
    return group;
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _groups
        .doc(groupId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GroupMember.fromFirestore(d.id, groupId, d.data()))
            .toList());
  }

  @override
  Future<GroupInvite> createInvite({required String groupId, required String ownerUid}) async {
    final code = _generateInviteCode();
    final invite = GroupInvite(
      code: code,
      groupId: groupId,
      createdBy: ownerUid,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 48)),
      status: GroupInviteStatus.pending,
    );
    await _groups.doc(groupId).collection('invites').doc(code).set(invite.toFirestore());
    // Top-level lookup doc so a joiner who only has the code (and doesn't
    // know which group it belongs to) can resolve it in one read, instead
    // of a fragile collectionGroup query. Mirrors the invite's own
    // pending/expiresAt so redeemInvite() can validate from this doc
    // alone before touching the real invite record.
    await _firestore.collection('inviteCodes').doc(code).set({
      'groupId': groupId,
      'expiresAt': Timestamp.fromDate(invite.expiresAt),
    });
    return invite;
  }

  @override
  Future<void> redeemInvite({required String code, required String joiningUid}) async {
    final lookup = await _firestore.collection('inviteCodes').doc(code).get();
    if (!lookup.exists) {
      throw Exception('Invite code not found.');
    }
    final groupId = lookup.data()!['groupId'] as String;

    final doc = await _groups.doc(groupId).collection('invites').doc(code).get();
    if (!doc.exists) {
      throw Exception('Invite code not found.');
    }
    final invite = GroupInvite.fromFirestore(doc.id, groupId, doc.data()!);

    if (!invite.isUsable) {
      throw Exception('This invite code is expired or already used.');
    }

    // Linked members are keyed by their own uid (not an auto-generated
    // id) -- this lets Firestore Rules cheaply check "is this caller a
    // member of this group" with a single exists() lookup instead of a
    // query, which rules can't do. See the corrected groups/{groupId}
    // and groups/{groupId}/members/{memberId} read rules in
    // firestore/group_rules_addition.rules.
    final memberRef = _groups.doc(groupId).collection('members').doc(joiningUid);
    final member = GroupMember(
      id: memberRef.id,
      groupId: groupId,
      sourceType: GroupMemberSourceType.linked,
      status: GroupMemberStatus.active,
      addedAt: DateTime.now(),
      linkedUid: joiningUid,
    );

    final batch = _firestore.batch();
    // `inviteCode` lets the Firestore rule verify this write is backed by a
    // real, unexpired invite for THIS group (see the members `create` rule).
    batch.set(memberRef, {...member.toFirestore(), 'inviteCode': code});
    batch.update(doc.reference, {'status': 'redeemed', 'redeemedByUid': joiningUid});
    batch.delete(_firestore.collection('inviteCodes').doc(code));
    batch.set(
      _firestore.collection('users').doc(joiningUid),
      {
        'memberOfGroupIds': FieldValue.arrayUnion([groupId]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  @override
  Future<void> revokeInvite({required String groupId, required String code}) async {
    await _groups.doc(groupId).collection('invites').doc(code).update({'status': 'revoked'});
  }

  @override
  Future<GroupMember> addManagedMember({
    required String groupId,
    required String displayName,
    String? avatar,
  }) async {
    final memberRef = _groups.doc(groupId).collection('members').doc();
    final member = GroupMember(
      id: memberRef.id,
      groupId: groupId,
      sourceType: GroupMemberSourceType.managed,
      status: GroupMemberStatus.active,
      addedAt: DateTime.now(),
      displayName: displayName,
      avatar: avatar,
    );
    await memberRef.set(member.toFirestore());
    return member;
  }

  @override
  Future<void> updateMemberAvatar({
    required String groupId,
    required String memberId,
    required String? avatar,
  }) async {
    await _groups.doc(groupId).collection('members').doc(memberId).update({
      'avatar': avatar ?? FieldValue.delete(),
    });
  }

  @override
  Future<bool> saveManagedMemberHealthData({
    required String groupId,
    required String memberId,
    required List<String> conditions,
    required List<String> allergens,
  }) async {
    // Phase 6 endpoint. Authorization is entirely server-side: the Worker
    // checks that this token's uid == groups/{groupId}.ownerUid AND that
    // {memberId} is sourceType "managed" before writing anything -- see
    // health-data-worker/group_member_health_profile.md.
    // Tries once with the cached ID token and, if the Worker rejects it,
    // once more with a force-refreshed token (an expired/stale token is
    // the most common transient cause of a 401/403 here). Any 2xx counts
    // as success -- the Worker isn't required to answer with exactly 200.
    // Failures are logged with the Worker's status + body so the real
    // cause is visible in the debug console instead of a silent `false`.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final idToken = await user?.getIdToken(attempt > 0);
        if (idToken == null) {
          debugPrint('saveManagedMemberHealthData: no authenticated user / ID token');
          return false;
        }
        final res = await http.post(
          Uri.parse('$_groupWorkerUrl/group-member-health-profile'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'groupId': groupId,
            'memberId': memberId,
            'conditions': conditions,
            'allergens': allergens,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) return true;
        debugPrint(
            'saveManagedMemberHealthData failed (attempt ${attempt + 1}): ${res.statusCode} ${res.body}');
      } catch (e) {
        debugPrint('saveManagedMemberHealthData error (attempt ${attempt + 1}): $e');
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  @override
  Future<void> removeMember({required String groupId, required String memberId}) async {
    final memberRef = _groups.doc(groupId).collection('members').doc(memberId);
    final snap = await memberRef.get();
    if (!snap.exists) return;
    final member = GroupMember.fromFirestore(snap.id, groupId, snap.data()!);

    if (member.isLinked && member.linkedUid != null) {
      // Leave, don't delete: their own health data is untouched.
      await memberRef.update({'status': 'left'});
      await _firestore.collection('users').doc(member.linkedUid).update({
        'memberOfGroupIds': FieldValue.arrayRemove([groupId]),
      });
    } else {
      // Managed member: nothing else references this record, safe to delete.
      await memberRef.delete();
    }
  }

  @override
  Future<void> deleteGroup({required String groupId, required String requestingUid}) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return;

    final group = HealthGroup.fromFirestore(doc.id, doc.data()!);
    if (group.ownerUid != requestingUid) {
      throw Exception('Only the group owner can delete this group.');
    }

    // Same rule GroupDetailsScreen enforces on its Delete Group button
    // (disabled while any active member remains) -- checked again here
    // so it holds no matter what calls this.
    final activeMembers = await doc.reference
        .collection('members')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (activeMembers.docs.isNotEmpty) {
      throw Exception('Remove all members before deleting this group.');
    }

    final batch = _firestore.batch();

    final invites = await doc.reference.collection('invites').get();
    for (final i in invites.docs) {
      batch.delete(i.reference);
    }
    // Any leftover (left/removed) member records -- not "active", so not
    // caught by the check above, but still cleaned up here.
    final leftoverMembers = await doc.reference.collection('members').get();
    for (final m in leftoverMembers.docs) {
      batch.delete(m.reference);
    }
    batch.delete(doc.reference);
    await batch.commit();

    final ownerRef = _firestore.collection('users').doc(requestingUid);
    final ownerDoc = await ownerRef.get();
    if (ownerDoc.data()?['primaryGroupId'] == groupId) {
      await ownerRef.update({'primaryGroupId': FieldValue.delete()});
    }
  }

  @override
  Future<List<UserHealthProfile>> getGroupHealthProfiles(String groupId) async {
    final snap = await _groups
        .doc(groupId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .get();

    final profiles = <UserHealthProfile>[];
    for (final doc in snap.docs) {
      final member = GroupMember.fromFirestore(doc.id, groupId, doc.data());
      if (member.isLinked && member.linkedUid != null) {
        if (_userRepository == null) continue;
        try {
          final profile = await _userRepository.getHealthProfile(member.linkedUid!);
          profiles.add(profile);
        } catch (_) {
          // A linked member's profile may be unreadable (e.g. they left
          // between the membership list load and this fetch) -- skip
          // rather than fail the whole group evaluation.
          continue;
        }
      } else if (member.isManaged) {
        final profile = await _fetchManagedMemberProfile(groupId, member);
        if (profile != null) profiles.add(profile);
      }
    }
    return profiles;
  }

  Future<UserHealthProfile?> _fetchManagedMemberProfile(
    String groupId,
    GroupMember member,
  ) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return null;
      final res = await http.get(
        Uri.parse('$_groupWorkerUrl/group-member-health-profile?groupId=$groupId&memberId=${member.id}'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('_fetchManagedMemberProfile failed: ${res.statusCode} ${res.body}');
        return null;
      }
      final healthData = jsonDecode(res.body) as Map<String, dynamic>;
      // The Worker returns the display LABELS this screen saved (e.g.
      // "Heart condition", "Milk/Dairy"), not enum names, so they must go
      // through the label mappings -- UserHealthProfile.fromJson() only
      // understands enum names and silently dropped every value, which
      // is why the member card showed no health info.
      return UserHealthProfile(
        // member.id (not a Firebase uid) becomes this profile's identity
        // for fingerprinting/caching purposes -- see health_profile.dart's
        // profileFingerprint and gemini_advisory_service.dart's cache key,
        // both of which already key off `userId` generically, not
        // specifically a Firebase Auth uid.
        userId: member.id,
        displayName: member.displayName ?? 'Member',
        conditions: mapConditionLabels((healthData['conditions'] as List<dynamic>?) ?? const []),
        allergies: mapAllergenLabels((healthData['allergens'] as List<dynamic>?) ?? const []),
      );
    } catch (e) {
      debugPrint('_fetchManagedMemberProfile error: $e');
      return null;
    }
  }

  @override
  Future<void> cleanupMembershipsForDeletedAccount(String uid) async {
    // Case 1: uid owns a group -- dissolve it (simplest policy; see
    // guide Phase 8 for the alternative "transfer ownership" policy).
    final owned = await _groups.where('ownerUid', isEqualTo: uid).get();
    for (final doc in owned.docs) {
      final members = await doc.reference.collection('members').get();
      final batch = _firestore.batch();
      for (final m in members.docs) {
        batch.delete(m.reference);
      }
      final invites = await doc.reference.collection('invites').get();
      for (final i in invites.docs) {
        batch.delete(i.reference);
      }
      batch.delete(doc.reference);
      await batch.commit();
    }

    // Case 2: uid is a linked member elsewhere -- mark those memberships left.
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final memberOfGroupIds =
        List<String>.from(userDoc.data()?['memberOfGroupIds'] as List? ?? []);
    for (final groupId in memberOfGroupIds) {
      final matches = await _groups
          .doc(groupId)
          .collection('members')
          .where('linkedUid', isEqualTo: uid)
          .get();
      for (final m in matches.docs) {
        await m.reference.update({'status': 'left'});
      }
    }
  }

  // 9 characters, all caps letters + digits -- matches the format
  // JoinGroupDialog validates on entry (see widgets/join_group_dialog.dart).
  // Ambiguous characters (0/O/1/I) are excluded so a code read off a
  // screen or spoken aloud is never misheard/mistyped, but that's purely
  // a generation-time choice -- the validator itself accepts any
  // A-Z/0-9 character in that 9-character shape, since a code could in
  // principle arrive from elsewhere.
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I ambiguity
    final rand = Random.secure();
    return List.generate(9, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}