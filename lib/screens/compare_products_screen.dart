import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/history_service.dart';
import '../services/voice_assistant_service.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../data/models/ranked_product_result.dart';
import '../data/services/backend_locator.dart';
import '../core/utils/nutrition_availability.dart';
import '../data/models/health_profile.dart';
import '../widgets/ranked_product_card.dart';
import 'product_detail_screen.dart';

class CompareProductsScreen extends StatefulWidget {
  /// The product the user is currently viewing — used to filter by category
  /// and to highlight it in the list.
  final Product sourceProduct;

  /// Whether to save this comparison session to history. Set to false when
  /// reopening a previously saved comparison to avoid duplicate entries.
  final bool saveToHistory;

  const CompareProductsScreen({
    super.key,
    required this.sourceProduct,
    this.saveToHistory = true,
  });

  @override
  State<CompareProductsScreen> createState() => _CompareProductsScreenState();
}

class _CompareProductsScreenState extends State<CompareProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final _authService = AuthService();
  final HistoryService _historyService = HistoryService();

  bool _loading = true;
  bool _nutritionUnavailable = false;
  String? _error;

  // Full ranked comparison set (scanned product + alternatives in the same
  // category), from ProductComparisonService.compareWithAlternatives --
  // backed by WhoCalculator.rankProducts under the hood. Free/pure-Dart,
  // no Gemini call happens just to build this list.
  List<RankedProductResult> _allRanked = [];
  List<RankedProductResult> _filtered = [];

  // Full profile (so we know every condition the user has, for the filter
  // sheet) and the fixed set of products from the initial compare fetch (so
  // re-ranking on filter change is free/pure-Dart -- no re-fetch of
  // alternatives, no Gemini call, no chance of the alternatives list itself
  // changing underneath the user when they switch filters).
  UserHealthProfile? _profile;
  List<Product> _comparisonProducts = [];

  // null == "Overall" (current/default behavior, all of the user's
  // conditions). Non-null == ranking narrowed to that single condition.
  HealthCondition? _selectedCondition;

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('compare_products');
    }
    _searchCtrl.addListener(_onSearch);
    _loadRanking();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRanking() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _loading = false;
          _error = 'no_user';
        });
        return;
      }

      final profile = await BackendLocator.userRepository.getHealthProfile(uid);

      // ProductComparisonService (WhoCalculator under the hood) scores this
      // product against alternatives -- if it has no real nutrition data
      // (all-zero defaults), that comparison is meaningless. Detect that up
      // front rather than run a comparison that would misrepresent it.
      // ProductComparisonService / WhoCalculator themselves are untouched.
      if (!NutritionAvailability.isAvailable(widget.sourceProduct)) {
        if (mounted) {
          setState(() {
            _nutritionUnavailable = true;
            _loading = false;
          });
        }
        return;
      }

      final ranked = await BackendLocator.productComparisonService.compareWithAlternatives(
        scannedProduct: widget.sourceProduct,
        user: profile,
      );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _comparisonProducts = ranked.map((r) => r.evaluation.product).toList();
        _allRanked = ranked;
        _filtered = List.from(ranked);
        _loading = false;
      });

      // Save comparison session to history immediately after successful generation
      // Only save if this is a new comparison (not viewing a saved one)
      if (widget.saveToHistory) {
        _historyService.addComparisonRecord(
          category: widget.sourceProduct.category,
          title: '${widget.sourceProduct.name} Comparison Result',
          sourceProductId: widget.sourceProduct.id,
        );
      }
    } catch (e) {
      debugPrint('Error loading product comparison: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<RankedProductResult> _computeFiltered(List<RankedProductResult> source) {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return List.from(source);
    return source
        .where((r) =>
            r.evaluation.product.name.toLowerCase().contains(q) ||
            r.evaluation.product.brand.toLowerCase().contains(q) ||
            r.evaluation.product.variant.toLowerCase().contains(q))
        .toList();
  }

  void _onSearch() {
    setState(() {
      _filtered = _computeFiltered(_allRanked);
    });
  }

  /// Re-ranks the SAME comparison set (no new DB fetch, no new Gemini call)
  /// against a health profile narrowed to just [condition] -- or the full
  /// profile when [condition] is null ("Overall"). Runs through the exact
  /// same WhoCalculator.rankProducts pipeline as the default ranking; the
  /// only thing that changes is which condition(s) are on the profile
  /// passed in, so a single-condition filter naturally focuses the score on
  /// that condition's nutrient(s) without any separate ranking logic.
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
      _allRanked = reRanked;
      _filtered = _computeFiltered(reRanked);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: back + title ──────────────────────────────
          Container(
            color: colorScheme.surface,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: topPadding + 14,
              bottom: 14,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticService().vibrate();
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.arrow_back,
                      color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  loc.similarProductsTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_profile != null)
                  GestureDetector(
                    onTap: _showFilterSheet,
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
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── Category chip ─────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.4)),
                  ),
                  child: Text(
                    widget.sourceProduct.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  loc.productCount(_allRanked.length),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                if (_selectedCondition != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _selectConditionFilter(null),
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

          // ── Search bar ────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search,
                        color: colorScheme.onSurfaceVariant, size: 22),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: loc.searchHint,
                        hintStyle: GoogleFonts.inter(
                            fontSize: 14, color: colorScheme.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        FocusScope.of(context).unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.close,
                            color: colorScheme.onSurfaceVariant, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── Ranked-by-suitability label ───────────────────────────
          if (!_loading && _error == null && !_nutritionUnavailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                loc.rankedBySuitability,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 4),

          // ── Product list ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _nutritionUnavailable
                    ? _buildNutritionUnavailable()
                    : _filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final ranked = _filtered[i];
                          final isCurrent =
                              ranked.evaluation.product.id == widget.sourceProduct.id;
                          return RankedProductCard(
                            ranked: ranked,
                            isCurrent: isCurrent,
                            onTap: () async {
                              if (widget.saveToHistory) {
                                // Normal flow: return result to caller (ProductDetailScreen)
                                Navigator.pop(
                                  context,
                                  {
                                    'product': ranked.evaluation.product,
                                    'comparisonSet': _allRanked,
                                  },
                                );
                              } else {
                                // Saved comparison flow: navigate directly to ProductDetailScreen
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: ranked.evaluation.product,
                                      comparisonSet: _allRanked,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),

      // ── Floating mic button (matching design) ─────────────────────
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  Widget _buildNutritionUnavailable() {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              loc.nutritionDataUnavailable,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            loc.noProductsFound,
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            loc.noSearchMatchDesc,
            style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
