// lib/screens/group_screen.dart
//
// UPDATED (Health Group UI & Navigation Update): this used to be a
// full-screen route pushed from ProfileScreen's "Health Group" menu row,
// and it assumed a single group (getActiveGroup()). It's now the content
// of its own bottom-nav "Group" tab (see home_screen.dart), and lists
// EVERY group the user belongs to -- owned or joined -- since users can
// now create/join multiple health groups.
//
// Layout: header, then a scrollable list of group cards (or a "No group
// yet" empty state), then a fixed Join/Create button row pinned to the
// bottom of this tab's content -- above HomeScreen's bottom navigation
// bar, since that bar lives outside this widget entirely.

import 'package:flutter/material.dart';

import '../core/utils/group_type_ui.dart';
import '../data/models/health_group.dart';
import '../data/services/backend_locator.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/join_group_dialog.dart';
import 'group_details_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _authService = AuthService();
  final _groupRepository = BackendLocator.groupRepository;

  bool _loading = true;
  bool _bulkDeleting = false;
  List<HealthGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
    // New/changed group screens support both English and Tagalog -- this
    // screen isn't tied to a Localizations rebuild the way route pushes
    // are, so it listens for language changes directly (same pattern
    // ProfileScreen/HistoryScreen already use).
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final groups = await _groupRepository.getGroups(uid);
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _onRefresh() async {
    HapticService().vibrate();
    await _load();
  }

  Future<void> _openGroup(HealthGroup group) async {
    HapticService().vibrate();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailsScreen(group: group)),
    );
    // The group may have been deleted, or a member added/removed --
    // reload the list either way rather than trying to patch it in place.
    if (mounted) await _load();
  }

  Future<void> _openJoinDialog() async {
    HapticService().vibrate();
    final joined = await showDialog<bool>(
      context: context,
      builder: (_) => const JoinGroupDialog(),
    );
    if (joined == true) await _load();
  }

  Future<void> _createGroup() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final loc = AppLocalizations.of(context)!;

    final nameController = TextEditingController();
    HapticService().vibrate();

    GroupType? selectedType;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Create is enabled only once BOTH a group name has been
            // entered and a group type has been chosen.
            final canCreate = nameController.text.trim().isNotEmpty && selectedType != null;
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(loc.nameYourGroup),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: nameController,
                      hintText: loc.groupNameHint,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      GroupTypeUi.sectionTitle(ctx),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.72,
                      children: GroupType.values.map((t) {
                        final selected = selectedType == t;
                        return GestureDetector(
                          onTap: () {
                            HapticService().vibrate();
                            setDialogState(() => selectedType = t);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: selected ? colorScheme.surfaceContainerHighest : Theme.of(ctx).cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? colorScheme.primary : colorScheme.outlineVariant,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GroupTypeUi.icon(
                                  ctx,
                                  t,
                                  size: 30,
                                  color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        GroupTypeUi.label(t, ctx),
                                        maxLines: 1,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: selected ? colorScheme.primary : colorScheme.onSurface,
                                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.cancel),
                ),
                TextButton(
                  onPressed: canCreate ? () => Navigator.pop(ctx, true) : null,
                  style: TextButton.styleFrom(
                    disabledForegroundColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                  child: Text(loc.createGroupButton),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || selectedType == null) return;

    final name = nameController.text.trim();
    HapticService().vibrate();
    await _groupRepository.createGroup(
      ownerUid: uid,
      name: name.isEmpty ? loc.defaultGroupName : name,
      groupType: selectedType,
    );
    await _load();
  }

  Future<void> _deleteAllGroups() async {
    if (_groups.isEmpty || _bulkDeleting) return;
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    HapticService().vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.deleteAllGroupsConfirmTitle),
        content: Text(loc.deleteAllGroupsConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              loc.deleteAllGroupsButton,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticService().vibrate();
    setState(() => _bulkDeleting = true);

    // Snapshot the list before looping -- _load() below replaces _groups,
    // so iterating the live field while it changes would be unsafe.
    final groupsToRemove = List<HealthGroup>.from(_groups);
    var failedCount = 0;

    for (final group in groupsToRemove) {
      try {
        if (group.ownerUid == uid) {
          // Owner: delete the group outright. deleteGroup() enforces the
          // same rule the single-card swipe-to-delete already relies on
          // (GroupRepository.deleteGroup) -- a group with other active
          // members can't be deleted this way, so that one is skipped
          // (counted as a failure) rather than silently removing other
          // people's membership.
          await _groupRepository.deleteGroup(
            groupId: group.id,
            requestingUid: uid,
          );
        } else {
          // Not the owner: this user can't delete someone else's group,
          // so "deleting" this card means leaving it -- they're no
          // longer a member either way.
          await _groupRepository.leaveGroup(groupId: group.id, uid: uid);
        }
      } catch (e) {
        debugPrint('Error removing group ${group.id} during delete-all: $e');
        failedCount++;
      }
    }

    if (!mounted) return;
    setState(() => _bulkDeleting = false);
    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failedCount == 0
              ? loc.deleteAllGroupsSuccess
              : loc.deleteAllGroupsPartialSuccess(failedCount),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final primaryColor = theme.brightness == Brightness.dark ? Colors.red : colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc.groupTab,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
              ),
              // "Delete All" -- only shown once there's at least one group
              // to remove. Reuses the same error-red delete affordance the
              // per-card swipe-to-delete and confirm dialogs already use.
              if (_groups.isNotEmpty)
                TextButton.icon(
                  onPressed: _bulkDeleting ? null : _deleteAllGroups,
                  icon: _bulkDeleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.error,
                          ),
                        )
                      : Icon(Icons.delete_sweep_outlined, size: 20, color: colorScheme.error),
                  label: Text(
                    loc.deleteAllGroupsButton,
                    style: TextStyle(fontSize: 13, color: colorScheme.error, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: primaryColor,
            onRefresh: _onRefresh,
            child: _loading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : _groups.isEmpty
                    ? _buildEmptyState(theme, colorScheme, loc)
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        itemCount: _groups.length,
                        itemBuilder: (context, i) => _buildGroupCard(theme, colorScheme, _groups[i]),
                      ),
          ),
        ),
        _buildActionButtons(colorScheme, loc),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme, AppLocalizations loc) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.group_outlined, size: 56, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          loc.noGroupYet,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          loc.groupEmptyStateSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildGroupCard(ThemeData theme, ColorScheme colorScheme, HealthGroup group) {
    final uid = _authService.currentUser?.uid;
    final isOwner = uid != null && uid == group.ownerUid;
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(group.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colorScheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: colorScheme.onError, size: 26),
        ),
        onDismissed: (_) async {
          // Only allow deletion if the user is the owner
          if (!isOwner) {
            // If not owner, show a message that only owners can delete
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.deleteGroupDisabledHint)),
              );
            }
            // Reload to restore the card
            await _load();
            return;
          }

          // Check if group has other members before allowing deletion
          try {
            final memberProfiles = await _groupRepository.getGroupMemberProfiles(group.id);
            // Check if there are other members besides the current user (owner)
            // The owner is always included in memberProfiles, so count > 1 means there are other members
            final hasOtherMembers = memberProfiles.length > 1;

            if (hasOtherMembers) {
              // Show error message - need to remove other members first
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.deleteGroupDisabledHint)),
                );
              }
              // Reload to restore the card
              await _load();
              return;
            }

            if (!mounted) return;

            // Show confirmation dialog
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(loc.deleteGroupConfirmTitle),
                content: Text(loc.deleteGroupConfirmMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(loc.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(loc.deleteGroupButton, style: TextStyle(color: colorScheme.error)),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                await _groupRepository.deleteGroup(groupId: group.id, requestingUid: uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.deleteGroupSuccess)),
                  );
                }
                // Reload the list
                await _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting group: $e')),
                  );
                }
                // Reload to restore the card if deletion failed
                await _load();
              }
            } else {
              // User cancelled, reload to restore the card
              await _load();
            }
          } catch (e) {
            debugPrint('Error checking group members: $e');
            // Reload to restore the card if there was an error
            await _load();
          }
        },
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openGroup(group),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    // The group's chosen type icon replaces the placeholder;
                    // older groups without a type keep the original icon.
                    child: group.groupType != null
                        ? Center(
                            child: GroupTypeUi.icon(
                              context,
                              group.groupType!,
                              size: 28,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.group, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOwner ? loc.groupOwnerLabel : loc.groupMemberLabel,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openJoinDialog,
              icon: Icon(Icons.qr_code_scanner_outlined, color: colorScheme.primary),
              label: Text(loc.joinGroupButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add),
              label: Text(loc.createGroupButton),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
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