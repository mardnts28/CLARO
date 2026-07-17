import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';

/// A screen showing additional product details:
/// - Ingredients list with allergen warnings
/// - Storage instructions / tips
class MoreDetailsScreen extends StatefulWidget {
  final Product product;

  const MoreDetailsScreen({super.key, required this.product});

  @override
  State<MoreDetailsScreen> createState() => _MoreDetailsScreenState();
}

class _MoreDetailsScreenState extends State<MoreDetailsScreen> {
  String? _dynamicStorageText;
  bool _loadingStorage = true;

  @override
  void initState() {
    super.initState();
    _fetchStorageInstructions();
  }

  Future<void> _fetchStorageInstructions() async {
    if (widget.product.category.isEmpty) {
      if (mounted) setState(() => _loadingStorage = false);
      return;
    }
    
    try {
      final docId = widget.product.category.toLowerCase().replaceAll(' ', '_');
      final doc = await FirebaseFirestore.instance.collection('categories').doc(docId).get();
      if (doc.exists && mounted) {
        setState(() {
          _dynamicStorageText = doc.data()?['default_storage'];
          _loadingStorage = false;
        });
      } else if (mounted) {
        setState(() => _loadingStorage = false);
      }
    } catch (e) {
      debugPrint('Error fetching storage instructions: $e');
      if (mounted) setState(() => _loadingStorage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          loc.moreDetailsScreenTitle,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ── Ingredients Card ──────────────────────────────────
            _buildSectionCard(
              context: context,
              icon: Icons.chat_bubble,
              iconColor: const Color(0xFFB71C1C),
              title: loc.ingredientsTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    product.ingredients.isNotEmpty
                        ? product.ingredients.join(', ')
                        : '—',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  // Allergen warnings
                  if (product.allergens.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...product.allergens.map((allergen) {
                      final langCode = Localizations.localeOf(context).languageCode;
                      final displayName = _getAllergenDisplayName(allergen, langCode);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF9A9A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Color(0xFFC62828), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.containsAllergenPrefix(displayName),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFC62828),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Storage Instructions Card ─────────────────────────
            _buildSectionCard(
              context: context,
              icon: Icons.storefront_rounded,
              iconColor: const Color(0xFFB71C1C),
              title: loc.storageTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (_loadingStorage)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_dynamicStorageText != null && _dynamicStorageText!.isNotEmpty)
                    _buildStorageTip(
                      context: context,
                      icon: Icons.info_outline,
                      text: _dynamicStorageText!,
                    )
                  else ...[
                    _buildStorageTip(
                      context: context,
                      icon: Icons.wb_sunny_outlined,
                      text: loc.storageTipCool,
                    ),
                    const SizedBox(height: 14),
                    _buildStorageTip(
                      context: context,
                      icon: Icons.ac_unit,
                      text: loc.storageTipRefrigerate,
                    ),
                    const SizedBox(height: 14),
                    _buildStorageTip(
                      context: context,
                      icon: Icons.access_time,
                      text: loc.storageTipConsume,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  /// Builds a card section with an icon + title header.
  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5D5C5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  /// Builds a single storage tip row with an icon and text.
  Widget _buildStorageTip({
    required BuildContext context,
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Returns the localized display name for a given allergen string.
  String _getAllergenDisplayName(String allergen, String langCode) {
    final normalized = allergen.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final isTagalog = langCode == 'tl';

    switch (normalized) {
      case 'fish':
      case 'isda':
        return isTagalog ? 'isda' : 'fish';
      case 'milk':
      case 'gatas':
        return isTagalog ? 'gatas' : 'milk';
      case 'egg':
      case 'itlog':
        return isTagalog ? 'itlog' : 'egg';
      case 'soy':
      case 'soya':
      case 'soybean':
        return isTagalog ? 'soya' : 'soy';
      case 'wheat':
      case 'trigo':
        return isTagalog ? 'trigo (wheat)' : 'wheat';
      case 'shellfish':
      case 'lamangdagat':
        return isTagalog ? 'lamang-dagat' : 'shellfish';
      case 'peanut':
      case 'mani':
        return isTagalog ? 'mani' : 'peanut';
      default:
        return allergen;
    }
  }
}
