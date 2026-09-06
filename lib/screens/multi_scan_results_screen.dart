import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/voice_assistant_service.dart';
import 'product_detail_screen.dart';
import 'camera_scanner_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_mic_overlay.dart';
import '../data/models/ranked_product_result.dart';
import '../data/models/health_profile.dart';
import '../core/utils/nutrition_availability.dart';
import '../data/services/backend_locator.dart';
import '../widgets/ranked_product_card.dart';
import '../widgets/selectable_scanned_product_card.dart';
import '../services/home_tab_controller.dart';
import '../services/haptic_service.dart';
import '../core/utils/success_feedback_utils.dart';

class MultiScanResultsScreen extends StatefulWidget {
  final List<Product> detectedProducts;
  final Map<String, int>? productCounts;

  const MultiScanResultsScreen({
    super.key,
    required this.detectedProducts,
    this.productCounts,
  });

  @override
  State<MultiScanResultsScreen> createState() => _MultiScanResultsScreenState();
}

class _MultiScanResultsScreenState extends State<MultiScanResultsScreen> {
  final _authService = AuthService();

  bool _loading = true;
  bool _nutritionUnavailable = false;
  List<RankedProductResult> _ranked = [];

  // Full profile (so the filter sheet knows every condition the user has)
  // and the fixed detected-products list (so re-ranking on filter change is
  // free/pure-Dart -- no re-fetch, no re-detection). Mirrors
  // compare_products_screen.dart's filter-by-condition behavior; the
  // product source here (widget.detectedProducts, from image recognition)
  // and ranking source (ProductRankingService.rankProducts) are unchanged.
  UserHealthProfile? _profile;

  // null == "Overall" (all of the user's conditions). Non-null == ranking
  // narrowed to that single condition.
  HealthCondition? _selectedCondition;

  // Comparison products set that can be extended via "Add Product" button
  // (mirrors CompareProductsScreen._comparisonProducts). Starts as a copy
  // of widget.detectedProducts and grows as new products are added.
  List<Product> _comparisonProducts = [];

