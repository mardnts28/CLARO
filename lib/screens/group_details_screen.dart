// lib/screens/group_details_screen.dart
//
// NEW (Health Group UI & Navigation Update). Opened by tapping a group
// card on GroupScreen. Shows:
//   - the group name
//   - the member list
//   - each member's health profile
//   - a Delete Group button, disabled while the group has any active
//     member (invited members must leave, managed members must be
//     removed, before the owner can delete the group)
//
// Permission model (per the ticket): the primary user (owner) can VIEW
// and MANAGE (edit/remove) a "managed" member's health profile, since
// the owner entered that data in the first place. For a "linked"
// (invited) member, the owner can only VIEW their profile -- that
// member's own account owns their health data, same as it does for a
// solo user, and only they can edit it. A non-owner viewer (a linked
// member looking at a group they belong to but don't own) gets a
// read-only view of everything here: no add/edit/remove/delete actions.

import 'package:flutter/material.dart';

import '../data/models/health_group.dart';
import '../data/models/health_profile.dart';
import '../data/services/backend_locator.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../core/utils/success_feedback_utils.dart';
import '../generated/l10n/app_localizations.dart';
import 'invite_member_screen.dart';
import 'add_managed_member_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final HealthGroup group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final _authService = AuthService();
  final _groupRepository = BackendLocator.groupRepository;

  late HealthGroup _group;
  bool _isOwner = false;
  bool _deleting = false;

  // Cached so the profile fetch is NOT restarted by every rebuild. It used to
  // be created inline in build(), so each members-stream emission / setState
  // threw away the in-flight fetch and reset every card to "no health
  // profile yet".
  Future<List<UserHealthProfile>>? _profilesFuture;
  String? _memberSignature; // null until the first members snapshot arrives

  void _refreshProfiles() {
    _profilesFuture = _groupRepository.getGroupHealthProfiles(_group.id);
  }

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    final uid = _authService.currentUser?.uid;
    _isOwner = uid != null && uid == _group.ownerUid;
    // The owner is a member of their own group; make sure their member
    // record exists (also backfills groups created before this change).
    // The members stream picks it up automatically once written.
    if (_isOwner) {
      _groupRepository.ensureOwnerMember(_group).catchError((e) {
        debugPrint('ensureOwnerMember failed: $e');
      });
    }
  }

  void _showAddMemberChooser() {
    final loc = AppLocalizations.of(context)!;
    HapticService().vibrate();
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(loc.addMemberChooserTitle),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InviteMemberScreen(group: _group)),
              );
            },
            child: ListTile(
              leading: const Icon(Icons.qr_code_2_outlined),
              title: Text(loc.inviteSomeoneTitle),
              subtitle: Text(loc.inviteSomeoneSubtitle),
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddManagedMemberScreen(group: _group)),
              );
              if (mounted) setState(_refreshProfiles); // re-fetch profiles for the new member
            },
            child: ListTile(
              leading: const Icon(Icons.person_add_alt_outlined),
              title: Text(loc.addManuallyTitle),
              subtitle: Text(loc.addManuallySubtitle),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(GroupMember member) async {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    HapticService().vibrate();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(member.isLinked ? loc.removeFromGroupTitle : loc.deleteMemberTitle),
        content: Text(member.isLinked ? loc.removeFromGroupMessage : loc.deleteMemberMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.removeButton, style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HapticService().vibrate();
      await _groupRepository.removeMember(groupId: _group.id, memberId: member.id);
      if (mounted) setState(_refreshProfiles);
    }
  }

  Future<void> _leaveGroup() async {
    final colorScheme = Theme.of(context).colorScheme;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final loc = AppLocalizations.of(context)!;

    HapticService().vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tl ? 'Umalis sa grupo?' : 'Leave group?'),
        content: Text(tl
            ? 'Hindi mo na makikita ang grupong ito at ang mga miyembro nito. Maaari kang sumali muli gamit ang bagong imbitasyon.'
            : "You won't be able to see this group or its members anymore. You can rejoin later with a new invitation."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tl ? 'Umalis' : 'Leave', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticService().vibrate();
    setState(() => _deleting = true);
    try {
      await _groupRepository.leaveGroup(groupId: _group.id, uid: uid);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteGroup() async {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    HapticService().vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.deleteGroupConfirmTitle),
        content: Text(loc.deleteGroupConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.deleteGroupButton, style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticService().vibrate();
    setState(() => _deleting = true);
    try {
      await _groupRepository.deleteGroup(groupId: _group.id, requestingUid: uid);
      if (!mounted) return;
      SuccessFeedbackUtils.showSuccessSnackBar(context, loc.deleteGroupSuccess);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _conditionLabel(HealthCondition c, AppLocalizations loc) {
    switch (c) {
      case HealthCondition.diabetes:
        return loc.conditionDiabetes;
      case HealthCondition.hypertension:
        return loc.conditionHypertension;
      case HealthCondition.heartCondition:
        return loc.conditionHeartCondition;
    }
  }

  String _allergenLabel(AllergenType a, AppLocalizations loc) {
    switch (a) {
      case AllergenType.fish:
        return loc.allergenFish;
      case AllergenType.dairy:
        return loc.allergenMilk;
      case AllergenType.eggs:
        return loc.allergenEggs;
      case AllergenType.soy:
        return loc.allergenSoy;
      case AllergenType.wheatGluten:
        return loc.allergenWheat;
      case AllergenType.shellfish:
        return loc.allergenShellfish;
      case AllergenType.peanuts:
        return loc.allergenPeanuts;
      // treeNuts/msg have no dedicated loc entry (they aren't offered as
      // options on the onboarding/add-member grid) -- fall back to the
      // model's own English label rather than leaving them unlabeled.
      case AllergenType.treeNuts:
      case AllergenType.msg:
        return a.displayLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(_group.name)),
      body: SafeArea(
        child: StreamBuilder<List<GroupMember>>(
          stream: _groupRepository.watchMembers(_group.id),
          builder: (context, memberSnap) {
            final members = memberSnap.data ?? const <GroupMember>[];
            final membersLoading = !memberSnap.hasData && !memberSnap.hasError;
            final membersError = memberSnap.hasError;

            // Re-fetch profiles only when the SET of active members changes
            // (e.g. a QR-invited member joins), not on every rebuild.
            final signature = (members.map((m) => '${m.id}:${m.linkedUid}').toList()..sort()).join('|');
            if (!membersLoading && !membersError && signature != _memberSignature) {
              _memberSignature = signature;
              _profilesFuture = _groupRepository.getGroupHealthProfiles(_group.id);
            }

            return FutureBuilder<List<UserHealthProfile>>(
              future: _profilesFuture,
              builder: (context, profileSnap) {
                final profiles = profileSnap.data ?? const <UserHealthProfile>[];
                final profileByKey = <String, UserHealthProfile>{
                  for (final p in profiles) p.userId: p,
                };

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeaderCard(colorScheme, loc),
                          const SizedBox(height: 20),
                          Text(
                            loc.groupDetailsMembers,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 8),
                          if (membersLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (membersError)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                // A non-owner losing read access (e.g. the owner
                                // removed them) surfaces here as a stream error.
                                _isOwner
                                    ? loc.somethingWentWrong
                                    : (Localizations.localeOf(context).languageCode == 'tl'
                                        ? 'Hindi ka na miyembro ng grupong ito.'
                                        : "You're no longer a member of this group."),
                                style: TextStyle(color: colorScheme.error),
                              ),
                            )
                          else if (members.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                loc.groupDetailsNoMembers,
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            )
                          else
                            // Owner's card first, then everyone else in the
                            // order they were added.
                            ...(([...members]..sort((a, b) {
                              final ao = a.linkedUid == _group.ownerUid ? 0 : 1;
                              final bo = b.linkedUid == _group.ownerUid ? 0 : 1;
                              if (ao != bo) return ao.compareTo(bo);
                              return a.addedAt.compareTo(b.addedAt);
                            })))
                                .map((m) => _buildMemberCard(theme, colorScheme, loc, m, profileByKey)),
                          if (_isOwner) ...[
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showAddMemberChooser,
                                icon: const Icon(Icons.person_add_alt_1_outlined),
                                label: Text(loc.addMemberButton),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                  side: BorderSide(color: colorScheme.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isOwner)
                      _buildDeleteGroupSection(colorScheme, loc, members)
                    else
                      _buildLeaveGroupSection(colorScheme, loc),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _group.name,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            _isOwner ? loc.groupOwnerLabel : loc.groupMemberLabel,
            style: TextStyle(fontSize: 13, color: colorScheme.onPrimaryContainer.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations loc,
    GroupMember member,
    Map<String, UserHealthProfile> profileByKey,
  ) {
    // Managed members are keyed by member.id in getGroupHealthProfiles()
    // (see GroupRepository._fetchManagedMemberProfile), linked members by
    // their own uid.
    final profileKey = member.isLinked ? member.linkedUid : member.id;
    final profile = profileKey != null ? profileByKey[profileKey] : null;

    // Owner can VIEW + MANAGE (edit/remove) a "managed" member's health
    // profile -- the owner entered it. Owner can only VIEW a "linked"
    // member's profile; that member's own account owns their data.
    final isOwnerMember = member.linkedUid != null && member.linkedUid == _group.ownerUid;
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final canManageHealthProfile = _isOwner && member.isManaged;
    // The owner's own card can't be removed (delete the group instead).
    final canRemove = _isOwner && !isOwnerMember;
    final statusLabel = isOwnerMember
        ? (tl ? 'May-ari' : 'Owner')
        : (member.isLinked ? loc.memberStatusLinked : loc.memberStatusManaged);
    // Both member kinds now carry a display name (linked members choose
    // theirs in the Join Group modal); older linked members without one
    // fall back to the generic label.
    final hasName = member.displayName != null && member.displayName!.trim().isNotEmpty;
    final name = hasName
        ? member.displayName!
        : (isOwnerMember
            ? (tl ? 'May-ari' : 'Owner')
            : (member.isManaged ? loc.memberStatusManaged : loc.groupMemberLabel));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Leading image is the member's chosen avatar; members with
                // no avatar (e.g. linked members) keep the original icon.
                if (member.avatar != null)
                  ClipOval(
                    child: Image.asset(
                      member.avatar!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_pin_circle_outlined,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                    ),
                  )
                else
                  Icon(
                    member.isLinked ? Icons.person_outline : Icons.person_pin_circle_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 15, color: colorScheme.onSurface)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.secondary),
                  ),
                ),
                if (canManageHealthProfile)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.outline, size: 20),
                    tooltip: loc.editHealthProfile,
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddManagedMemberScreen(group: _group, existingMember: member),
                        ),
                      );
                      if (mounted) setState(_refreshProfiles);
                    },
                  ),
                if (canRemove)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: colorScheme.outline, size: 20),
                    tooltip: member.isLinked ? loc.removeFromGroupTooltip : loc.deleteMemberTooltip,
                    onPressed: () => _confirmRemove(member),
                  ),
              ],
            ),
          ),
          Divider(height: 0, color: colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildHealthProfileSummary(colorScheme, loc, member, profile),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthProfileSummary(
    ColorScheme colorScheme,
    AppLocalizations loc,
    GroupMember member,
    UserHealthProfile? profile,
  ) {
    if (profile == null || (profile.conditions.isEmpty && profile.allergies.isEmpty)) {
      return Text(loc.noHealthProfileYet, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant));
    }

    final conditionLabels = profile.conditions.map((c) => _conditionLabel(c, loc)).join(', ');
    final allergenLabels = profile.allergies.map((a) => _allergenLabel(a, loc)).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conditionLabels.isNotEmpty)
          Text(
            '${loc.healthConditions}: $conditionLabels',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        if (allergenLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${loc.allergensLabel}: $allergenLabels',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
        // Only the "view-only" note is shown for linked members -- a
        // managed member's card instead gets the edit pencil icon above,
        // which already communicates that the owner can act on it.
        // Only for an INVITED member's card viewed by someone else. The
        // owner's own member record is also sourceType "linked" (it points
        // at their own account), and a member looking at their own card can
        // edit their own data -- neither should show this note.
        if (member.isLinked &&
            member.linkedUid != _group.ownerUid &&
            member.linkedUid != _authService.currentUser?.uid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              loc.viewOnlyHealthProfileNote,
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  // Invited (non-owner) members get a Leave Group button instead of Delete.
  Widget _buildLeaveGroupSection(ColorScheme colorScheme, AppLocalizations loc) {
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final isDarkMode = colorScheme.brightness == Brightness.dark;
    final color = isDarkMode ? Colors.red.shade400 : Colors.red.shade700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _deleting ? null : _leaveGroup,
          icon: _deleting
              ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(Icons.logout, color: color),
          label: Text(tl ? 'Umalis sa Grupo' : 'Leave Group'),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteGroupSection(ColorScheme colorScheme, AppLocalizations loc, List<GroupMember> members) {
    // Delete is available only when the owner is the sole remaining member.
    final hasMembers = members.any((m) => m.linkedUid != _group.ownerUid);
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    final isDarkMode = colorScheme.brightness == Brightness.dark;
    
    // Determine colors based on state and theme
    final buttonColor = hasMembers 
        ? colorScheme.onSurfaceVariant.withOpacity(0.5) // Disabled: gray
        : (isDarkMode ? Colors.red.shade400 : Colors.red.shade700); // Available: primary red or bright red in dark mode
    
    final iconColor = hasMembers 
        ? colorScheme.onSurfaceVariant.withOpacity(0.5) // Disabled: gray
        : (isDarkMode ? Colors.red.shade400 : Colors.red.shade700); // Available: same as button
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (hasMembers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tl
                    ? 'Alisin muna ang lahat ng iba pang miyembro bago mabura ang grupong ito.'
                    : 'Remove all other members before you can delete this group.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (!hasMembers && !_deleting) ? _deleteGroup : null,
              icon: _deleting
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: buttonColor),
                    )
                  : Icon(Icons.delete_outline, color: iconColor),
              label: Text(loc.deleteGroupButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: buttonColor,
                side: BorderSide(color: buttonColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}