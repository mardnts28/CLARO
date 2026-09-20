// lib/widgets/join_group_dialog.dart
//
// The "Join" popup card opened from GroupScreen. Replaces the old
// full-screen JoinGroupScreen (Phase 4) now that Join is a popup rather
// than a ProfileScreen menu destination -- same redeemInvite() call
// underneath, same CustomTextField styling, just presented as a Dialog
// instead of a pushed route.
//
// Validation: the invite-code field only accepts the invite-code format
// -- exactly kInviteCodeLength (9) characters, all caps letters and
// digits, no special characters or spaces. Lowercase keystrokes are
// upshifted rather than rejected (most people won't reach for caps lock
// to type a share code), and anything outside A-Z/0-9 is dropped as it's
// typed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/services/backend_locator.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../screens/qr_scan_screen.dart';
import 'custom_text_field.dart';
import 'join_profile_dialog.dart';

/// Invite codes are exactly this many characters -- see
/// GroupRepository._generateInviteCode() in data/repositories/group_repository.dart.
const int kInviteCodeLength = 9;

bool isValidInviteCode(String code) =>
    RegExp('^[A-Z0-9]{$kInviteCodeLength}\$').hasMatch(code);

class _UpperCaseAlphanumericFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}

/// Shown via `showDialog(context: context, builder: (_) => const
/// JoinGroupDialog())`. Pops `true` if the user successfully joined a
/// group, so the caller (GroupScreen) knows to reload its list.
class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final _authService = AuthService();
  final _groupRepository = BackendLocator.groupRepository;
  final _codeController = TextEditingController();

  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();

    if (!isValidInviteCode(code)) {
      setState(() => _errorText = loc.invalidCodeError);
      return;
    }

    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    HapticService().vibrate();
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      // 1. Make sure the code is real/unexpired BEFORE asking for a
      //    profile, so nobody fills in a form for a dead code.
      await _groupRepository.validateInvite(code);
      if (!mounted) return;

      // 2. Collect the name + avatar that will appear on their member card.
      final profile = await showDialog<JoinProfile>(
        context: context,
        barrierDismissible: false,
        builder: (_) => JoinProfileDialog(uid: uid),
      );
      if (profile == null) {
        // Cancelled -- back to the code dialog, nothing joined.
        if (mounted) setState(() => _submitting = false);
        return;
      }

      // 3. Join with that profile (existing redeem flow).
      await _groupRepository.redeemInvite(
        code: code,
        joiningUid: uid,
        displayName: profile.name,
        avatar: profile.avatar,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = loc.codeDidNotWorkError;
        _submitting = false;
      });
    }
  }

  Future<void> _scanQr() async {
    HapticService().vibrate();
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (scanned == null || !mounted) return;

    final cleaned = scanned.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    _codeController.text = cleaned;
    setState(() => _errorText = null);

    // A QR that already decodes to a well-formed code can be submitted
    // right away -- no reason to make the person re-tap Join Group after
    // a successful scan. A malformed/foreign QR just leaves the (likely
    // invalid) text in the field for the person to see and correct.
    if (isValidInviteCode(cleaned)) {
      await _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.joinGroupDialogTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              loc.joinGroupDialogSubtitle,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _codeController,
              hintText: loc.inviteCodeHint,
              errorText: _errorText,
              textInputAction: TextInputAction.done,
              autofocus: true,
              inputFormatters: [
                _UpperCaseAlphanumericFormatter(),
                LengthLimitingTextInputFormatter(kInviteCodeLength),
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(loc.joinGroupSubmit),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _submitting ? null : _scanQr,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      loc.joinViaQr,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context, false),
                child: Text(loc.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}