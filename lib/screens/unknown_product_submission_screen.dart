import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';

class UnknownProductSubmissionScreen extends StatefulWidget {
  const UnknownProductSubmissionScreen({super.key});

  @override
  State<UnknownProductSubmissionScreen> createState() => _UnknownProductSubmissionScreenState();
}

class _UnknownProductSubmissionScreenState extends State<UnknownProductSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _variantController = TextEditingController();
  final _ingredientsController = TextEditingController();
  
  String _selectedCategory = "Canned Fish";
  bool _isUploadingImage = false;
  bool _hasImage = false;
  bool _isSubmitting = false;

  final List<String> _categories = [
    "Canned Fish",
    "Canned Meat",
    "Instant Noodles",
    "Other Canned Food",
    "Other Noodles"
  ];

  void _simulateImageCapture() {
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _isUploadingImage = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
        _hasImage = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.imageCaptureSuccess, style: GoogleFonts.inter(color: Colors.black)),
          backgroundColor: const Color(0xFF00c6ff),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _handleSubmit() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.imageRequiredError, style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });

        // Show thank you modal/sheet
        showModalBottomSheet(
          context: context,
          backgroundColor: theme.cardColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.submissionReceivedTitle,
                    style: GoogleFonts.outfit(
                      color: colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.submissionReceivedDesc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // close sheet
                        Navigator.pop(context); // back to scanner screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        loc.returnToScanner,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _variantController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.submitSkuHeader,
          style: GoogleFonts.outfit(
            color: colorScheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.trainModelHeadline,
                style: GoogleFonts.outfit(
                  color: colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.trainModelSubtitle,
                style: GoogleFonts.inter(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Image Capture Target Box
              GestureDetector(
                onTap: _simulateImageCapture,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasImage 
                          ? Colors.green.withOpacity(0.5) 
                          : theme.dividerColor,
                      width: 1.5,
                    ),
                  ),
                  child: _isUploadingImage
                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                      : _hasImage
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  loc.labelImageAttached,
                                  style: GoogleFonts.outfit(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc.tapToReplace,
                                  style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 11),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: colorScheme.primary, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  loc.captureProductLabel,
                                  style: GoogleFonts.outfit(
                                    color: colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc.ensureReadableNote,
                                  style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 11),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Product Name
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.inter(color: colorScheme.onSurface),
                decoration: _buildInputDecoration(loc.productNameLabel, Icons.info_outline),
                validator: (value) {
                  if (value == null || value.isEmpty) return loc.productNameEmpty;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Brand Name
              TextFormField(
                controller: _brandController,
                style: GoogleFonts.inter(color: colorScheme.onSurface),
                decoration: _buildInputDecoration(loc.brandNameLabel, Icons.branding_watermark_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) return loc.brandNameEmpty;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Variant
              TextFormField(
                controller: _variantController,
                style: GoogleFonts.inter(color: colorScheme.onSurface),
                decoration: _buildInputDecoration(loc.productVariantLabel, Icons.style_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) return loc.productVariantEmpty;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: theme.cardColor,
                style: GoogleFonts.inter(color: colorScheme.onSurface),
                decoration: _buildInputDecoration(loc.productCategoryLabel, Icons.category_outlined),
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat, style: GoogleFonts.inter(color: colorScheme.onSurface)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Ingredients
              TextFormField(
                controller: _ingredientsController,
                maxLines: 4,
                style: GoogleFonts.inter(color: colorScheme.onSurface),
                decoration: _buildInputDecoration(loc.ingredientsListLabel, Icons.receipt_long_outlined),
              ),
              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator(color: colorScheme.onPrimary)
                      : Text(
                          loc.submitTrainingButton,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: colorScheme.onSurfaceVariant, fontSize: 13),
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }
}
