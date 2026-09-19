// lib/screens/add_managed_member_screen.dart
//
// Phase 5 (Option B) — the group owner adds a member who has no account
// of their own and enters that person's name + health info directly.
//
// UPDATED (Health Group UI & Navigation Update): the condition/allergen
// picker used to be a column of Switch toggles. It's now a tappable
// multiple-selection grid -- the exact same visual pattern
// OnboardingScreen uses for its own Health Profile step
// (_buildConditionsGrid / _buildAllergensGrid / _buildToggleItem in
// onboarding_screen.dart), so a manually-added member's health profile
// is filled in with a UI a user has already seen during their own
// onboarding.
//
// UPDATED: also now doubles as the EDIT screen for an existing managed
// member (see GroupDetailsScreen's edit button), via the optional
// [existingMember] constructor param. In that mode the name field is
// locked (renaming isn't in scope here) and the grid is pre-selected
// from that member's current health profile.
//
// Uses the SAME condition/allergen keys ('Diabetes', 'Hypertension',
// 'Heart condition', 'Fish', 'Milk/Dairy', etc. -- see
// firestore_label_mappings.dart) so the data this screen produces maps
// onto HealthCondition/AllergenType via the exact same mapping code the
// rest of the app already uses.
//
// The actual save call goes through GroupRepository.saveManagedMemberHealthData(),
// which is a NEW Worker endpoint (Phase 6) -- NOT AuthService's
// _pushHealthDataToWorker(), which is hard-wired to write the CALLER's
// own profile and has no notion of a target member.

import 'package:flutter/material.dart';

import '../data/models/health_group.dart';
import '../data/models/health_profile.dart';
import '../data/services/backend_locator.dart';
import '../services/haptic_service.dart';
import '../widgets/custom_text_field.dart';
import '../core/utils/success_feedback_utils.dart';
import '../generated/l10n/app_localizations.dart';

class AddManagedMemberScreen extends StatefulWidget {
  final HealthGroup group;

  // When set, this screen edits this existing managed member's health
  // profile instead of creating a new member. Only ever passed for a
  // GroupMember with sourceType == managed -- GroupDetailsScreen never
  // offers this edit entry point for "linked" members, since a primary
  // user can only VIEW (not manage) an invited member's own profile.
  final GroupMember? existingMember;

  const AddManagedMemberScreen({super.key, required this.group, this.existingMember});

  bool get isEditing => existingMember != null;

  @override
  State<AddManagedMemberScreen> createState() => _AddManagedMemberScreenState();
}

class _AddManagedMemberScreenState extends State<AddManagedMemberScreen> {
  final _groupRepository = BackendLocator.groupRepository;
  final _nameController = TextEditingController();

  // Same fixed option set as PersonalInfoScreen/OnboardingScreen, so the
  // data this screen produces is compatible with firestore_label_mappings.dart
  // without any changes there. Supports both English and Tagalog labels.
  final Map<String, bool> _conditions = {
    'Diabetes': false,
    'Hypertension': false,
    'Heart condition': false,
    'Low vision': false,
    'None': false,
  };
  final Map<String, bool> _allergens = {
    'Fish': false,
    'Milk/Dairy': false,
    'Eggs': false,
    'Soy': false,
    'Wheat': false,
    'Shellfish': false,
    'Peanuts': false,
  };

  final Map<String, IconData> _conditionIcons = {
    'Diabetes': Icons.bloodtype_outlined,
    'Hypertension': Icons.monitor_heart_outlined,
    'Heart condition': Icons.favorite_border,
    'Low vision': Icons.visibility_off_outlined,
    'None': Icons.block,
  };

  final Map<String, IconData> _allergenIcons = {
    'Fish': Icons.set_meal_outlined,
    'Milk/Dairy': Icons.local_drink_outlined,
    'Eggs': Icons.egg_outlined,
    'Soy': Icons.eco_outlined,
    'Wheat': Icons.grass_outlined,
    'Shellfish': Icons.water_outlined,
    'Peanuts': Icons.spa_outlined,
  };

