// lib/data/models/health_group.dart
//
// Phase 1 — data models for the multi-member health group feature.
//
// A group has exactly one owner (the primary user) and any number of
// members. Each member is either:
//   - "linked"  : has their own Firebase Auth account and manages their
//                 own health data exactly the way a solo user does today
//                 (see health_profile.dart / user_repository.dart). The
//                 group only stores a reference to their uid -- their
//                 conditions/allergens NEVER live here.
//   - "managed" : has no account. The group owner entered their info, and
//                 their encrypted health data lives on this member
//                 document, written only through the Worker endpoint added
//                 in Phase 6 (never directly from the client).
//
// Mirrors the fromJson/toJson pattern already used by UserHealthProfile
// in health_profile.dart so the rest of the codebase stays consistent.

import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupMemberSourceType { linked, managed }

enum GroupMemberStatus { invited, active, left }

enum GroupInviteStatus { pending, redeemed, revoked, expired }

enum GroupType { family, friends, lovers, others }

/// Parses the string stored in Firestore back into a [GroupType]. Returns
/// null when absent or unrecognised (groups created before group types
/// existed).
GroupType? groupTypeFromString(String? raw) {
  for (final t in GroupType.values) {
    if (t.name == raw) return t;
  }
  return null;
}

class HealthGroup {
  final String id;
  final String ownerUid;
  final String name;
  final DateTime createdAt;
  // Owner-controlled display ordering of member ids. Any member not
  // present here (e.g. just added) is appended at render time -- this
  // list is a display hint, not a source of truth for membership.
  final List<String> memberOrder;
  // Family / Friends / Lovers / Others. Null for older groups.
  final GroupType? groupType;

  const HealthGroup({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.createdAt,
    this.memberOrder = const [],
    this.groupType,
  });

  factory HealthGroup.fromFirestore(String id, Map<String, dynamic> data) {
    return HealthGroup(
      id: id,
      ownerUid: data['ownerUid']?.toString() ?? '',
      name: data['name']?.toString() ?? 'My Health Group',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberOrder: (data['memberOrder'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      groupType: groupTypeFromString(data['groupType']?.toString()),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerUid': ownerUid,
        'name': name,
        if (groupType != null) 'groupType': groupType!.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'memberOrder': memberOrder,
      };
}

class GroupMember {
  final String id; // memberId (Firestore doc id under groups/{groupId}/members)
  final String groupId;
  final GroupMemberSourceType sourceType;
  final GroupMemberStatus status;
  final DateTime addedAt;
  final DateTime? updatedAt;

  // "linked" members only:
  final String? linkedUid;

  // "managed" members only:
  final String? displayName;
  
  // Asset path of the avatar chosen for this member (managed members),
  // e.g. 'assets/images/avatars/female_1.png'. Null if none was chosen.
  final String? avatar;

  // Encrypted blobs written ONLY by the Cloudflare Worker (Phase 6) for
  // "managed" members. Never written directly by the client. Left null
  // for "linked" members -- their health data lives at users/{linkedUid}
  // and is fetched through UserRepository instead (see
  // GroupRepository.getGroupHealthProfiles in group_repository.dart).
  final String? conditionsEncrypted;
  final String? allergensEncrypted;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.sourceType,
    required this.status,
    required this.addedAt,
    this.updatedAt,
    this.linkedUid,
    this.displayName,
    this.avatar,
    this.conditionsEncrypted,
    this.allergensEncrypted,
  });

  bool get isLinked => sourceType == GroupMemberSourceType.linked;
  bool get isManaged => sourceType == GroupMemberSourceType.managed;

  factory GroupMember.fromFirestore(
    String id,
    String groupId,
    Map<String, dynamic> data,
  ) {
    return GroupMember(
      id: id,
      groupId: groupId,
      sourceType: (data['sourceType'] as String?) == 'managed'
          ? GroupMemberSourceType.managed
          : GroupMemberSourceType.linked,
      status: _statusFromString(data['status'] as String?),
      addedAt: _readDate(data['addedAt']) ?? DateTime.now(),
      updatedAt: _readDate(data['updatedAt']),
      linkedUid: data['linkedUid']?.toString(),
      displayName: data['displayName']?.toString(),
      avatar: data['avatar']?.toString(),
      conditionsEncrypted: data['conditionsEncrypted']?.toString(),
      allergensEncrypted: data['allergensEncrypted']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sourceType': sourceType.name,
        'status': status.name,
        'addedAt': Timestamp.fromDate(addedAt),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        if (linkedUid != null) 'linkedUid': linkedUid,
        if (displayName != null) 'displayName': displayName,
        if (avatar != null) 'avatar': avatar,
        // conditionsEncrypted/allergensEncrypted deliberately omitted here:
        // the client never writes these fields (see Phase 6 Worker + Phase
        // 1 Firestore Rules, which reject direct client writes to them --
        // same rule shape as users/{uid}.conditions/allergens today).
      };

  // The Worker used to write `updatedAt` as an ISO string rather than a
  // Firestore Timestamp; a hard `as Timestamp?` cast on such a document
  // throws and breaks the whole members stream. Accept both.
  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static GroupMemberStatus _statusFromString(String? raw) {
    switch (raw) {
      case 'active':
        return GroupMemberStatus.active;
      case 'left':
        return GroupMemberStatus.left;
      case 'invited':
      default:
        return GroupMemberStatus.invited;
    }
  }
}

class GroupInvite {
  final String code; // also the Firestore doc id
  final String groupId;
  final String createdBy; // ownerUid
  final DateTime createdAt;
  final DateTime expiresAt;
  final GroupInviteStatus status;
  final String? redeemedByUid;

  const GroupInvite({
    required this.code,
    required this.groupId,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.redeemedByUid,
  });

  bool get isUsable =>
      status == GroupInviteStatus.pending && DateTime.now().isBefore(expiresAt);

  factory GroupInvite.fromFirestore(
    String code,
    String groupId,
    Map<String, dynamic> data,
  ) {
    return GroupInvite(
      code: code,
      groupId: groupId,
      createdBy: data['createdBy']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 48)),
      status: _inviteStatusFromString(data['status'] as String?),
      redeemedByUid: data['redeemedByUid']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'status': status.name,
        if (redeemedByUid != null) 'redeemedByUid': redeemedByUid,
      };

  static GroupInviteStatus _inviteStatusFromString(String? raw) {
    switch (raw) {
      case 'redeemed':
        return GroupInviteStatus.redeemed;
      case 'revoked':
        return GroupInviteStatus.revoked;
      case 'expired':
        return GroupInviteStatus.expired;
      case 'pending':
      default:
        return GroupInviteStatus.pending;
    }
  }
}