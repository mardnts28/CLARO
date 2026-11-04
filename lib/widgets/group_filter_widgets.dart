// lib/widgets/group_filter_widgets.dart
//
// Group filter button (name + enabled checkbox) and the member-selection
// dialog, shared by CompareProductsScreen and MultiScanResultsScreen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/utils/group_filter_controller.dart';
import '../services/haptic_service.dart';

/// Group-name filter chip with a checkbox reflecting whether the group
/// filter is enabled. Tapping it opens the member dialog.
class GroupFilterButton extends StatelessWidget {
  const GroupFilterButton({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final GroupFilterController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = controller.isActive;
    final isDark = theme.brightness == Brightness.dark;
    final bg = Color.alphaBlend(
      cs.secondary.withValues(alpha: active ? 0.12 : 0.04),
      theme.scaffoldBackgroundColor,
    );

    return GestureDetector(
      onTap: () {
        HapticService().vibrate();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.16),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display-only: the whole chip opens the dialog.
            IgnorePointer(
              child: SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: active,
                  onChanged: (_) {},
                  activeColor: cs.secondary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                controller.group.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? cs.secondary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupFilterResult {
  const GroupFilterResult({required this.enabled, required this.selectedIds});
  final bool enabled;
  final Set<String> selectedIds;
}

/// Dialog listing the group's members with checkboxes. Returns the new
/// selection when "Apply" is tapped, or null if dismissed.
Future<GroupFilterResult?> showGroupFilterDialog(
  BuildContext context,
  GroupFilterController controller,
) {
  return showDialog<GroupFilterResult>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final cs = theme.colorScheme;
      var enabled = controller.enabled;
      final selected = Set<String>.from(controller.selectedIds);
      final members = controller.members;

      return StatefulBuilder(
        builder: (context, setState) {
          final allSelected = selected.length == members.length;
          final noneSelected = selected.isEmpty;

          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(
              controller.group.name,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Master switch: off == only the user's own profile.
                    CheckboxListTile(
                      value: enabled,
                      activeColor: cs.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Use group health profile',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        enabled
                            ? 'Ranking uses the selected members below.'
                            : 'Ranking uses only your own health profile.',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      onChanged: (v) {
                        HapticService().vibrate();
                        setState(() {
                          enabled = v == true;
                          // Re-enabling with nobody selected: select all.
                          if (enabled && selected.isEmpty) {
                            selected.addAll(members.map((m) => m.member.id));
                          }
                        });
                      },
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      value: allSelected ? true : (noneSelected ? false : null),
                      tristate: true,
                      activeColor: cs.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Select all members',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      onChanged: !enabled
                          ? null
                          : (_) {
                              HapticService().vibrate();
                              setState(() {
                                if (allSelected) {
                                  selected.clear();
                                } else {
                                  selected
                                    ..clear()
                                    ..addAll(members.map((m) => m.member.id));
                                }
                              });
                            },
                    ),
                    for (final m in members)
                      CheckboxListTile(
                        value: selected.contains(m.member.id),
                        activeColor: cs.primary,
                        contentPadding: const EdgeInsets.only(left: 12),
                        title: Text(
                          controller.isSelf(m)
                              ? '${m.member.displayName ?? m.profile.displayName} (You)'
                              : (m.member.displayName ??
                                    m.profile.displayName),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        onChanged: !enabled
                            ? null
                            : (v) {
                                HapticService().vibrate();
                                setState(() {
                                  if (v == true) {
                                    selected.add(m.member.id);
                                  } else {
                                    selected.remove(m.member.id);
                                  }
                                });
                              },
                      ),
                    if (enabled && noneSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No members selected: only your own profile will be used.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                onPressed: () => Navigator.pop(
                  dialogContext,
                  GroupFilterResult(
                    enabled: enabled && selected.isNotEmpty,
                    selectedIds: selected,
                  ),
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
    },
  );
}
