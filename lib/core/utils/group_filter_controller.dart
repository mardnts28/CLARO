// lib/core/utils/group_filter_controller.dart
//
// Shared group-filter state for CompareProductsScreen and
// MultiScanResultsScreen, so both screens load, combine and toggle the
// group's health profiles identically.
//
// Ranking itself is untouched: this only decides WHICH UserHealthProfile is
// handed to the existing ranking pipeline.
//
//  - enabled == false (or nobody selected) -> the current user's OWN profile
//  - otherwise -> union (deduplicated) of the selected members' conditions
//    and allergies. The current user's own entry always uses their own saved
//    profile.

import 'package:flutter/foundation.dart';

import '../../data/models/health_group.dart';
import '../../data/models/health_profile.dart';
import '../../data/repositories/group_repository.dart'
    show GroupMemberProfile;
import '../../data/services/backend_locator.dart';

class GroupFilterController {
  GroupFilterController._({
    required this.group,
    required this.members,
    required this.selfMemberId,
    required UserHealthProfile ownProfile,
  }) : _ownProfile = ownProfile,
       selectedIds = {for (final m in members) m.member.id};

  final HealthGroup group;

  /// Every active member, current user first.
  final List<GroupMemberProfile> members;
  final String selfMemberId;
  final UserHealthProfile _ownProfile;

  /// Master switch (the checkbox on the filter button).
  bool enabled = true;

  /// Member ids whose conditions/allergies are applied.
  Set<String> selectedIds;

  bool isSelf(GroupMemberProfile e) => e.member.id == selfMemberId;

  /// True only when the group filter actually affects ranking.
  bool get isActive => enabled && selectedIds.isNotEmpty;

  bool get allSelected => selectedIds.length == members.length;

  void update({required bool enabled, required Set<String> selectedIds}) {
    this.enabled = enabled && selectedIds.isNotEmpty;
    this.selectedIds = Set<String>.from(selectedIds);
  }

  /// Profile for ranking while the group filter is active: union of the
  /// selected members' conditions and allergies (Set -> no duplicates).
  UserHealthProfile get combinedProfile {
    final selected = members.where((m) => selectedIds.contains(m.member.id));
    final conditions = <HealthCondition>{};
    final allergies = <AllergenType>{};
    for (final m in selected) {
      conditions.addAll(m.profile.conditions);
      allergies.addAll(m.profile.allergies);
    }
    return UserHealthProfile(
      userId: _ownProfile.userId,
      displayName: _ownProfile.displayName,
      conditions: conditions.toList(),
      allergies: allergies.toList(),
      voiceAssistant: _ownProfile.voiceAssistant,
    );
  }

  /// Loads the user's active group. Returns null for solo users (no group,
  /// or no OTHER member whose profile could be read) or on any failure, in
  /// which case the screen behaves exactly as it does without groups.
  static Future<GroupFilterController?> load({
    required String uid,
    required UserHealthProfile ownProfile,
  }) async {
    try {
      final repo = BackendLocator.groupRepository;
      final group = await repo.getActiveGroup(uid);
      if (group == null) return null;

      final entries = await repo.getGroupMemberProfiles(group.id);
      bool isSelfEntry(GroupMemberProfile e) =>
          e.member.isLinked && e.member.linkedUid == uid;

      final others = entries.where((e) => !isSelfEntry(e)).toList();
      if (others.isEmpty) return null;

      // Current user's own profile is always used for their own entry (their
      // member record can be missing on older groups).
      final selfMember =
          entries.where(isSelfEntry).map((e) => e.member).firstOrNull ??
          GroupMember(
            id: uid,
            groupId: group.id,
            sourceType: GroupMemberSourceType.linked,
            status: GroupMemberStatus.active,
            addedAt: DateTime.now(),
            linkedUid: uid,
            displayName: ownProfile.displayName,
          );

      return GroupFilterController._(
        group: group,
        selfMemberId: selfMember.id,
        ownProfile: ownProfile,
        members: [
          GroupMemberProfile(member: selfMember, profile: ownProfile),
          ...others,
        ],
      );
    } catch (e) {
      debugPrint('Group filter skipped: $e');
      return null;
    }
  }
}
