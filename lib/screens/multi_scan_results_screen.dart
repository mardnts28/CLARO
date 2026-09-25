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
import '../core/utils/product_characteristics.dart';
import '../data/services/backend_locator.dart';
import '../widgets/ranked_product_card.dart';
import '../widgets/selectable_scanned_product_card.dart';
import '../services/home_tab_controller.dart';
import '../services/haptic_service.dart';
import '../core/utils/success_feedback_utils.dart';

/// Soft drop shadow used everywhere an outline/border used to be.
List<BoxShadow> _softShadow(ThemeData theme, {double blur = 14, double dy = 5}) {
  final isDark = theme.brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.16),
      blurRadius: blur,
      spreadRadius: 0,
      offset: Offset(0, dy),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.07),
      blurRadius: blur * 0.45,
      spreadRadius: 0,
      offset: Offset(0, dy * 0.35),
    ),
  ];
}

/// Opaque version of a translucent tint (tint blended over the scaffold
/// background). Needed because a BoxShadow shows through translucent fills,
/// so tinted containers that now carry a shadow must have an opaque fill.
Color _tint(ThemeData theme, Color tint, double opacity) =>
    Color.alphaBlend(tint.withValues(alpha: opacity), theme.scaffoldBackgroundColor);

class MultiScanResultsScreen extends StatefulWidget {
  final List<Product> detectedProducts;
  final Map<String, int>? productCounts;
  final bool isSearchResult;
  final bool showOfflineNotice;

  const MultiScanResultsScreen({
    super.key,
    required this.detectedProducts,
    this.productCounts,
    this.isSearchResult = false,
    this.showOfflineNotice = false,
  });

  @override
  State<MultiScanResultsScreen> createState() => _MultiScanResultsScreenState();
}

class _MultiScanResultsScreenState extends State<MultiScanResultsScreen> {
  final _authService = AuthService();

  bool _loading = true;
  bool _nutritionUnavailable = false;

  // Full re-ranked set (health-condition scoring applied) and the subset
  // of it actually shown after Product Type / Flavor tag filters are
  // layered on top. Mirrors CompareProductsScreen's _allRanked/_filtered
  // split: tag filtering only narrows which re-ranked results are
  // displayed, it never changes their order.
  List<RankedProductResult> _allRanked = [];
  List<RankedProductResult> _filtered = [];

  // Full profile (so the filter sheet knows every condition the user has)
  // and the fixed detected-products list (so re-ranking on filter change is
  // free/pure-Dart -- no re-fetch, no re-detection). Mirrors
  // compare_products_screen.dart's filter-by-condition behavior; the
  // product source here (widget.detectedProducts, from image recognition)
  // and ranking source (ProductRankingService.rankProducts) are unchanged.
  UserHealthProfile? _profile;

  // Multi-select, same as CompareProductsScreen: empty set == "Overall"
  // (rank against the full saved profile). Non-empty narrows the
  // effective profile to just those condition(s), which can be one or
  // several at once.
  Set<HealthCondition> _selectedConditions = {};

  // Product Type / Flavor filter chips -- membership filters (hide
  // non-matching products) layered on top of the health-condition
  // re-ranking above. Multi-select within each group (OR): e.g. selecting
  // both "Chicken" and "Beef" shows either. Between groups (type AND
  // flavor) it's AND: selecting "Chicken" + "Spicy" shows only spicy
  // chicken products. Ported from CompareProductsScreen -- same
  // ProductCharacteristics keyword lists, same facet semantics.
  static const String _spicyTag = '__spicy__';
  static const String _nonSpicyTag = '__non_spicy__';

  final Set<String> _selectedTypeTags = {};
  final Set<String> _selectedFlavorTags = {};

  // A multi-scan result can contain products from several different
  // categories at once (e.g. a drink and a snack scanned together),
  // unlike CompareProductsScreen where every product shares
  // sourceProduct.category by construction. When that happens, each
  // distinct category becomes an extra selectable option inside the
  // Product Type filter group (tagged so it doesn't collide with a
  // ProductCharacteristics type keyword of the same name).
  static const String _categoryTagPrefix = '__category__:';
  String _categoryTag(String category) => '$_categoryTagPrefix$category';
  bool _isCategoryTag(String tag) => tag.startsWith(_categoryTagPrefix);

