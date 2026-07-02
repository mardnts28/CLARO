import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          content: Text("Mock product image captured successfully!", style: GoogleFonts.inter(color: Colors.black)),
          backgroundColor: const Color(0xFF00c6ff),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _handleSubmit() {
    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please capture or upload a product label photo first.", style: GoogleFonts.inter(color: Colors.white)),
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
          backgroundColor: const Color(0xFF161B26),
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
                      color: const Color(0xFF38ef7d).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Color(0xFF38ef7d),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Submission Received",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Thank you! Our AI team will verify this product label and update the on-device YOLOv8 database model within 24 hours.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
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
                        backgroundColor: const Color(0xFF00c6ff),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Return to Scanner",
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
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SUBMIT UNKNOWN SKU",
          style: GoogleFonts.outfit(
            color: Colors.white,
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
                "Help Train Our Model",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "If a product isn't detected by our camera, upload its photo and info. Our engine uses this data to refine label mapping.",
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(128),
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
                    color: const Color(0xFF161B26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasImage 
                          ? const Color(0xFF38ef7d).withOpacity(0.5) 
                          : const Color(0xFF1F2937),
                      width: 1.5,
                    ),
                  ),
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00c6ff)))
                      : _hasImage
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Color(0xFF38ef7d), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  "Label Image Attached",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tap to replace photo",
                                  style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_outlined, color: Color(0xFF00c6ff), size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  "Capture Product Label (Front/Rear)",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Ensure text/nutrition facts are readable",
                                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Product Name
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _buildInputDecoration("Product Name / Description", Icons.info_outline),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter product name";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Brand Name
              TextFormField(
                controller: _brandController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _buildInputDecoration("Brand Name (e.g. Century, Ligo, Lucky Me)", Icons.branding_watermark_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter brand name";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Variant
              TextFormField(
                controller: _variantController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _buildInputDecoration("Product Variant (e.g. Hot & Spicy, Sweet & Sour)", Icons.style_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter product variant";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF161B26),
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _buildInputDecoration("Product Category", Icons.category_outlined),
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat, style: GoogleFonts.inter(color: Colors.white)),
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
                style: GoogleFonts.inter(color: Colors.white),
                decoration: _buildInputDecoration("Ingredients List (Optional)", Icons.receipt_long_outlined),
              ),
              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00c6ff),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          "SUBMIT FOR TRAINING",
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
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: const Color(0xFF161B26),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF00c6ff), width: 1.5),
      ),
    );
  }
}
