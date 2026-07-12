import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/fda_verification_service.dart';
import '../services/auth_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import 'compare_products_screen.dart';
import '../data/models/health_profile.dart';
import '../data/models/health_advisory.dart';
import '../data/models/product_evaluation.dart';
import '../data/models/ranked_product_result.dart';
import '../data/models/comparison_matrix.dart';
import '../core/constants/who_fda_thresholds.dart';
import '../core/utils/rank_label_helper.dart';
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

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.confidence = 0.95,
    this.comparisonSet,
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

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _currentComparisonSet = widget.comparisonSet;
    _scanEventId = '${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}';
    _loadFdaVerification();
    _loadFavoriteStatus();
  }

  /// Updates the currently displayed product and reloads all associated data.
  /// Called when returning from Compare with a selected product.
  void _updateProduct(Product newProduct, List<RankedProductResult>? newComparisonSet) {
    setState(() {
      _currentProduct = newProduct;
      _currentComparisonSet = newComparisonSet;
      _scanEventId = '${newProduct.id}_${DateTime.now().millisecondsSinceEpoch}';
      _advisoryLoading = true;
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
                        // Product image placeholder
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.cardColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.dining_outlined,
                              size: 40, color: colorScheme.outline),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
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

                  // ── 3. Paalala Card ────────────────────────────────
                  _buildCard(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.reminderLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Reassurance line — only when nothing was flagged
                        // for this user's conditions.
                        if (!_advisoryLoading &&
                            _evaluation != null &&
                            _evaluation!.overallLevel == AdvisoryLevel.suitable &&
                            !_evaluation!.allergenAssessment.hasDirectAllergen)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  loc.diabetesSafeReminder,
                                  style: GoogleFonts.inter(
                                    color: Colors.green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Allergen warning (red) — only when this product
                        // matches one of THIS user's saved allergies
                        // (WhoCalculator.assessAllergens), not just when
                        // the product happens to list any allergen at all.
                        if (_evaluation != null &&
                            _evaluation!.allergenAssessment.hasDirectAllergen) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  loc.containsAllergens(
                                    _evaluation!.allergenAssessment.matchedContains
                                        .map((a) => a.displayLabel)
                                        .join(', '),
                                  ),
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // ── Personalized Health Warnings (per flagged nutrient) ──
                        if (_evaluation != null &&
                            _evaluation!.nutrientEvaluations
                                .any((e) => e.level != AdvisoryLevel.suitable)) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange, width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.personalHealthWarningTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange[900],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._evaluation!.nutrientEvaluations
                                    .where((e) => e.level != AdvisoryLevel.suitable)
                                    .map((e) => Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '⚠️ ${_nutrientLabel(e.nutrientKey)}: '
                                            '${e.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(e.nutrientKey)} '
                                            '(${e.whoDailyLimitPercentage.toStringAsFixed(0)}% of WHO daily limit per serving)',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: e.level == AdvisoryLevel.caution
                                                  ? Colors.red[900]
                                                  : Colors.orange[900],
                                              fontWeight: FontWeight.w600,
                                              height: 1.4,
                                            ),
                                          ),
                                        )),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Serving recommendation box — from the AI/fallback
                        // advisory when available, generic copy otherwise.
                        // While _loadAdvisory() is still in flight we show a
                        // "calculating" placeholder rather than the generic
                        // fallback copy, since showing that first and then
                        // swapping it for the real value reads like stale
                        // or incorrect info flashing on screen.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.green, width: 1.2),
                          ),
                          child: _advisoryLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Calculating your safe serving size...',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                          fontStyle: FontStyle.italic,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _advisory?.safeServingSize ??
                                      loc.servingRecommendation,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 12),

                        // "Higit pang detalye" link
                        Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right_rounded,
                                color: colorScheme.onSurfaceVariant, size: 16),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                loc.moreDetailsLink,
                                style: GoogleFonts.inter(
                                  color: colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

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
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriCalories, p.nutritionalFacts.calories),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriSodium, p.nutritionalFacts.sodium),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriSugar, p.nutritionalFacts.sugars),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriProtein, p.nutritionalFacts.protein),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriTotalFat, p.nutritionalFacts.totalFat),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriSatFat, p.nutritionalFacts.saturatedFat),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriTransFat, p.nutritionalFacts.transFat),
                            const SizedBox(width: 8),
                            _nutriCard(context, loc.nutriFiber, p.nutritionalFacts.dietaryFiber),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _nutriCard(context, loc.nutriPotassium, p.nutritionalFacts.potassiumMg > 0
                                ? '${p.nutritionalFacts.potassiumMg.toStringAsFixed(0)}mg'
                                : '0mg'),
                            _nutriCard(context, loc.nutriCalcium, p.nutritionalFacts.calciumMg > 0
                                ? '${p.nutritionalFacts.calciumMg.toStringAsFixed(0)}mg'
                                : '0mg'),
                            _nutriCard(context, loc.nutriIron, p.nutritionalFacts.ironMg > 0
                                ? '${p.nutritionalFacts.ironMg.toStringAsFixed(1)}mg'
                                : '0.0mg'),
                            Expanded(child: const SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 7. Scores (Individual White Cards) ─────────────
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
                    badge: 'C',
                    badgeColor: const Color(0xFFFFB300),
                    description: loc.scoreNutritionDesc,
                  ),
                  const SizedBox(height: 8),
                  _scoreCard(
                    context: context,
                    label: loc.scoreEnvironment,
                    badge: 'B',
                    badgeColor: const Color(0xFF4CAF50),
                    description: loc.scoreEnvironmentDesc,
                  ),
                  const SizedBox(height: 8),
                  _scoreCard(
                    context: context,
                    label: loc.scoreProcess,
                    badge: '3',
                    badgeColor: const Color(0xFFFF9800),
                    isCircle: true,
                    description: loc.scoreProcessDesc,
                  ),

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

    final level = _evaluation?.overallLevel ?? AdvisoryLevel.suitable;
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
    final advisoryTitle = _advisory?.warningText ??
        (level == AdvisoryLevel.suitable ? loc.safeToConsume : loc.reminderLabel);
    final title = '$levelLabel - $advisoryTitle';
    final subtitle = _advisory?.explanation ?? loc.safeToConsumeSubtitle;

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

  String _nutrientLabel(String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return 'Sodium';
      case 'sugarsG':
        return 'Sugars';
      case 'saturatedFatG':
        return 'Saturated Fat';
      default:
        return nutrientKey;
    }
  }

  String _nutrientUnit(String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return 'mg';
      case 'sugarsG':
      case 'saturatedFatG':
        return 'g';
      default:
        return '';
    }
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
}