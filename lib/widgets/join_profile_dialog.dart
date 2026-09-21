// lib/widgets/join_profile_dialog.dart
//
// Shown after a valid invite code/QR has been entered but BEFORE the user
// actually joins. Collects the name + avatar that will appear on their
// member card in the group (for both the owner and the member).
//
// Pops a [JoinProfile] when the user taps Join, or null if cancelled.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import 'avatar_picker.dart';
import 'custom_text_field.dart';

class JoinProfile {
  final String name;
  final String avatar;
  const JoinProfile({required this.name, required this.avatar});
}

class JoinProfileDialog extends StatefulWidget {
  final String uid;
  const JoinProfileDialog({super.key, required this.uid});

  @override
  State<JoinProfileDialog> createState() => _JoinProfileDialogState();
}

class _JoinProfileDialogState extends State<JoinProfileDialog> {
  final _nameController = TextEditingController();
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _prefillName();
  }

  // Pre-fill with the name captured during onboarding/sign-up
  // (users/{uid}.name). Still editable.
  Future<void> _prefillName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final name = doc.data()?['name']?.toString().trim() ?? '';
      if (mounted && name.isNotEmpty && _nameController.text.isEmpty) {
        _nameController.text = name;
      }
    } catch (_) {
      // Non-fatal: the user can just type their name.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canJoin => _nameController.text.trim().isNotEmpty && _avatar != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final tl = Localizations.localeOf(context).languageCode == 'tl';

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tl ? 'Sumali sa Grupo' : 'Join Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              tl ? 'Pangalan' : 'Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _nameController,
              hintText: tl ? 'Ang iyong pangalan' : 'Your name',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Text(
              'Avatar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            AvatarPicker(
              selected: _avatar,
              onChanged: (a) => setState(() => _avatar = a),
            ),
            const SizedBox(height: 14),
            Text(
              tl
                  ? 'Makikita ng mga miyembro ng grupo ang iyong pangalan, avatar, at impormasyon sa kalusugan.'
                  : 'Members of the group will be able to see your name, avatar, and health information.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canJoin
                    ? () {
                        HapticService().vibrate();
                        Navigator.pop(
                          context,
                          JoinProfile(name: _nameController.text.trim(), avatar: _avatar!),
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade400,
                  disabledForegroundColor: isDark ? Colors.grey.shade500 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tl ? 'Sumali' : 'Join'),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(loc.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}