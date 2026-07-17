import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../services/auth_service.dart';

/// Simplified report screen for unidentified products.
///
/// Flow (matches CLARO design):
///  1. Shows the captured photo (or a placeholder) with a "Change Photo" button
///  2. Shows the detected product name (editable) with an "Edit" button
///  3. An info card explaining the value of reporting
///  4. A prominent "Submit" button
///  5. On success → dialog with "Go back to Home"
class UnknownProductSubmissionScreen extends StatefulWidget {
  /// Path to the image captured during the failed scan.
  final String? capturedImagePath;

  const UnknownProductSubmissionScreen({super.key, this.capturedImagePath});

  @override
  State<UnknownProductSubmissionScreen> createState() =>
      _UnknownProductSubmissionScreenState();
}

class _UnknownProductSubmissionScreenState
    extends State<UnknownProductSubmissionScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String? _imagePath;
  bool _isEditingName = false;
  bool _isEditingDesc = false;
  bool _isSubmitting = false;

  final _authService = AuthService();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _imagePath = widget.capturedImagePath;
    _nameCtrl = TextEditingController(text: '');
    _descCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Pick / replace photo ───────────────────────────────────────────────
  Future<void> _changePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  // ── Submit report to Firestore ─────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      final uid = user?.uid ?? 'anonymous';
      final email = user?.email ?? '';
      final name = user?.displayName ?? email.split('@').first;

      await FirebaseFirestore.instance.collection('reports').add({
        'dateSubmitted': FieldValue.serverTimestamp(),
        'productDescription': _descCtrl.text.trim(),
        'productName': _nameCtrl.text.trim(),
        'reportedBy': uid,
        'status': 'Pending',
        'userEmail': email,
        'userName': name,
        // Keep imagePath around even if not in the requested schema so we don't lose the photo
        'imagePath': _imagePath ?? '', 
      });

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      debugPrint('Report submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                loc.reportSuccessTitle,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),

              // Body
              Text(
                loc.reportSuccessBody,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Go Home button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // close dialog
                    // Pop all the way back to the home screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home, size: 20),
                  label: Text(
                    loc.reportGoHome,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: colorScheme.primary, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // ── Scrollable content ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      loc.reportTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      loc.reportSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Product Photo section ────────────────────
                    Text(
                      loc.reportProductPhoto,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Photo preview
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 140,
                            height: 140,
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            child: _imagePath != null &&
                                    File(_imagePath!).existsSync()
                                ? Image.file(
                                    File(_imagePath!),
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 48,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Change Photo button
                        OutlinedButton.icon(
                          onPressed: _changePhoto,
                          icon: Icon(Icons.camera_alt_outlined,
                              size: 18, color: colorScheme.primary),
                          label: Text(
                            loc.reportChangePhoto,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Product Name section ─────────────────────
                    Text(
                      loc.reportProductName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _isEditingName
                              ? TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: colorScheme.primary),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: colorScheme.primary,
                                          width: 1.5),
                                    ),
                                  ),
                                  onSubmitted: (_) =>
                                      setState(() => _isEditingName = false),
                                )
                              : Text(
                                  _nameCtrl.text.isEmpty
                                      ? '—'
                                      : _nameCtrl.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _isEditingName = !_isEditingName),
                          icon: Icon(
                            _isEditingName ? Icons.check : Icons.edit_outlined,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          label: Text(
                            _isEditingName
                                ? 'OK'
                                : loc.reportEditButton,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Product Description section ─────────────
                    Text(
                      loc.reportProductDescription,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _isEditingDesc
                              ? TextField(
                                  controller: _descCtrl,
                                  autofocus: true,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: colorScheme.primary),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: colorScheme.primary,
                                          width: 1.5),
                                    ),
                                  ),
                                  onSubmitted: (_) =>
                                      setState(() => _isEditingDesc = false),
                                )
                              : Text(
                                  _descCtrl.text.isEmpty
                                      ? '—'
                                      : _descCtrl.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _isEditingDesc = !_isEditingDesc),
                          icon: Icon(
                            _isEditingDesc ? Icons.check : Icons.edit_outlined,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          label: Text(
                            _isEditingDesc
                                ? 'OK'
                                : loc.reportEditButton,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Info note card ────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: colorScheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              loc.reportInfoNote,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Submit button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: colorScheme.onPrimary,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                loc.reportSubmitButton,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: const VoiceAssistantFab(),

      // ── Bottom Navigation Bar ──────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context, colorScheme, theme),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final loc = AppLocalizations.of(context)!;
    final navPillColor = theme.brightness == Brightness.dark
        ? colorScheme.primary.withValues(alpha: 0.2)
        : const Color(0xFFF6CDCD);

    final items = [
      (icon: Icons.home_outlined, label: loc.home, active: false),
      (icon: Icons.qr_code_scanner, label: loc.scan, active: true),
      (icon: Icons.history_outlined, label: loc.history, active: false),
      (icon: Icons.person_outline, label: loc.profile, active: false),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.map((item) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: item.active ? navPillColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: colorScheme.primary, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight:
                            item.active ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
