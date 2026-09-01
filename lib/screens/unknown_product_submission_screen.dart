import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/custom_text_field.dart';
import '../core/utils/sanitizing_text_input_formatter.dart';
import '../core/utils/success_feedback_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_assistant_fab.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/home_tab_controller.dart';
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
  final List<String> _additionalBackImagePaths = [];
  bool _isSubmitting = false;
  String? _nameError;
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
    if (VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('unknown_product_submission');
    }
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

  Future<void> _pickAdditionalBackPhoto() async {
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
        setState(() => _additionalBackImagePaths.add(picked.path));
      }
    } catch (e) {
      debugPrint('Additional back image pick error: $e');
    }
  }

  void _removeAdditionalBackPhoto(int index) {
    setState(() => _additionalBackImagePaths.removeAt(index));
  }

  // ── Submit report to Firestore ─────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    final loc = AppLocalizations.of(context)!;

    if (_backImagePath == null) {
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
      setState(() => _nameError = loc.pleaseEnterProductName);
      return;
    }
    setState(() => _nameError = null);

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      final uid = user?.uid ?? 'anonymous';
      final email = user?.email ?? '';

      // Firebase Auth's displayName is never set in this app (no
      // updateDisplayName() call anywhere) -- the user's actual name lives
      // in Firestore under users/{uid}.name, written during onboarding.
      // Falls back to the email prefix only if that document/field is
      // somehow missing (shouldn't happen for a signed-up user, but keeps
      // this from ever showing a raw UID if it does).
      String name = email.isNotEmpty ? email.split('@').first : 'Anonymous';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final fetchedName = userDoc.data()?['name'] as String?;
        if (fetchedName != null && fetchedName.trim().isNotEmpty) {
          name = fetchedName.trim();
        }
      } catch (e) {
        debugPrint('Could not fetch user name for report: $e');
        // Keep the email-prefix fallback set above -- don't block
        // submission over a profile lookup failure.
      }

      // Read photos safely -- front photo is optional if capturedImagePath was not provided
      Uint8List frontBytes = Uint8List(0);
      if (_frontImagePath != null && _frontImagePath!.isNotEmpty) {
        final frontFile = File(_frontImagePath!);
        if (await frontFile.exists()) {
          frontBytes = await frontFile.readAsBytes();
        }
      }
      final backBytes = await File(_backImagePath!).readAsBytes();

      // Upload additional back photos
      List<Uint8List> additionalBackBytesList = [];
      List<Future<String?>> additionalUploads = [];
      for (int i = 0; i < _additionalBackImagePaths.length; i++) {
        final additionalFile = File(_additionalBackImagePaths[i]);
        if (await additionalFile.exists()) {
          final additionalBytes = await additionalFile.readAsBytes();
          additionalBackBytesList.add(additionalBytes);
          additionalUploads.add(
            BackendLocator.cloudinaryUploadService.upload(
              additionalBytes,
              filename: '${uid}_back_additional_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
        }
      }

      // Upload in parallel. CloudinaryUploadService.upload() returns null
      // on failure rather than throwing -- we still let the report submit
      // with a blank URL in that case (see its header comment) rather than
      // blocking the whole submission on an image host hiccup.
      final uploads = await Future.wait([
        frontBytes.isNotEmpty
            ? BackendLocator.cloudinaryUploadService.upload(
                frontBytes,
                filename: '${uid}_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
              )
            : Future<String?>.value(''),
        BackendLocator.cloudinaryUploadService.upload(
          backBytes,
          filename: '${uid}_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        ...additionalUploads,
      ]);
      final frontUrl = uploads[0] ?? '';
      final backUrl = uploads[1] ?? '';
      final additionalBackUrls = uploads.skip(2)
          .where((url) => url != null && url.isNotEmpty)
          .cast<String>()
          .toList();

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
        additionalBackImageUrls: additionalBackUrls,
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
      _runBackgroundExtraction(
        docRef.id,
        frontBytes,
        backBytes,
        additionalBackBytesList,
      );
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
    List<Uint8List> additionalBackBytes,
  ) async {
    try {
      final result = await BackendLocator.productExtractionService.extract(
        frontImageBytes: frontBytes,
        backImageBytes: backBytes,
        additionalBackImageBytes: additionalBackBytes,
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
    final loc = AppLocalizations.of(context)!;
    SuccessFeedbackUtils.showSuccessDialog(
      context,
      title: loc.reportSuccessTitle,
      message: loc.reportSuccessBody,
      buttonText: loc.reportGoHome,
      onDismiss: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  // ── Reusable photo block (front or back) ────────────────────────────────
  Widget _photoBlock({
    required ColorScheme colorScheme,
    required Color primaryColor,
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
            color: primaryColor,
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
        // `Expanded` around the button (instead of letting it size to its
        // unwrapped intrinsic width) is what actually fixes the overflow:
        // longer labels -- e.g. the Tagalog "Baguhin ang Litrato" /
        // "Magdagdag ng Litrato" vs. English "Change Photo" / "Add Photo"
        // -- now wrap and share the remaining row width instead of pushing
        // past the screen edge ("RIGHT OVERFLOWED BY 34 PIXELS").
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
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: Icon(Icons.camera_alt_outlined, size: 18, color: primaryColor),
                label: Text(
                  buttonLabel,
                  softWrap: true,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  alignment: Alignment.center,
                ),
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
    final primaryColor = theme.brightness == Brightness.dark
        ? Colors.red
        : colorScheme.primary;
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
                      color: primaryColor, size: 26),
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
                      primaryColor: primaryColor,
                      label: loc.reportFrontPhoto,
                      imagePath: _frontImagePath,
                      buttonLabel: _frontImagePath == null
                          ? loc.reportAddBackPhoto
                          : loc.reportChangePhoto,
                      onPick: _changeFrontPhoto,
                    ),

                    const SizedBox(height: 28),

                    // ── Back Photo section (required) ─────────────
                    _photoBlock(
                      colorScheme: colorScheme,
                      primaryColor: primaryColor,
                      label: loc.reportBackPhoto,
                      hint: loc.reportBackPhotoHint,
                      imagePath: _backImagePath,
                      buttonLabel: _backImagePath == null
                          ? loc.reportAddBackPhoto
                          : loc.reportChangePhoto,
                      onPick: _pickBackPhoto,
                    ),

                    const SizedBox(height: 28),

                    // ── Additional Back Photos section (optional) ────
                    Text(
                      loc.reportAdditionalBackPhotos,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.reportAdditionalBackPhotosHint,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Display additional back photos
                    if (_additionalBackImagePaths.isNotEmpty) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(_additionalBackImagePaths.length, (index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  child: Image.file(
                                    File(_additionalBackImagePaths[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeAdditionalBackPhoto(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.9),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Add additional photo button
                    OutlinedButton.icon(
                      onPressed: _pickAdditionalBackPhoto,
                      icon: Icon(Icons.add_photo_alternate_outlined, size: 18, color: colorScheme.primary),
                      label: Text(
                        loc.reportAddAnotherBackPhoto,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Product Name section ─────────────────────
                    Text(
                      loc.productName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Enter product name',
                      errorText: _nameError,
                      inputFormatters: [SanitizingTextInputFormatter()],
                      onChanged: (value) {
                        if (_nameError != null) setState(() => _nameError = null);
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
                      loc.category,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
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
                          activeColor: primaryColor,
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
                        color: theme.brightness == Brightness.dark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? colorScheme.outlineVariant
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: theme.brightness == Brightness.dark
                                  ? primaryColor
                                  : Colors.green.shade700, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              loc.reportInfoNote,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: theme.brightness == Brightness.dark
                                    ? colorScheme.onSurface
                                    : Colors.green.shade900,
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
                          backgroundColor: primaryColor,
                          foregroundColor: colorScheme.onPrimary,
                          disabledBackgroundColor:
                              primaryColor.withValues(alpha: 0.4),
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
    // Active nav item uses a white pill in dark mode so it stands out
    // against the dark bottom bar background; the icon/text stay in
    // colorScheme.primary (a saturated red), which reads clearly on white.
    final navPillColor = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFFF6CDCD);

    final items = [
      (icon: Icons.home_outlined, label: loc.home),
      (icon: Icons.qr_code_scanner, label: loc.scan),
      (icon: Icons.history_outlined, label: loc.history),
      (icon: Icons.person_outline, label: loc.profile),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            final item = items[index];
            // "Scan" stays highlighted here since this screen is reached
            // from the scan flow (via Product Not Found), matching the
            // same convention used by Product Not Found's own nav.
            final isSelected = index == 1;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Reuses the same tab-switch + pop-to-root navigation as
                  // the other main screens (see HistoryScreen) so bottom
                  // nav taps actually work from this screen instead of
                  // being visually present but non-functional.
                  HapticService().vibrate();
                  HomeTabController.switchToTab(index);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? navPillColor : Colors.transparent,
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
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}