  bool _saving = false;
  bool _loadingExisting = false;
  String? _nameError;

  String _getLocalizedConditionLabel(String key, AppLocalizations loc) {
    switch (key) {
      case 'Diabetes':
        return loc.conditionDiabetes;
      case 'Hypertension':
        return loc.conditionHypertension;
      case 'Heart condition':
        return loc.conditionHeartCondition;
      case 'Low vision':
        return loc.conditionLowVision;
      case 'None':
        return loc.conditionNone;
      default:
        return key;
    }
  }

  String _getLocalizedAllergenLabel(String key, AppLocalizations loc) {
    switch (key) {
      case 'Fish':
        return loc.allergenFish;
      case 'Milk/Dairy':
        return loc.allergenMilk;
      case 'Eggs':
        return loc.allergenEggs;
      case 'Soy':
        return loc.allergenSoy;
      case 'Wheat':
        return loc.allergenWheat;
      case 'Shellfish':
        return loc.allergenShellfish;
      case 'Peanuts':
        return loc.allergenPeanuts;
      default:
        return key;
    }
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMember;
    if (existing != null) {
      _nameController.text = existing.displayName ?? '';
      _loadExistingProfile(existing);
    }
  }

  Future<void> _loadExistingProfile(GroupMember member) async {
    setState(() => _loadingExisting = true);
    try {
      // No single-member fetch endpoint exists -- getGroupHealthProfiles
      // returns every active member's profile in one call (it's the same
      // call GroupDetailsScreen makes to render its member list), so
      // this just picks this member's entry out of that batch.
      final profiles = await _groupRepository.getGroupHealthProfiles(widget.group.id);
      final profile = profiles.where((p) => p.userId == member.id).toList();
      if (profile.isNotEmpty && mounted) {
        final p = profile.first;
        setState(() {
          for (final c in p.conditions) {
            final key = _conditionKeyFor(c);
            if (key != null) _conditions[key] = true;
          }
          if (p.conditions.isEmpty) _conditions['None'] = true;
          for (final a in p.allergies) {
            final key = _allergenKeyFor(a);
            if (key != null) _allergens[key] = true;
          }
        });
      }
    } catch (_) {
      // Leave the grid at its default (nothing selected) -- the owner
      // can still fill it in and save from scratch.
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  String? _conditionKeyFor(HealthCondition c) {
    switch (c) {
      case HealthCondition.diabetes:
        return 'Diabetes';
      case HealthCondition.hypertension:
        return 'Hypertension';
      case HealthCondition.heartCondition:
        return 'Heart condition';
    }
  }

  String? _allergenKeyFor(AllergenType a) {
    switch (a) {
      case AllergenType.fish:
        return 'Fish';
      case AllergenType.dairy:
        return 'Milk/Dairy';
      case AllergenType.eggs:
        return 'Eggs';
      case AllergenType.soy:
        return 'Soy';
      case AllergenType.wheatGluten:
        return 'Wheat';
      case AllergenType.shellfish:
        return 'Shellfish';
      case AllergenType.peanuts:
        return 'Peanuts';
      default:
        return null; // treeNuts/msg have no grid entry here
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleCondition(String key) {
    HapticService().vibrate();
    setState(() {
      if (key == 'None') {
        _conditions.forEach((k, v) => _conditions[k] = false);
        _conditions['None'] = true;
      } else {
        _conditions['None'] = false;
        _conditions[key] = !_conditions[key]!;
      }
    });
  }

  void _toggleAllergen(String key) {
    HapticService().vibrate();
    setState(() => _allergens[key] = !_allergens[key]!);
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final isEditing = widget.isEditing;

    String name = _nameController.text.trim();
    if (!isEditing && name.isEmpty) {
      setState(() => _nameError = loc.memberNameEmptyError);
      return;
    }
    if (isEditing) {
      // Locked field in edit mode -- always the existing member's name.
      name = widget.existingMember!.displayName ?? '';
    }

    setState(() {
      _saving = true;
      _nameError = null;
    });

    HapticService().vibrate();

    final selectedConditions =
        _conditions.entries.where((e) => e.value && e.key != 'None').map((e) => e.key).toList();
    final selectedAllergens =
        _allergens.entries.where((e) => e.value).map((e) => e.key).toList();

    String memberId;
    if (isEditing) {
      memberId = widget.existingMember!.id;
    } else {
      // Step 1: create the member record (name only, no health data yet).
      final member = await _groupRepository.addManagedMember(
        groupId: widget.group.id,
        displayName: name,
      );
      memberId = member.id;
    }

    // Step 2: push health data through the Worker (Phase 6). If this
    // fails, the member still exists with no conditions/allergens set --
    // the owner can retry from this same screen (GroupDetailsScreen's
    // edit button).
    final ok = await _groupRepository.saveManagedMemberHealthData(
      groupId: widget.group.id,
      memberId: memberId,
      conditions: selectedConditions,
      allergens: selectedAllergens,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (isEditing) {
      Navigator.pop(context, true);
      return;
    }

    if (ok) {
      SuccessFeedbackUtils.showSuccessSnackBar(context, loc.memberAddedSuccess(name));
      Navigator.pop(context, true);
    } else {
      SuccessFeedbackUtils.showSuccessSnackBar(context, loc.memberAddedHealthDataFailed(name));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? loc.editHealthProfile : loc.addMemberButton)),
      body: SafeArea(
        child: _loadingExisting
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CustomTextField(
                    controller: _nameController,
                    hintText: loc.memberNameHint,
                    errorText: _nameError,
                    enabled: !widget.isEditing,
                  ),
                  const SizedBox(height: 20),
                  _buildConditionsSection(theme, colorScheme, loc),
                  const SizedBox(height: 16),
                  _buildAllergensSection(theme, colorScheme, loc),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(widget.isEditing ? loc.save : loc.addMemberButton),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildConditionsSection(ThemeData theme, ColorScheme colorScheme, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                loc.healthConditions,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildToggleGrid(
            theme: theme,
            keys: _conditions.keys.toList(),
            values: _conditions,
            icons: _conditionIcons,
            labelFor: (key) => _getLocalizedConditionLabel(key, loc),
            onTap: _toggleCondition,
          ),
        ],
      ),
    );
  }

  Widget _buildAllergensSection(ThemeData theme, ColorScheme colorScheme, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                loc.allergensLabel,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildToggleGrid(
            theme: theme,
            keys: _allergens.keys.toList(),
            values: _allergens,
            icons: _allergenIcons,
            labelFor: (key) => _getLocalizedAllergenLabel(key, loc),
            onTap: _toggleAllergen,
          ),
        ],
      ),
    );
  }

  // Multiple-selection grid -- same visual pattern as
  // OnboardingScreen._buildConditionsGrid()/_buildAllergensGrid()/
  // _buildToggleItem() (see onboarding_screen.dart): a 4-column GridView
  // of tappable cards, selected state shown via a filled border +
  // checkmark badge instead of a Switch. Kept as one shared builder here
  // (rather than two near-duplicate grids like onboarding's) since both
  // sections use Material icons instead of onboarding's image assets.
  Widget _buildToggleGrid({
    required ThemeData theme,
    required List<String> keys,
    required Map<String, bool> values,
    required Map<String, IconData> icons,
    required String Function(String key) labelFor,
    required void Function(String key) onTap,
  }) {
    final colorScheme = theme.colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: keys.map((key) {
        final selected = values[key]!;
        return GestureDetector(
          onTap: () => onTap(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? colorScheme.surfaceContainerHighest : theme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colorScheme.primary : colorScheme.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[key] ?? Icons.circle_outlined,
                        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          labelFor(key),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}