  @override
  void initState() {
    super.initState();
    if (widget.detectedProducts.isNotEmpty) {
      VoiceAssistantService.setLatestScanProduct(widget.detectedProducts.first);
    }
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('multi_scan_results');
    }
    _comparisonProducts = List.from(widget.detectedProducts);
    _rankProducts();
  }

  // Ranks the scanned products via WhoCalculator (through
  // ProductRankingService.rankProducts), against the current user's saved
  // health profile. Free/pure-Dart -- no Gemini call happens here; that
  // only happens per-product once the user taps into a detail screen.
  Future<void> _rankProducts() async {
    try {
      // WhoCalculator.rankProducts scores/sorts this whole list relative to
      // each other -- a product with no real nutrition data (all-zero
      // defaults) would silently rank as "healthiest" and skew every other
      // product's comparison too. Detect that up front and skip ranking
      // entirely rather than feed it bad data; WhoCalculator/
      // ProductRankingService themselves are untouched.
      if (!NutritionAvailability.allAvailable(widget.detectedProducts)) {
        if (mounted) {
          setState(() {
            _nutritionUnavailable = true;
            _loading = false;
          });
        }
        return;
      }

      final uid = _authService.currentUser?.uid;
      // No conditions/allergies on record (e.g. not logged in) still
      // ranks meaningfully -- WhoCalculator falls back to general
      // WHO/FDA thresholds when a profile has no flagged conditions.
      final profile = uid == null
          ? const UserHealthProfile(
              userId: '',
              displayName: '',
              conditions: [],
              allergies: [],
            )
          : await BackendLocator.userRepository.getHealthProfile(uid);

      final ranked = BackendLocator.productRankingService.rankProducts(
        products: _comparisonProducts,
        user: profile,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _ranked = ranked;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error ranking scanned products: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Re-ranks the SAME detected-products set (no re-scan, no re-detection)
  /// against a health profile narrowed to just [condition] -- or the full
  /// profile when [condition] is null ("Overall"). Runs through the exact
  /// same ProductRankingService.rankProducts pipeline as the default
  /// ranking; only which condition(s) are on the profile changes.
  void _selectConditionFilter(HealthCondition? condition) {
    final profile = _profile;
    if (profile == null) return;

    final effectiveProfile = condition == null
        ? profile
        : UserHealthProfile(
            userId: profile.userId,
            displayName: profile.displayName,
            conditions: [condition],
            allergies: profile.allergies,
            voiceAssistant: profile.voiceAssistant,
          );

    final reRanked = BackendLocator.productRankingService.rankProducts(
      products: _comparisonProducts,
      user: effectiveProfile,
    );

    setState(() {
      _selectedCondition = condition;
      _ranked = reRanked;
    });
  }

  String _conditionLabel(HealthCondition condition) {
    final loc = AppLocalizations.of(context)!;
    switch (condition) {
      case HealthCondition.hypertension:
        return loc.conditionHypertension;
      case HealthCondition.diabetes:
        return loc.conditionDiabetes;
      case HealthCondition.heartCondition:
        return loc.conditionHeartCondition;
    }
  }

  void _showFilterSheet() {
    final profile = _profile;
    if (profile == null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  loc.filterConditionTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              RadioListTile<HealthCondition?>(
                value: null,
                groupValue: _selectedCondition,
                activeColor: colorScheme.primary,
                title: Text(loc.conditionOverall),
                onChanged: (value) {
                  Navigator.pop(sheetContext);
                  _selectConditionFilter(value);
                },
              ),
              for (final condition in HealthCondition.values)
                RadioListTile<HealthCondition?>(
                  value: condition,
                  groupValue: _selectedCondition,
                  activeColor: colorScheme.primary,
                  title: Text(_conditionLabel(condition)),
                  onChanged: (value) {
                    Navigator.pop(sheetContext);
                    _selectConditionFilter(value);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Launches the existing scanning flow (CameraScannerScreen, YOLO
  /// recognition + catalog lookup) in "return results" mode so this
  /// screen gets the recognized product(s) back directly instead of
  /// navigating away to ProductDetailScreen / MultiScanResultsScreen.
  Future<void> _openAddProductFlow() async {
    HapticService().vibrate();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScannerScreen(returnResultsOnDetect: true),
      ),
    );

    if (!mounted || result is! Map) return;

    final recognized = result['products'];
    if (recognized is! List) return;

    final products = recognized.whereType<Product>().toList();
    if (products.isEmpty) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.noNewProductsDetected)),
      );
      return;
    }

    _showAddProductSheet(products);
  }

  /// Bottom sheet for picking which recognized product(s) to add. Visual
  /// styling mirrors PersonalInfoScreen's Allergen Selector (Container
  /// with a top-rounded 20px sheet, cardColor background, 20px padding),
  /// and each row reuses HistoryScreen's product-card layout via
  /// SelectableScannedProductCard (image + name only, no timestamp).
  void _showAddProductSheet(List<Product> recognizedProducts) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    // De-dupe the scan results themselves (recognition can report the
    // same product more than once) before checking against the
    // already-ranked set.
    final Map<String, Product> distinctById = {
      for (final p in recognizedProducts) p.id: p,
    };
    final products = distinctById.values.toList();

    final existingIds = _comparisonProducts.map((p) => p.id).toSet();
    final Set<String> selectedIds = {};
    final bool anySelectable = products.any((p) => !existingIds.contains(p.id));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final hasSelection = selectedIds.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.selectProductsToAddTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!anySelectable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            loc.noNewProductsDetected,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final product = products[i];
                            final alreadyRanked = existingIds.contains(product.id);
                            return SelectableScannedProductCard(
                              product: product,
                              selected: selectedIds.contains(product.id),
                              alreadyRanked: alreadyRanked,
                              onTap: () {
                                HapticService().vibrate();
                                setSheetState(() {
                                  if (selectedIds.contains(product.id)) {
                                    selectedIds.remove(product.id);
                                  } else {
                                    selectedIds.add(product.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            disabledBackgroundColor:
                                colorScheme.primary.withOpacity(0.3),
                            disabledForegroundColor:
                                colorScheme.onPrimary.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // Disabled (per spec) until at least one product
                          // is selected -- selecting/deselecting a card
                          // toggles this via setSheetState above.
                          onPressed: hasSelection
                              ? () {
                                  final selectedProducts = products
                                      .where((p) => selectedIds.contains(p.id))
                                      .toList();
                                  Navigator.pop(sheetContext);
                                  _addProductsToRanking(selectedProducts);
                                }
                              : null,
                          child: Text(
                            loc.apply,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Folds newly-selected product(s) into the SAME ranking/comparison
  /// set this screen already manages -- not a separate ranking. Reuses
  /// the exact re-ranking pipeline _selectConditionFilter/rankProducts already
  /// runs on filter changes, so the newly added products are compared
  /// against the existing ones (and vice versa) exactly as if they'd
  /// been part of the initial comparison. Previously-ranked products are
  /// kept; duplicates (already in _comparisonProducts) are skipped.
  void _addProductsToRanking(List<Product> newProducts) {
    final profile = _profile;
    if (profile == null) return;

    final existingIds = _comparisonProducts.map((p) => p.id).toSet();
    final toAdd = <Product>[];
    for (final p in newProducts) {
      if (existingIds.contains(p.id)) continue; // duplicate guard
      if (toAdd.any((q) => q.id == p.id)) continue; // dupes within selection
      toAdd.add(p);
    }

    if (toAdd.isEmpty) return;

    _comparisonProducts = [..._comparisonProducts, ...toAdd];

    // Re-rank the combined set through the same pipeline used for every
    // other re-rank on this screen, preserving whatever condition filter
    // is currently active.
    _selectConditionFilter(_selectedCondition);

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    SuccessFeedbackUtils.showSuccessSnackBar(
      context,
      loc.productsAddedToRanking(toAdd.length),
    );
  }

  /// "Add Product" row -- lets the user scan another product (reusing
  /// CameraScannerScreen's existing recognition flow) and fold the
  /// result(s) into this SAME ranking via _addProductsToRanking, rather
  /// than starting a separate ranking/comparison elsewhere.
  Widget _buildAddProductButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () {
        HapticService().vibrate();
        _openAddProductFlow();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              loc.addProductButton,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: VoiceMicOverlay(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── Header bar: back, Resulta (perfectly centered Stack) ──
          Container(
            color: colorScheme.surface,
            height: topPadding + 56,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: topPadding,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered Title
                Text(
                  loc.resultsTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                // Left Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      HapticService().vibrate();
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.arrow_back,
                        color: colorScheme.primary, size: 24),
                  ),
                ),
                // Right Filter Ranking Button (matches compare_products_screen)
                if (_profile != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        HapticService().vibrate();
                        _showFilterSheet();
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.filter_list,
                              color: colorScheme.primary, size: 24),
                          if (_selectedCondition != null)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── Ranked description label ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  loc.rankedBySuitability,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectedCondition != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticService().vibrate();
                      _selectConditionFilter(null);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: colorScheme.secondary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _conditionLabel(_selectedCondition!),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close,
                              size: 14, color: colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (widget.detectedProducts.any((p) => p.isOfflineFallback))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFFE65100).withValues(alpha: 0.15)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFFFFB74D).withValues(alpha: 0.4)
                        : const Color(0xFFFFB74D).withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.offlineBasicRecognitionBanner,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFFFB74D)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Product list ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _nutritionUnavailable
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 40, color: colorScheme.onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text(
                                loc.nutritionDataUnavailable,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom + 24),
                    itemCount: _ranked.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == _ranked.length) {
                        return _buildAddProductButton();
                      }

                      final ranked = _ranked[i];
                      return RankedProductCard(
                        ranked: ranked,
                        quantity: widget.productCounts?[ranked.evaluation.product.id],
                        onTap: () {
                          // Navigate to the individual detail screen, passing
                          // the full ranked set so the detail screen can show
                          // the comparison matrix and ranking explanation for
                          // this scan event too.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: ranked.evaluation.product,
                                comparisonSet: _ranked,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          ],
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    // Active nav item uses a white pill in dark mode so it stands out
    // against the dark bottom bar background; the icon/text stay in
    // colorScheme.primary (a saturated red), which reads clearly on white.
    final navPillColor = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFFF6CDCD);

    final items = [
      (icon: Icons.home_outlined, activeIcon: Icons.home, label: loc.home),
      (icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner, label: loc.scan),
      (icon: Icons.history_outlined, activeIcon: Icons.history, label: loc.history),
      (icon: Icons.person_outline, activeIcon: Icons.person, label: loc.profile),
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
            // Multi-scan results are conceptually part of the 'Scan' journey
            final isSelected = index == 1;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticService().vibrate();
                  HomeTabController.tabNotifier.value = index;
                  Navigator.popUntil(context, (r) => r.isFirst);
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
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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