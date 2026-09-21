// lib/screens/invite_member_screen.dart
//
// Phase 4 (Option A) — the group owner generates an invite code/QR here
// and shares it with a family member/friend/co-living partner, who
// redeems it on their own device via the Join popup (see
// widgets/join_group_dialog.dart, opened from GroupScreen's Join button).
//
// Uses qr_flutter for the QR code -- add it to pubspec.yaml:
//   qr_flutter: ^4.1.0
// (the project's camera-scanning stack reads QR/barcodes but doesn't
// appear to generate them, so this is a new, standard, well-maintained
// package rather than a hand-rolled QR renderer.)
//
// Visual style: same card container + Divider pattern as
// PersonalInfoScreen sections; the code itself is shown large and
// monospaced with a "Copy" affordance, same weight as other emphasized
// values in the app (e.g. the profile name in ProfileScreen._buildProfileCard()).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/models/health_group.dart';
import '../data/services/backend_locator.dart';
import '../services/haptic_service.dart';
import '../core/utils/success_feedback_utils.dart';

class InviteMemberScreen extends StatefulWidget {
  final HealthGroup group;

  const InviteMemberScreen({super.key, required this.group});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _groupRepository = BackendLocator.groupRepository;
  GroupInvite? _invite;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateInvite();
  }

  Future<void> _generateInvite() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final invite = await _groupRepository.createInvite(
        groupId: widget.group.id,
        ownerUid: widget.group.ownerUid,
      );
      if (mounted) {
        setState(() {
          _invite = invite;
          _generating = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to create invite: $e');
      if (mounted) {
        setState(() {
          _generating = false;
          _error = 'Could not generate an invite code. Please check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite a Member')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 40, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _generateInvite, child: const Text('Try again')),
                    ],
                  ),
                )
              : _generating || _invite == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Text(
                      'Share this code or QR with the person you want to add. '
                      'It expires in 48 hours and can only be used once.',
                      style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: _invite!.code,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _invite!.code,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              HapticService().vibrate();
                              Clipboard.setData(ClipboardData(text: _invite!.code));
                              SuccessFeedbackUtils.showSuccessSnackBar(context, 'Code copied');
                            },
                            icon: Icon(Icons.copy, color: colorScheme.primary, size: 18),
                            label: Text('Copy code', style: TextStyle(color: colorScheme.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          HapticService().vibrate();
                          await _groupRepository.revokeInvite(
                            groupId: widget.group.id,
                            code: _invite!.code,
                          );
                          await _generateInvite();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Revoke & Generate New Code'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}