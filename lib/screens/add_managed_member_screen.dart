// lib/screens/add_managed_member_screen.dart
//
// Phase 5 (Option B) — the group owner adds a member who has no account
// of their own and enters that person's name + health info directly.
//
// Deliberately structured as a near-copy of
// PersonalInfoScreen._buildConditionsSection() /
// PersonalInfoScreen's allergens section, using the SAME condition/
// allergen keys ('Diabetes', 'Hypertension', 'Heart condition',
// 'Fish', 'Milk/Dairy', etc. -- see firestore_label_mappings.dart) so the
// data this screen produces maps onto HealthCondition/AllergenType via
// the exact same mapping code the rest of the app already uses. Anyone
// who has used PersonalInfoScreen will find this screen immediately
// familiar -- same icons, same Switch styling, same layout.
//
// The actual save call goes through GroupRepository.saveManagedMemberHealthData(),
// which is a NEW Worker endpoint (Phase 6) -- NOT AuthService's
// _pushHealthDataToWorker(), which is hard-wired to write the CALLER's
// own profile and has no notion of a target member.

import 'package:flutter/material.dart';

import '../data/models/health_group.dart';
import '../data/services/backend_locator.dart';
import '../services/haptic_service.dart';
import '../widgets/custom_text_field.dart';
import '../core/utils/success_feedback_utils.dart';

class AddManagedMemberScreen extends StatefulWidget {
  final HealthGroup group;

  const AddManagedMemberScreen({super.key, required this.group});

  @override
  State<AddManagedMemberScreen> createState() => _AddManagedMemberScreenState();
}

class _AddManagedMemberScreenState extends State<AddManagedMemberScreen> {
  final _groupRepository = BackendLocator.groupRepository;
  final _nameController = TextEditingController();

  // Same fixed option set as PersonalInfoScreen, so the data this screen
  // produces is compatible with firestore_label_mappings.dart without any
  // changes there.
  final Map<String, bool> _conditions = {
    'Diabetes': false,
    'Hypertension': false,
    'Heart condition': false,
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

  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = "Enter this member's name");
      return;
    }

    setState(() {
      _saving = true;
      _nameError = null;
    });

    HapticService().vibrate();

    // Step 1: create the member record (name only, no health data yet).
    final member = await _groupRepository.addManagedMember(
      groupId: widget.group.id,
      displayName: name,
    );

    // Step 2: push health data through the Worker (Phase 6). If this
    // fails, the member still exists with no conditions/allergens set --
    // the owner can retry from the member's edit screen (same idea as
    // PersonalInfoScreen retrying a failed toggle).
    final selectedConditions =
        _conditions.entries.where((e) => e.value).map((e) => e.key).toList();
    final selectedAllergens =
        _allergens.entries.where((e) => e.value).map((e) => e.key).toList();

    final ok = await _groupRepository.saveManagedMemberHealthData(
      groupId: widget.group.id,
      memberId: member.id,
      conditions: selectedConditions,
      allergens: selectedAllergens,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      SuccessFeedbackUtils.showSuccessSnackBar(context, '$name added to your group');
      Navigator.pop(context, true);
    } else {
      SuccessFeedbackUtils.showSuccessSnackBar(
        context,
        '$name was added, but health info failed to save. Edit them to retry.',
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a Member')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
              controller: _nameController,
              hintText: "Member's name",
              errorText: _nameError,
            ),
            const SizedBox(height: 20),
            _buildConditionsSection(theme, colorScheme),
            const SizedBox(height: 16),
            _buildAllergensSection(theme, colorScheme),
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
                    : const Text('Add Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Copied structurally from
  // PersonalInfoScreen._buildConditionsSection() -- same card shape, same
  // icon, same Switch styling. The only difference is this writes into
  // local screen state instead of pushing one toggle at a time to the
  // Worker (this screen batches everything into one save on submit).
  Widget _buildConditionsSection(ThemeData theme, ColorScheme colorScheme) {
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
                'Health Conditions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._conditions.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(entry.key, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
                  ),
                  Switch(
                    value: entry.value,
                    onChanged: (value) {
                      HapticService().vibrate();
                      setState(() => _conditions[entry.key] = value);
                    },
                    activeThumbColor: colorScheme.primary,
                    activeTrackColor: colorScheme.primary.withAlpha(120),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllergensSection(ThemeData theme, ColorScheme colorScheme) {
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
                'Allergens',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._allergens.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.circle_notifications_outlined, color: colorScheme.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(entry.key, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
                  ),
                  Switch(
                    value: entry.value,
                    onChanged: (value) {
                      HapticService().vibrate();
                      setState(() => _allergens[entry.key] = value);
                    },
                    activeThumbColor: colorScheme.primary,
                    activeTrackColor: colorScheme.primary.withAlpha(120),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
