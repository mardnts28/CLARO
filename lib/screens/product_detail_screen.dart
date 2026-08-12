import 'package:flutter/material.dart';
import '../core/utils/number_format_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/fda_verification_service.dart';
import '../services/auth_service.dart';
import '../services/voice_assistant_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/locale_service.dart';
import '../widgets/voice_assistant_fab.dart';
import 'compare_products_screen.dart';
import 'more_details_screen.dart';
import '../data/models/health_profile.dart';
import '../data/models/health_advisory.dart';
import '../data/models/product_evaluation.dart';
import '../data/models/ranked_product_result.dart';
import '../data/models/comparison_matrix.dart';
import '../core/constants/who_fda_thresholds.dart';
import '../core/utils/rank_label_helper.dart';
import '../core/utils/who_calculator.dart';
import '../core/utils/fallback_advisory_generator.dart';
import '../core/utils/nutrition_availability.dart';
import '../core/utils/nutri_score_calculator.dart';
import '../core/utils/nova_score_calculator.dart';
import '../data/services/backend_locator.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final double confidence;

  // Optional: the full set of products this one is being compared against
  // (populated when navigated from CompareProductsScreen or
  // MultiScanResultsScreen). Must include an entry for `product` itself.
  // When null/omitted, this is a solo scan -- advisory-only, no comparison
  // matrix, matching the original Phase 2 solo flow.
  final List<RankedProductResult>? comparisonSet;
  final Map<String, int>? productCounts;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.confidence = 0.95,
    this.comparisonSet,
    this.productCounts,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  bool _favoriteBusy = false;
  FdaVerificationResult? _fdaResult;
  final _authService = AuthService();

  // Backend-derived health advisory state (WhoCalculator + GeminiAdvisoryService,
  // via ProductRankingService.getProductDetail -- see backend_locator.dart).
  bool _advisoryLoading = true;
  bool _nutritionUnavailable = false;
  ProductEvaluation? _evaluation;
  HealthAdvisory? _advisory;
  ComparisonMatrix? _comparisonMatrix;
  String? _rankingExplanation;

  // Placeholder scan-event id used only for GeminiAdvisoryService's
  // per-scan-event response cache. Once a real scan-session id is threaded
  // through from the camera/multi-scan flow, pass that in instead.
  late String _scanEventId;

  bool _advisoryStarted = false;

  // Local state for the current product to allow updates from Compare
  late Product _currentProduct;
  List<RankedProductResult>? _currentComparisonSet;

  late double _selectedSizeG;
  late List<double> _availableSizes;
  late String _displayedImageUrl;

  void _initSizes(Product product) {
    final originalG = product.servingSizeG > 0 ? product.servingSizeG : 100.0;
    final sizeSet = <double>{originalG, ...product.availableSizes};
    _availableSizes = sizeSet.toList()..sort();
    _selectedSizeG = originalG;
    _displayedImageUrl = product.imageUrlForSize(originalG);
  }

  double get _sizeScale {
    final original = _currentProduct.servingSizeG > 0
        ? _currentProduct.servingSizeG
        : 100.0;
    return _selectedSizeG / original;
  }

  @override
  void initState() {
    super.initState();
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
    VoiceAssistantService.setLatestScanProduct(widget.product);
    _currentProduct = widget.product;
    _currentComparisonSet = widget.comparisonSet;
    _scanEventId = '${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}';
    _initSizes(_currentProduct);
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('product_detail');
    }
    _loadFdaVerification();
    _loadFavoriteStatus();
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  /// Updates the currently displayed product and reloads all associated data.
  /// Called when returning from Compare with a selected product.
  void _updateProduct(Product newProduct, List<RankedProductResult>? newComparisonSet) {
    setState(() {
      _currentProduct = newProduct;
      _currentComparisonSet = newComparisonSet;
      _scanEventId = '${newProduct.id}_${DateTime.now().millisecondsSinceEpoch}';
      _initSizes(newProduct);
      _advisoryLoading = true;
      _nutritionUnavailable = false;
      _evaluation = null;
      _advisory = null;
      _comparisonMatrix = null;
      _rankingExplanation = null;
      _fdaResult = null;
      _isFavorite = false;
      _favoriteBusy = true; // Prevent interaction while loading new product's favorite status
    });
    _loadFdaVerification();
    _loadFavoriteStatus();
    _loadAdvisory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_advisoryStarted) {
      _advisoryStarted = true;
      _loadAdvisory();
    }
  }

  Future<void> _loadFdaVerification() async {
    // Try verification using CPR number first, fall back to fuzzy match by product name
    FdaVerificationResult result = await FdaVerificationService()
        .verifyByCprNumber(_currentProduct.fdaRegistrationNumber);

    if (result.isUnverified) {
      result = await FdaVerificationService()
          .verifyByProductName(_currentProduct.name);
    }

    if (mounted) {
      setState(() => _fdaResult = result);
      _refreshVoiceSummary();
    }
  }

  Future<void> _loadFavoriteStatus() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final isFav = await BackendLocator.favoritesService.isFavorite(
      userId: uid,
      productId: _currentProduct.id,
    );

    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _favoriteBusy = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _favoriteBusy) return;

    // Optimistic update -- flip the icon immediately so the tap feels
    // responsive, then reconcile with what the repository actually did.
    final previous = _isFavorite;
    setState(() {
      _isFavorite = !previous;
      _favoriteBusy = true;
    });

    try {
      final newState = await BackendLocator.favoritesService.toggleFavorite(
        userId: uid,
        productId: _currentProduct.id,
      );
      if (mounted) {
        setState(() {
          _isFavorite = newState;
          _favoriteBusy = false;
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      // Revert the optimistic flip since the write didn't actually happen.
      if (mounted) {
        setState(() {
          _isFavorite = previous;
          _favoriteBusy = false;
        });
      }
    }
  }

  /// Loads the user's health profile (via UserRepository, which already
  /// maps Firestore's English/Tagalog condition labels onto the backend's
  /// HealthCondition enum -- see firestore_label_mappings.dart) and runs
  /// the real WhoCalculator/GeminiAdvisoryService pipeline for this
  /// product, replacing the old hand-rolled warning strings.
  Future<void> _loadAdvisory() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _advisoryLoading = false);
        return;
      }

      // WhoCalculator/GeminiAdvisoryService/ProductRankingService assume
      // real nutrition data for every product involved -- a product with no
      // real data (all-zero defaults) would otherwise silently score as
      // "Suitable" and skew ranking/comparison for every product alongside
      // it. Detect that up front and skip the whole pipeline rather than
      // feed it bad data; none of those services themselves are touched.
      final productsInvolved = _currentComparisonSet != null && _currentComparisonSet!.length > 1
          ? _currentComparisonSet!.map((r) => r.evaluation.product)
          : [_currentProduct];
      if (!NutritionAvailability.allAvailable(productsInvolved)) {
        if (mounted) {
          setState(() {
            _nutritionUnavailable = true;
            _advisoryLoading = false;
          });
        }
        return;
      }

      final profile = await BackendLocator.userRepository.getHealthProfile(uid);

      // If a comparisonSet was handed to us (from Compare / multi-scan),
      // use it as-is -- it's already ranked. Otherwise this is a solo
      // scan: rank just this one product so we still get a proper
      // ProductEvaluation out of WhoCalculator.
      List<RankedProductResult> ranked;
      if (_currentComparisonSet != null && _currentComparisonSet!.length > 1) {
        ranked = _currentComparisonSet!;
      } else {
        ranked = BackendLocator.productRankingService.rankProducts(
          products: [_currentProduct],
          user: profile,
        );
      }

      final target = ranked.firstWhere(
        (r) => r.evaluation.product.id == _currentProduct.id,
        orElse: () => ranked.first,
      );

      final languageCode =
          mounted ? Localizations.localeOf(context).languageCode : 'en';

      final detail = await BackendLocator.productRankingService.getProductDetail(
        target: target,
        comparisonSet: ranked.length > 1 ? ranked : null,
        user: profile,
        scanEventId: _scanEventId,
        languageCode: languageCode,
      );

      if (mounted) {
        setState(() {
          _evaluation = target.evaluation;
          _advisory = detail.advisory;
          _comparisonMatrix = detail.comparisonMatrix;
          _rankingExplanation = detail.rankingExplanation;
          _advisoryLoading = false;
        });
        _refreshVoiceSummary();
      }
    } catch (e) {
      debugPrint('Error loading health advisory: $e');
      if (mounted) setState(() => _advisoryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _currentProduct;
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header bar: back, Resulta, heart (perfectly centered Stack) ──
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
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color: colorScheme.primary, size: 24),
                  ),
                ),
                // Right Heart Button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: colorScheme.secondary,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── Scrollable content ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('product_detail_scroll'),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ── 1. Main Product Info Card ──────────────────────
                  _buildCard(
                    context: context,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image (Cloudinary-hosted, via imageURL from
                        // Firestore) with graceful placeholder fallback for
                        // missing/invalid URLs.
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 80,
                                height: 80,
                                color: theme.cardColor.withOpacity(0.5),
                                child: _displayedImageUrl.isEmpty
                                    ? Icon(Icons.dining_outlined,
                                        size: 40, color: colorScheme.outline)
                                    : Image.network(
                                        _displayedImageUrl,
                                        key: ValueKey(_displayedImageUrl),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: colorScheme.outline,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.dining_outlined,
                                              size: 40, color: colorScheme.outline);
                                        },
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // ── Size dropdown ──
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<double>(
                                  value: _selectedSizeG,
                                  isDense: true,
                                  icon: Icon(Icons.arrow_drop_down,
                                      size: 18, color: colorScheme.onSurfaceVariant),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  items: _availableSizes.map((size) {
                                    final label = size == size.roundToDouble()
                                        ? '${size.toInt()}g'
                                        : '${size.toStringAsFixed(1)}g';
                                    return DropdownMenuItem(
                                      value: size,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (newSize) {
                                    if (newSize != null) {
                                      setState(() {
                                        _selectedSizeG = newSize;
                                        _displayedImageUrl = p.imageUrlForSize(newSize);
                                      });
                                      _refreshVoiceSummary();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.productCounts != null && (widget.productCounts![p.id] ?? 1) > 1
                                    ? '${p.name} (x${widget.productCounts![p.id]})'
                                    : p.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.nutritionalFacts.servingSize,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // FDA badge
                              _buildFdaBadge(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── FDA Warning Banner (only shown if expired or unverified) ────
                  if (_fdaResult != null && !_fdaResult!.isActive)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _fdaResult!.isExpired
                            ? Colors.red.withOpacity(0.1)
                            : Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _fdaResult!.isExpired
                              ? Colors.red.withOpacity(0.5)
                              : Colors.amber.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: _fdaResult!.isExpired ? Colors.red : Colors.amber[800],
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fdaResult!.isExpired
                                  ? loc.fdaExpiredWarning
                                  : loc.fdaUnverifiedWarning,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── 2. Age recommendation and LIGTAS I-KONSUMO ──────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        loc.ageRequirementBadge,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _buildAdvisoryBanner(context, loc),

                  const SizedBox(height: 12),

                  // ── 3. Batayan ng Pagsusuri (Reminders Box) ───────
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5D5C5), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB71C1C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.bookmark,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.analysisBasisTitle,
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    loc.analysisBasisSubtitle('${_selectedSizeG == _selectedSizeG.roundToDouble() ? _selectedSizeG.toInt().toString() : _selectedSizeG.toStringAsFixed(1)}g'),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: colorScheme.onSurface.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (!p.nutritionalFacts.hasNutritionData)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 18, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    loc.nutritionDataUnavailable,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                        // Nutrient rows
                        ...(() {
                          final evals = <DisplayNutrientEval>[
                            // 1. Sodium (Hypertension)
                            (() {
                              final val100g = p.nutritionPer100g.sodiumMg;
                              final valServing = (val100g / 100) * _selectedSizeG;
                              final limit = 2000.0;
                              final pct = (valServing / limit) * 100;
                              return DisplayNutrientEval(
                                label: loc.bpSodiumLabel,
                                nutrientKey: 'sodiumMg',
                                valuePerServing: valServing,
                                limit: limit,
                                percentage: pct,
                                level: WhoCalculator.classifyByWhoPercentage(pct),
                                unit: 'mg',
                              );
                            })(),
                            // 2. Sugars (Diabetes)
                            (() {
                              final val100g = p.nutritionPer100g.sugarsG;
                              final valServing = (val100g / 100) * _selectedSizeG;
                              final limit = 50.0;
                              final pct = (valServing / limit) * 100;
                              return DisplayNutrientEval(
                                label: loc.diabetesSugarsLabel,
                                nutrientKey: 'sugarsG',
                                valuePerServing: valServing,
                                limit: limit,
                                percentage: pct,
                                level: WhoCalculator.classifyByWhoPercentage(pct),
                                unit: 'g',
                              );
                            })(),
                            // 3. Saturated Fats (Heart disease)
                            (() {
                              final val100g = p.nutritionPer100g.saturatedFatG;
                              final valServing = (val100g / 100) * _selectedSizeG;
                              final limit = 22.2;
                              final pct = (valServing / limit) * 100;
                              return DisplayNutrientEval(
                                label: loc.heartSatFatLabel,
                                nutrientKey: 'saturatedFatG',
                                valuePerServing: valServing,
                                limit: limit,
                                percentage: pct,
                                level: WhoCalculator.classifyByWhoPercentage(pct),
                                unit: 'g',
                              );
                            })(),
                          ];

                          return evals.map((e) {
                            Color progressColor;
                            Color badgeBgColor;
                            Color badgeTextColor;
                            String badgeLabel;

                            switch (e.level) {
                              case AdvisoryLevel.suitable:
                                progressColor = const Color(0xFF2E7D32);
                                badgeBgColor = const Color(0xFFE8F5E9);
                                badgeTextColor = const Color(0xFF2E7D32);
                                badgeLabel = 'Suitable';
                                break;
                              case AdvisoryLevel.moderate:
                                progressColor = const Color(0xFFE65100);
                                badgeBgColor = const Color(0xFFFFF3E0);
                                badgeTextColor = const Color(0xFFE65100);
                                badgeLabel = 'Moderate';
                                break;
                              case AdvisoryLevel.caution:
                                progressColor = const Color(0xFFC62828);
                                badgeBgColor = const Color(0xFFFFEBEE);
                                badgeTextColor = const Color(0xFFC62828);
                                badgeLabel = 'Caution';
                                break;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: badgeBgColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: GoogleFonts.inter(
                                            color: badgeTextColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (e.percentage / 100).clamp(0.0, 1.0),
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                      minHeight: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_formatValue(e.valuePerServing)}${e.unit} / ${_formatValue(e.limit)}${e.unit} ${loc.dailySuffix} · ${e.percentage.toStringAsFixed(0)}% ${loc.ofWhoLimit}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          });
                        })(),

                        // Allergy row -- ONLY for allergens that are both
                        // (a) present in this product AND (b) saved in the
                        // user's own health profile. `p.allergens` alone is
                        // every allergen the PRODUCT contains, not the ones
                        // relevant to this user; cross-reference against
                        // `_evaluation.allergenAssessment.matchedContains`
                        // (computed by WhoCalculator.assessAllergens against
                        // the signed-in user's saved allergies) so a user
                        // who only lists "milk" doesn't see unrelated
                        // allergens like crustaceans/fish/soy/coconut that
                        // simply happen to be in the product.
                        //
                        // -- consolidated into ONE block listing every
                        // matched allergen together, rather than repeating
                        // the full title/badge/note layout per allergen.
                        // With 2+ allergens that per-item layout stacked
                        // duplicate "may cause allergic reaction" notes and
                        // made the card grow unbounded; grouping them still
                        // surfaces every allergen while keeping the card a
                        // fixed height regardless of how many are detected.
                        if (_matchedUserAllergenLabels(p, Localizations.localeOf(context).languageCode).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Allergy - ${_matchedUserAllergenLabels(p, Localizations.localeOf(context).languageCode).join(', ')}',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        loc.allergenDetectedBadge,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFC62828),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // Legend section - How to understand
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 24, thickness: 1),
                            Text(
                              loc.howToUnderstandTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildLegendItem(
                              dotColor: const Color(0xFF2E7D32),
                              label: loc.suitableLegend,
                              description: loc.legendSuitableDesc,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              dotColor: const Color(0xFFE65100),
                              label: loc.moderateLegend,
                              description: loc.legendModerateDesc,
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              dotColor: const Color(0xFFC62828),
                              label: loc.cautionLegend,
                              description: loc.legendCautionDesc,
                              colorScheme: colorScheme,
                            ),
                          ],
                        ),
                        ],
                      ],
                    ),
                  ),

                  // ── 4. For more details link ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12, left: 24, right: 24),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MoreDetailsScreen(
                              product: p,
                              matchedAllergens: _evaluation?.allergenAssessment.matchedContains ?? const [],
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_return_rounded,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              loc.forMoreDetails,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                                decoration: TextDecoration.underline,
                                decorationColor: colorScheme.onSurface,
                                decorationThickness: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── 6. Kabuuang Nutrisyon Card ────────────────────
                  _buildCard(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.totalNutritionTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (!p.nutritionalFacts.hasNutritionData)
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.nutritionDataUnavailable,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriCalories, '${(p.nutritionalFacts.caloriesKcal * _sizeScale).toStringAsFixed(0)} kcal'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriCarbs, '${(p.nutritionalFacts.carbsG * _sizeScale).toStringAsFixed(1)}g'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriSugar, '${(p.nutritionalFacts.sugarsG * _sizeScale).toStringAsFixed(1)}g'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriSodium, '${(p.nutritionalFacts.sodiumMg * _sizeScale).toStringAsFixed(0)}mg'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriProtein, '${(p.nutritionalFacts.proteinG * _sizeScale).toStringAsFixed(1)}g'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriTotalFat, '${(p.nutritionalFacts.totalFatG * _sizeScale).toStringAsFixed(1)}g'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriSatFat, '${(p.nutritionalFacts.saturatedFatG * _sizeScale).toStringAsFixed(1)}g'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriTransFat, '${(p.nutritionalFacts.transFatG * _sizeScale).toStringAsFixed(1)}g'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriFiber, '${(p.nutritionalFacts.fiberG * _sizeScale).toStringAsFixed(1)}g'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriPotassium, '${(p.nutritionalFacts.potassiumMg * _sizeScale).toStringAsFixed(0)}mg'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriCalcium, '${(p.nutritionalFacts.calciumMg * _sizeScale).toStringAsFixed(0)}mg'),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriIron, '${(p.nutritionalFacts.ironMg * _sizeScale).toStringAsFixed(1)}mg'),
                          ],
                        ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 7. Scores (Individual White Cards: Nutri-Score & NOVA) ─
                  (() {
                    final langCode = Localizations.localeOf(context).languageCode;
                    final nutriResult = NutriScoreCalculator.computeFromProduct(
                      _currentProduct,
                      customServingSizeG: _selectedSizeG,
                    );
                    final novaResult = NovaScoreCalculator.computeFromProduct(_currentProduct);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            loc.scoresTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _scoreCard(
                          context: context,
                          label: loc.scoreNutrition,
                          badge: nutriResult.gradeLetter,
                          badgeColor: Color(nutriResult.gradeColorHex),
                          description: nutriResult.description(langCode),
                        ),
                        const SizedBox(height: 8),
                        _scoreCard(
                          context: context,
                          label: loc.scoreProcess,
                          badge: novaResult.groupString,
                          badgeColor: Color(novaResult.colorHex),
                          isCircle: true,
                          description: novaResult.description(langCode),
                        ),
                      ],
                    );
                  })(),

                  const SizedBox(height: 16),

                  // ── 8. Product Ranking Card ─────────────────────────
                  // Only rendered when this product was viewed as part of
                  // a comparison set (Compare button / multi-scan), per
                  // ProductDetailResult.hasComparison.
                  if (_comparisonMatrix != null && !_comparisonMatrix!.isEmpty)
                    _buildComparisonCard(context, loc),

                  if (_comparisonMatrix != null && !_comparisonMatrix!.isEmpty)
                    const SizedBox(height: 16),

                  // ── 9. Ihambing Button ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompareProductsScreen(
                                sourceProduct: p,
                              ),
                            ),
                          );
                          if (result != null && result is Map<String, dynamic>) {
                            final newProduct = result['product'] as Product;
                            final newComparisonSet = result['comparisonSet'] as List<RankedProductResult>?;
                            _updateProduct(newProduct, newComparisonSet);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          loc.compareButton,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Clean trailing bottom space (no huge excessive spacing)
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  // ── Health advisory banner (WhoCalculator + GeminiAdvisoryService) ──────
  Widget _buildAdvisoryBanner(BuildContext context, AppLocalizations loc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_advisoryLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          height: 20,
          child: LinearProgressIndicator(),
        ),
      );
    }

    if (_nutritionUnavailable) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.nutritionDataUnavailable,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // The backend's `_evaluation.overallLevel` is fixed to the product's
    // labeled serving size (`product.servingSizeG`) -- deliberately, so
    // ranking/comparison across products stays size-independent (see
    // WhoCalculator.evaluateProduct). But on THIS single-product screen,
    // the nutrient rows below already recalculate live against whichever
    // size the user picked in the dropdown, so the verdict badge should
    // agree with them rather than staying frozen on the label size.
    final level = _currentOverallLevel();
    late final Color color;
    late final IconData icon;
    switch (level) {
      case AdvisoryLevel.suitable:
        color = Colors.green;
        icon = Icons.verified_user_outlined;
        break;
      case AdvisoryLevel.moderate:
        color = Colors.amber[800]!;
        icon = Icons.info_outline;
        break;
      case AdvisoryLevel.caution:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
    }

    final levelLabel = _levelLabel(level);
    final effectiveAdvisory = _effectiveAdvisory(context);
    final advisoryTitle = effectiveAdvisory?.warningText ??
        (level == AdvisoryLevel.suitable ? loc.safeToConsume : loc.reminderLabel);
    final title = '$levelLabel - $advisoryTitle';
    final subtitle = effectiveAdvisory?.explanation ?? loc.safeToConsumeSubtitle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nutrient comparison card (ComparisonMatrixBuilder output) ───────────
  Widget _buildComparisonCard(BuildContext context, AppLocalizations loc) {
    final matrix = _comparisonMatrix!;
    final productId = widget.product.id;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine rank level label + color based on product's rank -- both
    // come from RankLabelHelper so this title always matches the tag
    // color shown for this same product on the compare/ranking list
    // screen (compare_products_screen.dart).
    final rankLabel = _getRankLevelLabel();
    final rankColor = _getRankLevelColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rankLabel,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
          if (_rankingExplanation != null) ...[
            const SizedBox(height: 8),
            Text(
              _rankingExplanation!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...matrix.nutrientRows.map((row) {
            final cell = row.cells.firstWhere((c) => c.productId == productId);
            final Color dotColor;
            switch (cell.highlight) {
              case ComparisonHighlight.favorable:
                dotColor = Colors.green;
                break;
              case ComparisonHighlight.unfavorable:
                dotColor = Colors.red;
                break;
              case ComparisonHighlight.neutral:
                dotColor = Colors.grey;
                break;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.nutrient.displayLabel,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${cell.value.toStringAsFixed(1)}${row.nutrient.unit} / 100g',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
          for (final row in matrix.allergenRows)
            if (row.cells.any((c) =>
                c.productId == productId && c.presence != AllergenPresence.none))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      row.allergen.displayLabel,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }



  String _levelLabel(AdvisoryLevel level) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return 'Suitable';
      case AdvisoryLevel.moderate:
        return 'Moderate';
      case AdvisoryLevel.caution:
        return 'Caution';
    }
  }

  // Both label and color are delegated to RankLabelHelper
  // (core/utils/rank_label_helper.dart) -- the single source of truth
  // shared with compare_products_screen.dart's list-card tags, so the
  // title here always matches that tag's text and color for the same
  // product.
  String _getRankLevelLabel() {
    if (widget.comparisonSet == null) {
      return 'Product Ranking';
    }

    final currentProduct = widget.comparisonSet!.firstWhere(
      (r) => r.evaluation.product.id == widget.product.id,
      orElse: () => widget.comparisonSet!.first,
    );

    return RankLabelHelper.label(
      rank: currentProduct.rank,
      suitabilityRankLabel: currentProduct.suitabilityRankLabel,
      includeChoiceSuffix: true,
    );
  }

  Color _getRankLevelColor() {
    if (widget.comparisonSet == null) {
      return Colors.green;
    }

    final currentProduct = widget.comparisonSet!.firstWhere(
      (r) => r.evaluation.product.id == widget.product.id,
      orElse: () => widget.comparisonSet!.first,
    );

    return RankLabelHelper.color(
      rank: currentProduct.rank,
      suitabilityRankLabel: currentProduct.suitabilityRankLabel,
    );
  }

  // ── Helper card builder to make cards completely uniform ────────────────
  Widget _buildCard({required BuildContext context, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Nutritional mini grid card ──────────────────────────────────────────
  Widget _nutriCard(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  // ── Individual white score card (matches the style of scores section) ────
  Widget _scoreCard({
    required BuildContext context,
    required String label,
    required String badge,
    required Color badgeColor,
    required String description,
    bool isCircle = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge indicator block
          Column(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircle ? null : BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Description text
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.inter(
                  fontSize: 13, color: colorScheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFdaBadge() {
    final fda = _fdaResult;
    if (fda == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const SizedBox(
          width: 60,
          height: 14,
          child: LinearProgressIndicator(),
        ),
      );
    }

    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (fda.status) {
      case FdaStatus.active:
        badgeColor = const Color(0xFF2E7D32);
        badgeIcon = Icons.verified;
        badgeText = 'FDA ACTIVE';
        break;
      case FdaStatus.expired:
        badgeColor = const Color(0xFFC62828);
        badgeIcon = Icons.warning_amber_rounded;
        badgeText = 'FDA EXPIRED';
        break;
      case FdaStatus.unverified:
        badgeColor = const Color(0xFFF57F17);
        badgeIcon = Icons.help_outline;
        badgeText = 'UNVERIFIED';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, color: Colors.white, size: 13),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (fda.cprNumber.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'CPR: ${fda.cprNumber}',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold),
          ),
          if (fda.validityDate.isNotEmpty)
            Text(
              'Valid until: ${fda.validityDate}',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
            ),
          if (fda.manufacturer.isNotEmpty)
            Text(
              fda.manufacturer,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
            ),
        ],
      ],
    );
  }

  // Returns a display label for every allergen in
  // `_evaluation.allergenAssessment.matchedContains` -- the exact set the
  // Health Advisory banner already uses (via WhoCalculator.assessAllergens),
  // which matches BOTH allergens explicitly listed in `product.allergens`
  // AND allergens only detected by scanning ingredient text (e.g. an
  // ingredient like "whey powder" flags dairy even if "milk"/"dairy" isn't
  // itself one of the product's listed allergens). Iterating
  // `matchedContains` directly (instead of trying to map it back onto
  // `product.allergens`) is what fixes ingredient-only matches silently
  // being dropped from this card while still showing up correctly in the
  // Health Advisory banner.
  //
  // Prefers the product's own (possibly localized) allergen string when
  // one exists in `product.allergens` for that type; falls back to the
  // generic `AllergenTypeDisplay.displayLabel` (same one comparison
  // screens use) for ingredient-only matches that have no such entry.
  List<String> _matchedUserAllergenLabels(Product product, String langCode) {
    final matchedTypes = _evaluation?.allergenAssessment.matchedContains;
    if (matchedTypes == null || matchedTypes.isEmpty) return const [];

    final productAllergenTypes = product.containsAllergens; // parallel to product.allergens
    final labels = <String>[];
    for (final type in matchedTypes) {
      final rawIndex = productAllergenTypes.indexOf(type);
      final label = rawIndex != -1
          ? _getAllergenName(product.allergens[rawIndex], langCode)
          : type.displayLabel;
      if (!labels.contains(label)) labels.add(label);
    }
    return labels;
  }

  String _buildVoiceSummary(
    BuildContext context,
    ProductEvaluation evaluation,
  ) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final allergenLabels = _matchedUserAllergenLabels(
      _currentProduct,
      languageCode,
    );
    final advisory = _effectiveAdvisory(context);
    final verdict = switch (_currentOverallLevel()) {
      AdvisoryLevel.suitable => 'Suitable',
      AdvisoryLevel.moderate => 'Moderate',
      AdvisoryLevel.caution => 'Caution',
    };
    final flaggedNutrients = <String>[];
    for (final nutrient in evaluation.nutrientEvaluations) {
      if (nutrient.level == AdvisoryLevel.suitable) continue;
      final label = _voiceNutrientLabel(nutrient.nutrientKey);
      if (!flaggedNutrients.contains(label)) {
        flaggedNutrients.add(label);
      }
    }

    final sections = <String>[];
    if (allergenLabels.isNotEmpty) {
      sections.add('Allergen warning: ${allergenLabels.join(', ')}.');
    }

    sections.add(
      'Product: ${_currentProduct.name}, size ${_selectedSizeG.toStringAsFixed(0)} grams.',
    );
    sections.add('Overall verdict: $verdict.');

    if (advisory != null) {
      if (advisory.warningText.trim().isNotEmpty) {
        sections.add(advisory.warningText.trim());
      }
      if (advisory.explanation.trim().isNotEmpty) {
        sections.add(advisory.explanation.trim());
      }
    }

    if (flaggedNutrients.isNotEmpty) {
      sections.add('Nutrients driving this verdict: ${flaggedNutrients.join(', ')}.');
    }

    final fda = _fdaResult;
    if (fda != null) {
      sections.add(
        fda.isActive
            ? 'FDA status: active.'
            : fda.isExpired
                ? 'FDA status: expired.'
                : 'FDA status: unverified.',
      );
    }

    final comparisonSet = _currentComparisonSet;
    if (comparisonSet != null && comparisonSet.isNotEmpty) {
      final currentRank = comparisonSet.firstWhere(
        (item) => item.evaluation.product.id == _currentProduct.id,
        orElse: () => comparisonSet.first,
      );
      final rankLabel = RankLabelHelper.label(
        rank: currentRank.rank,
        suitabilityRankLabel: currentRank.suitabilityRankLabel,
      );
      if (_rankingExplanation != null && _rankingExplanation!.trim().isNotEmpty) {
        sections.add('Comparison ranking: $rankLabel. ${_rankingExplanation!.trim()}');
      } else {
        sections.add('Comparison ranking: $rankLabel.');
      }
    }

    return sections.join(' ');
  }

  void _refreshVoiceSummary() {
    final evaluation = _evaluation;
    if (!mounted || evaluation == null) return;
    VoiceAssistantService.setLatestScanSummary(
      _buildVoiceSummary(context, evaluation),
    );
  }

  String _voiceNutrientLabel(String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return 'sodium';
      case 'sugarsG':
        return 'sugar';
      case 'saturatedFatG':
        return 'saturated fat';
      default:
        return nutrientKey;
    }
  }

  // Re-derives the overall advisory level (the badge on this screen) for
  // whichever pack size the user currently has selected in the dropdown,
  // instead of the backend's fixed-label-serving-size `overallLevel`.
  //
  // Deliberately reuses `_evaluation.nutrientEvaluations` -- the exact set
  // of nutrients WhoCalculator.evaluateProduct() already evaluated for
  // THIS user's saved health conditions -- so this stays in sync with
  // whatever conditions the user actually has, rather than hardcoding a
  // fixed nutrient list. Only the per-serving math is redone here, against
  // `_selectedSizeG` in place of the product's label serving size; the
  // WHO daily limits and classification thresholds come from the same
  // WhoCalculator functions the backend used, so this can't drift out of
  // sync with the server-side thresholds.
  //
  // Ranking/comparison screens are untouched -- they always call
  // WhoCalculator.rankProducts/evaluateProduct directly, which keeps using
  // the label serving size on purpose (see WhoCalculator comments), so a
  // product's rank never changes just because someone viewed it here with
  // a different size selected.
  AdvisoryLevel _currentOverallLevel() {
    final evaluation = _evaluation;
    if (evaluation == null) return AdvisoryLevel.suitable;

    // Allergen match doesn't scale with pack size -- keep the backend's
    // hard override as-is.
    if (evaluation.allergenAssessment.hasDirectAllergen) {
      return AdvisoryLevel.caution;
    }

    if (evaluation.nutrientEvaluations.isEmpty) {
      return evaluation.overallLevel;
    }

    var worst = AdvisoryLevel.suitable;
    for (final nutrientEval in evaluation.nutrientEvaluations) {
      final valuePerServing = (nutrientEval.valuePer100g / 100) * _selectedSizeG;
      final whoDailyLimit = WhoCalculator.getWhoDailyLimit(nutrientEval.nutrientKey);
      final whoPercentage = (valuePerServing / whoDailyLimit) * 100;
      final level = WhoCalculator.classifyByWhoPercentage(whoPercentage);
      if (level == AdvisoryLevel.caution) return AdvisoryLevel.caution;
      if (level == AdvisoryLevel.moderate) worst = AdvisoryLevel.moderate;
    }
    return worst;
  }

  // Returns the advisory text (title + explanation) to show alongside the
  // verdict badge, kept consistent with `_currentOverallLevel()`:
  //
  // - While the dropdown is still on the product's original label serving
  //   size, this is just `_advisory` unchanged -- the Gemini-written text
  //   fetched once in `_loadAdvisory()`, since nothing has been recomputed
  //   yet and it already matches that level.
  // - Once the user picks a DIFFERENT size, `_advisory` (written for the
  //   label size) would silently go stale, so this regenerates the text
  //   locally via FallbackAdvisoryGenerator using the same scaled
  //   nutrient math as `_currentOverallLevel()` -- deterministic, free
  //   (no AI call), and guaranteed to agree with the badge because both
  //   are derived from the same WhoCalculator functions. Less nuanced
  //   than the AI phrasing, but always accurate to what's on screen.
  HealthAdvisory? _effectiveAdvisory(BuildContext context) {
    final evaluation = _evaluation;
    if (evaluation == null) return _advisory;

    final labelServingSizeG = evaluation.product.servingSizeG;
    if (_selectedSizeG == labelServingSizeG) return _advisory;

    return FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.notNeeded,
      languageCode: Localizations.localeOf(context).languageCode,
      servingSizeGOverride: _selectedSizeG,
    );
  }

  String _getAllergenName(String allergen, String languageCode) {
    final norm = allergen.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (languageCode == 'tl') {
      switch (norm) {
        case 'fish':
        case 'isda':
          return 'Isda';
        case 'milk':
        case 'gatas':
          return 'Gatas';
        case 'egg':
        case 'itlog':
          return 'Itlog';
        case 'soy':
        case 'soya':
        case 'soybean':
          return 'Soya';
        case 'wheat':
        case 'trigo':
          return 'Wheat';
        case 'shellfish':
        case 'lamangdagat':
        case 'lamang-dagat':
          return 'Lamang-Dagat';
        case 'peanut':
        case 'mani':
          return 'Mani';
        default:
          return allergen;
      }
    } else {
      switch (norm) {
        case 'fish':
        case 'isda':
          return 'Fish';
        case 'milk':
        case 'gatas':
          return 'Milk';
        case 'egg':
        case 'itlog':
          return 'Egg';
        case 'soy':
        case 'soya':
        case 'soybean':
          return 'Soy';
        case 'wheat':
        case 'trigo':
          return 'Wheat';
        case 'shellfish':
        case 'lamangdagat':
        case 'lamang-dagat':
          return 'Shellfish';
        case 'peanut':
        case 'mani':
          return 'Peanut';
        default:
          return allergen;
      }
    }
  }

  String _formatValue(double value) {
    return NumberFormatUtils.formatValue(value);
  }

  Widget _buildLegendItem({
    required Color dotColor,
    required String label,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


}

class DisplayNutrientEval {
  final String label;
  final String nutrientKey;
  final double valuePerServing;
  final double limit;
  final double percentage;
  final AdvisoryLevel level;
  final String unit;

  DisplayNutrientEval({
    required this.label,
    required this.nutrientKey,
    required this.valuePerServing,
    required this.limit,
    required this.percentage,
    required this.level,
    required this.unit,
  });
}