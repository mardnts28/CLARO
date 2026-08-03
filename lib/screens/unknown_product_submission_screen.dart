import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../data/services/backend_locator.dart';

/// Report screen for unidentified products.
///
/// Flow (Phase 3):
///  1. Front photo -- pre-filled from the failed scan, replaceable
///  2. Back photo (nutrition label) -- required, must be added before submit
///  3. Submit uploads both photos to Cloudinary, writes the report to
///     Firestore immediately (status: Pending), and shows the success
///     dialog right away -- OCR + Gemini extraction then runs in the
///     background and patches `extractedData` onto the same report doc
///     once it finishes, so the user never waits on it.
class UnknownProductSubmissionScreen extends StatefulWidget {
  /// Path to the image captured during the failed scan -- reused as the
  /// front photo so the user doesn't have to retake something they already
  /// captured. Only the back photo is asked for fresh.
  final String? capturedImagePath;

  const UnknownProductSubmissionScreen({super.key, this.capturedImagePath});

  @override
  State<UnknownProductSubmissionScreen> createState() =>
      _UnknownProductSubmissionScreenState();
}

class _UnknownProductSubmissionScreenState
    extends State<UnknownProductSubmissionScreen> {
  String? _frontImagePath;
  String? _backImagePath;
  bool _isSubmitting = false;
  String _productName = '';
  String _selectedCategory = 'others'; // Default to 'others'

  final _authService = AuthService();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();

  final List<String> _categories = [
    'canned fish',
    'canned seafood',
    'canned meat',
    'canned vegetables',
    'instant noodles',
    'others',
  ];

  @override
  void initState() {
    super.initState();
    _frontImagePath = widget.capturedImagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Pick / replace photos ──────────────────────────────────────────────
  Future<void> _changeFrontPhoto() async {
    // Request camera permission first
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take photos'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _frontImagePath = picked.path);
      }
    } catch (e) {
      debugPrint('Front image pick error: $e');
    }
  }

  Future<void> _pickBackPhoto() async {
    // Request camera permission first
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take photos'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _backImagePath = picked.path);
      }
    } catch (e) {
      debugPrint('Back image pick error: $e');
    }
  }

  // ── Submit report to Firestore ─────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    if (_backImagePath == null) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.reportBackPhotoRequired),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a product name'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      final uid = user?.uid ?? 'anonymous';
      final email = user?.email ?? '';
      final name = user?.displayName ?? email.split('@').first;

      // Read both photos once -- the same bytes are used for the Cloudinary
      // upload below and for the background extraction call afterwards, so
      // we don't hit the file system twice per photo.
      final frontBytes = await File(_frontImagePath!).readAsBytes();
      final backBytes = await File(_backImagePath!).readAsBytes();

      // Upload in parallel. CloudinaryUploadService.upload() returns null
      // on failure rather than throwing -- we still let the report submit
      // with a blank URL in that case (see its header comment) rather than
      // blocking the whole submission on an image host hiccup.
      final uploads = await Future.wait([
        BackendLocator.cloudinaryUploadService.upload(
          frontBytes,
          filename: '${uid}_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        BackendLocator.cloudinaryUploadService.upload(
          backBytes,
          filename: '${uid}_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      ]);
      final frontUrl = uploads[0] ?? '';
      final backUrl = uploads[1] ?? '';

      final report = ReportModel(
        id: '', // Firestore assigns this on add(); unused in toMap().
        dateSubmitted: DateTime.now(), // overwritten by toMap()'s serverTimestamp
        productDescription: '',
        productName: _nameController.text.trim(),
        category: _selectedCategory,
        reportedBy: uid,
        status: 'Pending',
        userEmail: email,
        userName: name,
        frontImageUrl: frontUrl,
        backImageUrl: backUrl,
        extractedData: const {}, // filled in by the background step below
      );

      final docRef =
          await FirebaseFirestore.instance.collection('reports').add(report.toMap());

      if (!mounted) return;
      _showSuccessDialog();

      // Fire-and-forget: don't await this, and don't touch `context`/State
      // from inside it -- the user has already seen the success dialog and
      // may navigate away before this finishes. Only Firestore writes
      // happen here, which are safe regardless of whether this screen is
      // still mounted.
      _runBackgroundExtraction(docRef.id, frontBytes, backBytes);
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

  // ── Background extraction (Gemini's 3rd role in this app) ──────────────
  // Runs after the report is already submitted and the user has moved on.
  // Patches `extractedData` onto the same report doc once done, so it's
  // ready by the time admin opens this report for review -- see
  // ProductExtractionService and ReportModel.extractedData.
  Future<void> _runBackgroundExtraction(
    String reportId,
    Uint8List frontBytes,
    Uint8List backBytes,
  ) async {
    try {
      final result = await BackendLocator.productExtractionService.extract(
        frontImageBytes: frontBytes,
        backImageBytes: backBytes,
      );
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'extractedData': result.toReportExtractedDataMap(),
      });
    } catch (e) {
      debugPrint('Background extraction error for report $reportId: $e');
      // Not surfaced to the user -- the report was already submitted
      // successfully. Admin's review UI (Phase 4) treats an empty/missing
      // extractedData as "needs manual entry" rather than an error state.
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

  // ── Reusable photo block (front or back) ────────────────────────────────
  Widget _photoBlock({
    required ColorScheme colorScheme,
    required String label,
    String? hint,
    required String? imagePath,
    required String buttonLabel,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 140,
                height: 140,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: imagePath != null && File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
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
            OutlinedButton.icon(
              onPressed: onPick,
              icon: Icon(Icons.camera_alt_outlined, size: 18, color: colorScheme.primary),
              label: Text(
                buttonLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final canSubmit = !_isSubmitting && _backImagePath != null;

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

                    // ── Front Photo section ───────────────────────
                    _photoBlock(
                      colorScheme: colorScheme,
                      label: loc.reportFrontPhoto,
                      imagePath: _frontImagePath,
                      buttonLabel: loc.reportChangePhoto,
                      onPick: _changeFrontPhoto,
                    ),

                    const SizedBox(height: 28),

                    // ── Back Photo section (required) ─────────────
                    _photoBlock(
                      colorScheme: colorScheme,
                      label: loc.reportBackPhoto,
                      hint: loc.reportBackPhotoHint,
                      imagePath: _backImagePath,
                      buttonLabel: _backImagePath == null
                          ? loc.reportAddBackPhoto
                          : loc.reportChangePhoto,
                      onPick: _pickBackPhoto,
                    ),

                    const SizedBox(height: 28),

                    // ── Product Name section ─────────────────────
                    Text(
                      'Product Name',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
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
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: colorScheme.primary, width: 1.5),
                        ),
                        hintText: 'Enter product name',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _productName = value);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kindly state the brand, name, and flavor (eg. Purefoods Corned Beef).',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Category section ─────────────────────────
                    Text(
                      'Category',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: _categories.map((category) {
                        return RadioListTile<String>(
                          title: Text(
                            category,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          value: category,
                          groupValue: _selectedCategory,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                          activeColor: colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // ── Info note card ────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50, // Pale green for welcoming feel
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.green.shade700, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              loc.reportInfoNote,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.green.shade900,
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
                        onPressed: canSubmit ? _handleSubmit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor:
                              colorScheme.primary.withValues(alpha: 0.4),
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