  // Chip OPTIONS shown in the filter sheet -- derived once (and
  // recomputed whenever the comparison set grows) from the actual
  // products in this set, so a chip never appears for a tag that has
  // zero matches in the current results.
  Set<String> _availableTypeTags = {};
  Set<String> _availableFlavorTags = {};
  bool _hasSpicyOption = false;

  bool get _hasActiveTagFilters =>
      _selectedTypeTags.isNotEmpty || _selectedFlavorTags.isNotEmpty;

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
    if (_authService.currentUser != null &&
        VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('multi_scan_results');
    }
    _comparisonProducts = List.from(widget.detectedProducts);
    _rankProducts();
    if (widget.showOfflineNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOfflineNotice();
      });
    }
  }

  Future<void> _showOfflineNotice() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    await SuccessFeedbackUtils.showOfflineNoticeDialog(
      context,
      title: loc.noInternetTitle,
      message: loc.noInternetNutritionMessage,
      buttonText: loc.gotIt,
      onDismiss: () {
        if (mounted) Navigator.pop(context);
      },
    );
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
      if (!widget.isSearchResult &&
          !NutritionAvailability.allAvailable(widget.detectedProducts)) {
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
          : await _loadProfileOrDefault(uid);

      final ranked = BackendLocator.productRankingService.rankProducts(
        products: _comparisonProducts,
        user: profile,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _allRanked = ranked;
        _filtered = _computeFiltered(ranked);
        _loading = false;
        _computeAvailableTags();
        // `ranked` above was already scored against the full saved
        // profile, so pre-checking whichever of the deterministic
        // conditions the user actually has doesn't require a re-rank --
        // it just reflects, in the filter UI, the same ranking already
        // shown. Matches CompareProductsScreen's default.
        _selectedConditions = HealthCondition.values
            .where((c) => c.isScored && profile.conditions.contains(c))
            .toSet();
      });
    } catch (e) {
      debugPrint('Error ranking scanned products: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<UserHealthProfile> _loadProfileOrDefault(String uid) async {
    try {
      return await BackendLocator.userRepository.getHealthProfile(uid);
    } catch (e) {
      // Product search should still show matching products when health-profile
      // data is temporarily unavailable; rank them without condition filters.
      debugPrint('Health profile unavailable during product search: $e');
      return UserHealthProfile(
        userId: uid,
        displayName: '',
        conditions: const [],
        allergies: const [],
      );
    }
  }

  /// Scans the fixed comparison set once (after load, and again whenever it
  /// grows via "Add Product") to find which Product Type / Flavor keywords
  /// actually occur in it -- these become the chip options offered in the
  /// filter sheet. "Spicy" is offered separately (as a Spicy/Non-Spicy
  /// toggle) whenever at least one product in the set matches a spicy
  /// keyword. Ported verbatim from CompareProductsScreen.
  void _computeAvailableTags() {
    final typeTags = <String>{};
    final flavorTags = <String>{};
    var hasSpicy = false;

    for (final product in _comparisonProducts) {
      typeTags.addAll(ProductCharacteristics.typeTags(product));
      final flavors = ProductCharacteristics.flavorTags(product);
      flavorTags.addAll(
        flavors.where((f) => !ProductCharacteristics.spicyKeywords.contains(f)),
      );
      if (flavors.any(ProductCharacteristics.spicyKeywords.contains)) {
        hasSpicy = true;
      }
    }

    // Only surface category as a Product Type option when this scan
    // actually mixes categories -- a single-category scan (the common
    // case, and CompareProductsScreen's case) has nothing to disambiguate
    // and shouldn't show a one-option "filter".
    final categories = _comparisonProducts.map((p) => p.category).toSet();
    if (categories.length > 1) {
      typeTags.addAll(categories.map(_categoryTag));
    }

    _availableTypeTags = typeTags;
    _availableFlavorTags = flavorTags;
    _hasSpicyOption = hasSpicy;
  }

  /// True if [product] matches the currently-selected Product Type /
  /// Flavor filters. Same faceted semantics as CompareProductsScreen:
  /// Product Type tags OR'd together; Flavor is two independent facets
  /// (Spicy/Non-Spicy toggle, and flavor keyword chips OR'd among
  /// themselves) that must each pass when selected; Product Type and
  /// Flavor combine with AND.
  bool _matchesTagFilters(Product product) {
    if (_selectedTypeTags.isNotEmpty) {
      final productTypeTags = {
        ...ProductCharacteristics.typeTags(product),
        _categoryTag(product.category),
      };
      if (productTypeTags.intersection(_selectedTypeTags).isEmpty) {
        return false;
      }
    }

    if (_selectedFlavorTags.isNotEmpty) {
      final productFlavorTags = ProductCharacteristics.flavorTags(product);
      final isSpicy = ProductCharacteristics.isSpicy(product);

      final spicySelection = _selectedFlavorTags.intersection({
        _spicyTag,
        _nonSpicyTag,
      });
      final keywordSelection = _selectedFlavorTags.difference({
        _spicyTag,
        _nonSpicyTag,
      });

      if (spicySelection.isNotEmpty) {
        final matchesSpicy = spicySelection.any((tag) {
          if (tag == _spicyTag) return isSpicy;
          return !isSpicy; // _nonSpicyTag
        });
        if (!matchesSpicy) return false;
      }

      if (keywordSelection.isNotEmpty) {
        if (!keywordSelection.any(productFlavorTags.contains)) {
          return false;
        }
      }
    }

    return true;
  }

  List<RankedProductResult> _computeFiltered(List<RankedProductResult> source) {
    if (!_hasActiveTagFilters) return source;
    return source.where((r) => _matchesTagFilters(r.evaluation.product)).toList();
  }

  /// Re-ranks the SAME detected-products set (no re-scan, no re-detection)
  /// against a health profile narrowed to [conditions] -- or the full
  /// profile when [conditions] is empty ("Overall") -- and applies the
  /// given Product Type / Flavor tag selections. Runs through the exact
  /// same ProductRankingService.rankProducts pipeline as the default
  /// ranking; tag filtering happens afterward, in _computeFiltered -- it
  /// narrows which of the re-ranked results are shown, it never changes
  /// their order. Ported from CompareProductsScreen._reRankAndFilter.
  void _reRankAndFilter({
    required Set<HealthCondition> conditions,
    required Set<String> typeTags,
    required Set<String> flavorTags,
  }) {
    final profile = _profile;
    if (profile == null) return;

    final effectiveProfile = conditions.isEmpty
        ? profile
        : UserHealthProfile(
            userId: profile.userId,
            displayName: profile.displayName,
            conditions: conditions.toList(),
            allergies: profile.allergies,
            voiceAssistant: profile.voiceAssistant,
          );

    final reRanked = BackendLocator.productRankingService.rankProducts(
      products: _comparisonProducts,
      user: effectiveProfile,
    );

    setState(() {
      _selectedConditions
        ..clear()
        ..addAll(conditions);
      _selectedTypeTags
        ..clear()
        ..addAll(typeTags);
      _selectedFlavorTags
        ..clear()
        ..addAll(flavorTags);
      _allRanked = reRanked;
      _filtered = _computeFiltered(reRanked);
    });
  }

  /// Removes a single condition from the current multi-select, keeping
  /// the rest of the selection (and the Product Type/Flavor filters)
  /// untouched.
  void _removeConditionTag(HealthCondition condition) {
    final updated = Set<HealthCondition>.from(_selectedConditions)
      ..remove(condition);
    _reRankAndFilter(
      conditions: updated,
      typeTags: _selectedTypeTags,
      flavorTags: _selectedFlavorTags,
    );
  }

  void _removeTypeTag(String tag) {
    final updated = Set<String>.from(_selectedTypeTags)..remove(tag);
    _reRankAndFilter(
      conditions: _selectedConditions,
      typeTags: updated,
      flavorTags: _selectedFlavorTags,
    );
  }

  void _removeFlavorTag(String tag) {
    final updated = Set<String>.from(_selectedFlavorTags)..remove(tag);
    _reRankAndFilter(
      conditions: _selectedConditions,
      typeTags: _selectedTypeTags,
      flavorTags: updated,
    );
  }

  /// Display label for a selected/available Product Type or Flavor tag.
  String _tagLabel(String tag) {
    final loc = AppLocalizations.of(context)!;
    if (tag == _spicyTag) return loc.spicyLabel;
    if (tag == _nonSpicyTag) return loc.nonSpicyLabel;
    if (_isCategoryTag(tag)) return tag.substring(_categoryTagPrefix.length);
    return ProductCharacteristics.displayLabel(tag);
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
      case HealthCondition.gerd:
        return loc.conditionGerd;
      case HealthCondition.kidneyDisease:
        return loc.conditionKidneyDisease;
    }
  }

  void _showFilterSheet() {
    final profile = _profile;
    if (profile == null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    // Local, transient copies -- edited freely while the sheet is open,
    // only committed to screen state when "Apply" is tapped. "Clear All"
    // resets these (and the sheet's view of itself) without touching the
    // screen until Apply/Clear is actually pressed.
    final tempConditions = Set<HealthCondition>.from(_selectedConditions);
    final tempTypeTags = Set<String>.from(_selectedTypeTags);
    final tempFlavorTags = Set<String>.from(_selectedFlavorTags);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget sectionTitle(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            );

            Widget tagChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  HapticService().vibrate();
                  onTap();
                },
                selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                checkmarkColor: colorScheme.primary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                ),
                side: BorderSide.none,
                elevation: selected ? 3 : 2,
                pressElevation: 1,
                shadowColor: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.6 : 0.35,
                ),
                selectedShadowColor: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.6 : 0.35,
                ),
                backgroundColor: colorScheme.surface,
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionTitle(loc.filterConditionTitle),
                    // Multi-select: any combination of the conditions can
                    // be checked at once (e.g. Diabetes + Heart Condition
                    // together). Only deterministic scored conditions can
                    // re-rank products.
                    for (final condition in HealthCondition.values.where(
                      (c) => c.isScored,
                    ))
                      CheckboxListTile(
                        value: tempConditions.contains(condition),
                        activeColor: colorScheme.primary,
                        title: Text(_conditionLabel(condition)),
                        onChanged: (checked) {
                          HapticService().vibrate();
                          setSheetState(() {
                            if (checked == true) {
                              tempConditions.add(condition);
                            } else {
                              tempConditions.remove(condition);
                            }
                          });
                        },
                      ),

                    // ── Product Type (only shown if this comparison set
                    // actually has products with a curated type tag) ────
                    if (_availableTypeTags.isNotEmpty) ...[
                      sectionTitle(loc.filterProductTypeTitle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            for (final tag in _availableTypeTags)
                              tagChip(
                                label: _tagLabel(tag),
                                selected: tempTypeTags.contains(tag),
                                onTap: () => setSheetState(() {
                                  if (!tempTypeTags.remove(tag)) {
                                    tempTypeTags.add(tag);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Flavor (spicy/non-spicy toggle + any other
                    // curated flavor tags actually present) ─────────────
                    if (_hasSpicyOption || _availableFlavorTags.isNotEmpty) ...[
                      sectionTitle(loc.filterFlavorTitle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            if (_hasSpicyOption) ...[
                              tagChip(
                                label: loc.spicyLabel,
                                selected: tempFlavorTags.contains(_spicyTag),
                                onTap: () => setSheetState(() {
                                  if (!tempFlavorTags.remove(_spicyTag)) {
                                    tempFlavorTags
                                      ..remove(_nonSpicyTag)
                                      ..add(_spicyTag);
                                  }
                                }),
                              ),
                              tagChip(
                                label: loc.nonSpicyLabel,
                                selected: tempFlavorTags.contains(_nonSpicyTag),
                                onTap: () => setSheetState(() {
                                  if (!tempFlavorTags.remove(_nonSpicyTag)) {
                                    tempFlavorTags
                                      ..remove(_spicyTag)
                                      ..add(_nonSpicyTag);
                                  }
                                }),
                              ),
                            ],
                            for (final tag in _availableFlavorTags)
                              tagChip(
                                label: _tagLabel(tag),
                                selected: tempFlavorTags.contains(tag),
                                onTap: () => setSheetState(() {
                                  if (!tempFlavorTags.remove(tag)) {
                                    tempFlavorTags.add(tag);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 4,
                                shadowColor: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark ? 0.55 : 0.20,
                                ),
                                backgroundColor: colorScheme.surface,
                                foregroundColor: colorScheme.onSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => setSheetState(() {
                                tempConditions.clear();
                                tempTypeTags.clear();
                                tempFlavorTags.clear();
                              }),
                              child: Text(loc.clearAll),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _reRankAndFilter(
                                  conditions: tempConditions,
                                  typeTags: tempTypeTags,
                                  flavorTags: tempFlavorTags,
                                );
                              },
                              child: Text(loc.apply),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.noNewProductsDetected)));
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final product = products[i];
                            final alreadyRanked = existingIds.contains(
                              product.id,
                            );
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
                            disabledBackgroundColor: colorScheme.primary
                                .withValues(alpha: 0.3),
                            disabledForegroundColor: colorScheme.onPrimary
                                .withValues(alpha: 0.7),
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
  /// the exact re-ranking pipeline _reRankAndFilter/rankProducts already
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
    _computeAvailableTags();

    // Re-rank the combined set through the same pipeline used for every
    // other re-rank on this screen, preserving whatever condition /
    // Product Type / Flavor filters are currently active.
    _reRankAndFilter(
      conditions: _selectedConditions,
      typeTags: _selectedTypeTags,
      flavorTags: _selectedFlavorTags,
    );

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
          color: _tint(theme, colorScheme.primary, 0.08),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _softShadow(theme),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: colorScheme.primary,
            ),
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

  Widget _buildRemovableChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _tint(theme, colorScheme.secondary, 0.12),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _softShadow(theme, blur: 9, dy: 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: colorScheme.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmpty() {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            loc.noProductsFound,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.noSearchMatchDesc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    // Offline banner colors (opaque so its shadow doesn't bleed through).
    final offlineBannerColor = isDark
        ? Color.alphaBlend(
            const Color(0xFFE65100).withValues(alpha: 0.15),
            theme.scaffoldBackgroundColor,
          )
        : const Color(0xFFFFF3E0);
    final offlineAccent = isDark
        ? const Color(0xFFFFB74D)
        : const Color(0xFFE65100);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: VoiceMicOverlay(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header bar: centered title with subtle shadow, matching the
            // ranking screens' consistent format. ──
            Container(
              height: topPadding + 56,
              padding: EdgeInsets.only(left: 16, right: 16, top: topPadding),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: _softShadow(theme, blur: 12, dy: 4),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    loc.resultsTitle,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        HapticService().vibrate();
                        Navigator.pop(context);
                      },
                      child: Icon(
                        Icons.arrow_back,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
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
                            Icon(
                              Icons.filter_list,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                            if (_selectedConditions.isNotEmpty ||
                                _hasActiveTagFilters)
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

            // ── Ranked description label + active filter chips ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    loc.rankedBySuitability,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  for (final condition in _selectedConditions)
                    _buildRemovableChip(
                      label: _conditionLabel(condition),
                      onRemove: () {
                        HapticService().vibrate();
                        _removeConditionTag(condition);
                      },
                    ),
                  for (final tag in _selectedTypeTags)
                    _buildRemovableChip(
                      label: _tagLabel(tag),
                      onRemove: () {
                        HapticService().vibrate();
                        _removeTypeTag(tag);
                      },
                    ),
                  for (final tag in _selectedFlavorTags)
                    _buildRemovableChip(
                      label: _tagLabel(tag),
                      onRemove: () {
                        HapticService().vibrate();
                        _removeFlavorTag(tag);
                      },
                    ),
                ],
              ),
            ),

            if (widget.detectedProducts.any((p) => p.isOfflineFallback))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: offlineBannerColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _softShadow(theme),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 18,
                        color: offlineAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc.offlineBasicRecognitionBanner,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: offlineAccent,
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
                            Icon(
                              Icons.info_outline,
                              size: 40,
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                  : (_filtered.isEmpty && _hasActiveTagFilters)
                  ? _buildFilterEmpty()
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16 + MediaQuery.of(context).padding.bottom + 24,
                      ),
                      itemCount: _filtered.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == _filtered.length) {
                          return _buildAddProductButton();
                        }

                        final ranked = _filtered[i];
                        return RankedProductCard(
                          ranked: ranked,
                          totalProducts: _filtered.length,
                          quantity: widget
                              .productCounts?[ranked.evaluation.product.id],
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
                                  comparisonSet: _allRanked,
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
      (
        icon: Icons.qr_code_scanner_outlined,
        activeIcon: Icons.qr_code_scanner,
        label: loc.scan,
      ),
      (
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: loc.history,
      ),
      (
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: loc.profile,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.10),
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
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
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