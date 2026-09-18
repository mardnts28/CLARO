// lib/screens/group_screen.dart
//
// Phase 3 — entry point for the group feature. Reached from ProfileScreen
// (see patches/profile_screen_patch.md for the one-row addition that
// links here).
//
// Visual style is deliberately copy-pasted from existing screens rather
// than invented:
//   - Header/empty-state card: same shape as ProfileScreen._buildProfileCard()
//     (colorScheme.primaryContainer background, bold title, 80%-opacity subtitle).
//   - Member list card: same bordered/rounded Container as
//     PersonalInfoScreen._buildConditionsSection() (theme.cardColor,
//     BorderRadius.circular(16), Border.all(color: theme.dividerColor)).
//   - Member rows: same Icon + Expanded(Text) + trailing pattern as
//     ProfileScreen._buildMenuItemWithArrow(), plus a small status pill.
//   - "Add Member" chooser dialog: same SimpleDialog pattern as
//     ProfileScreen._showLanguageChooser().

import 'package:flutter/material.dart';

import '../data/models/health_group.dart';
import '../data/services/backend_locator.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import 'invite_member_screen.dart';
import 'add_managed_member_screen.dart';
// Note: JoinGroupScreen (Phase 4) is linked from ProfileScreen directly,
// not from here -- see patches/profile_screen_patch.md. A user who
// already owns/belongs to a group doesn't need a "join" entry point on
// this screen.

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _authService = AuthService();
  final _groupRepository = BackendLocator.groupRepository;

  bool _loading = true;
  HealthGroup? _group;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final group = await _groupRepository.getActiveGroup(uid);
    setState(() {
      _group = group;
      _isOwner = group != null && group.ownerUid == uid;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final nameController = TextEditingController(text: 'My Health Group');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name your group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'e.g. The Santos Household'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticService().vibrate();
    final group = await _groupRepository.createGroup(
      ownerUid: uid,
      name: nameController.text.trim().isEmpty ? 'My Health Group' : nameController.text.trim(),
    );
    setState(() {
      _group = group;
      _isOwner = true;
    });
  }

  void _showAddMemberChooser() {
    HapticService().vibrate();
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add a member'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InviteMemberScreen(group: _group!)),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.qr_code_2_outlined),
              title: Text('Invite someone'),
              subtitle: Text('They install the app and manage their own profile'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => AddManagedMemberScreen(group: _group!)),
              );
              if (added == true) _load();
            },
            child: const ListTile(
              leading: Icon(Icons.person_add_alt_outlined),
              title: Text('Add manually'),
              subtitle: Text('For someone without their own account'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_group == null) ..._buildEmptyState(colorScheme) else ..._buildGroupView(theme, colorScheme),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildEmptyState(ColorScheme colorScheme) {
    return [
      // Same visual shape as ProfileScreen._buildProfileCard().
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evaluate products for your whole household',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to see a health evaluation for each family member, '
              'friend, or co-living partner every time you scan a product.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _createGroup,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Create a Group'),
        ),
      ),
    ];
  }

  List<Widget> _buildGroupView(ThemeData theme, ColorScheme colorScheme) {
    final group = _group!;
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              _isOwner ? 'You own this group' : 'You are a member',
              style: TextStyle(fontSize: 13, color: colorScheme.onPrimaryContainer.withOpacity(0.8)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('Members', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
      const SizedBox(height: 8),
      StreamBuilder<List<GroupMember>>(
        stream: _groupRepository.watchMembers(group.id),
        builder: (context, snapshot) {
          final members = snapshot.data ?? [];
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (members.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No members yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            );
          }
          return Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  _buildMemberRow(theme, colorScheme, members[i]),
                  if (i != members.length - 1) Divider(height: 0, color: colorScheme.outlineVariant),
                ],
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 20),
      if (_isOwner)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showAddMemberChooser,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add Member'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
    ];
  }

  Widget _buildMemberRow(ThemeData theme, ColorScheme colorScheme, GroupMember member) {
    final label = member.isLinked ? 'Linked' : 'Managed';
    final name = member.isManaged ? (member.displayName ?? 'Member') : 'Group member';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            member.isLinked ? Icons.person_outline : Icons.person_pin_circle_outlined,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 15, color: colorScheme.onSurface)),
          ),
          // Small status pill -- reuses colorScheme.secondary the same
          // way advisory badges elsewhere in the app tint a pastel
          // background behind a colored label.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.secondary),
            ),
          ),
          if (_isOwner) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: colorScheme.outline, size: 20),
              onPressed: () => _confirmRemove(member),
              tooltip: member.isLinked ? 'Remove from group' : 'Delete member',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemove(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(member.isLinked ? 'Remove from group?' : 'Delete this member?'),
        content: Text(
          member.isLinked
              ? "This removes them from the group. Their own health data is not affected."
              : "This permanently deletes this member's entry and their health data.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _groupRepository.removeMember(groupId: _group!.id, memberId: member.id);
    }
  }
}
