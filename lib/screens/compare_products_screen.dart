import 'dart:async';
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
import '../core/utils/product_characteristics.dart';
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

  // Empty set == "Overall" (all of the user's conditions, i.e. the
  // profile as saved). Non-empty == ranking narrowed to just those
  // condition(s) -- multi-select, so the user can combine e.g. Diabetes
  // + Hypertension. Defaults to whichever of the 3 conditions are
  // actually on the user's saved health profile once it loads (see
  // _loadRanking), so the initial view already reflects their profile.
  Set<HealthCondition> _selectedConditions = {};

  // Product Type / Flavor filter chips -- membership filters (hide
  // non-matching products) layered on top of the health-condition
  // re-ranking above. Multi-select within each group (OR): e.g. selecting
  // both "Chicken" and "Beef" shows either. Between groups (type AND
  // flavor) it's AND: selecting "Chicken" + "Spicy" shows only spicy
  // chicken products. Built from ProductCharacteristics -- the same
  // keyword lists ProductComparisonService already used to decide which
  // products belong in this screen's set in the first place.
  static const String _spicyTag = '__spicy__';
  static const String _nonSpicyTag = '__non_spicy__';

  final Set<String> _selectedTypeTags = {};
  final Set<String> _selectedFlavorTags = {};

  // Chip OPTIONS shown in the filter sheet -- derived once from the
  // actual products in this comparison set (not a static per-category
  // list), so a chip never appears for a tag that has zero matches in
  // the current results.
  Set<String> _availableTypeTags = {};
  Set<String> _availableFlavorTags = {};
  bool _hasSpicyOption = false;

  bool get _hasActiveTagFilters =>
      _selectedTypeTags.isNotEmpty || _selectedFlavorTags.isNotEmpty;

  // Scenario B only: the ranked list can hold more than
  // kMaxProductsPerRanking products now that compareWithAlternatives
  // returns every same-category match. false == show only the top 5;
  // true == "See More" was tapped, show the rest in the same ranked
  // order. Ignored while a search query is active -- search shows every
  // matching result regardless of this flag.
  bool _expanded = false;

  static const int _initialVisibleCount = 5;

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('compare_products');
    }
    _searchCtrl.addListener(_onSearch);
    _loadRanking();
  }

  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _filtered = _computeFiltered(_allRanked);
        });
      }
    });
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
        _computeAvailableTags();
        // Pre-check whichever of the 3 filterable conditions the user
        // actually has on their saved profile. `ranked` was already
        // computed against the full profile above, so this matches the
        // list just shown -- it's the same ranking, just reflected in
        // the filter UI's default state.
        _selectedConditions = HealthCondition.values
            .where(profile.conditions.contains)
            .toSet();
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

  /// Scans the fixed comparison set once (after load) to find which
  /// Product Type / Flavor keywords actually occur in it -- these become
  /// the chip options offered in the filter sheet. "Spicy" is offered
  /// separately (as a Spicy/Non-Spicy toggle) whenever at least one
  /// product in the set matches a spicy keyword.
  void _computeAvailableTags() {
    final typeTags = <String>{};
    final flavorTags = <String>{};
    var hasSpicy = false;

    for (final product in _comparisonProducts) {
      typeTags.addAll(ProductCharacteristics.typeTags(product));
      final flavors = ProductCharacteristics.flavorTags(product);
      flavorTags.addAll(flavors.where(
        (f) => !ProductCharacteristics.spicyKeywords.contains(f),
      ));
      if (flavors.any(ProductCharacteristics.spicyKeywords.contains)) {
        hasSpicy = true;
      }
    }

    _availableTypeTags = typeTags;
    _availableFlavorTags = flavorTags;
    _hasSpicyOption = hasSpicy;
  }

  /// True if [product] matches the currently-selected Product Type /
  /// Flavor filters. Type tags are OR'd together, flavor tags are OR'd
  /// together, and (when both groups have a selection) the two groups
  /// combine with AND -- standard faceted-filter behavior.
  bool _matchesTagFilters(Product product) {
    if (_selectedTypeTags.isNotEmpty) {
      final productTypeTags = ProductCharacteristics.typeTags(product);
      if (productTypeTags.intersection(_selectedTypeTags).isEmpty) {
        return false;
      }
    }

    if (_selectedFlavorTags.isNotEmpty) {
      final productFlavorTags = ProductCharacteristics.flavorTags(product);
      final isSpicy = ProductCharacteristics.isSpicy(product);
      final matchesAnySelectedFlavor = _selectedFlavorTags.any((tag) {
        if (tag == _spicyTag) return isSpicy;
        if (tag == _nonSpicyTag) return !isSpicy;
        return productFlavorTags.contains(tag);
      });
      if (!matchesAnySelectedFlavor) return false;
    }

    return true;
  }

  List<RankedProductResult> _computeFiltered(List<RankedProductResult> source) {
    Iterable<RankedProductResult> results = source;

    if (_hasActiveTagFilters) {
      results =
          results.where((r) => _matchesTagFilters(r.evaluation.product));
    }

    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      results = results.where((r) =>
          r.evaluation.product.name.toLowerCase().contains(q) ||
          r.evaluation.product.brand.toLowerCase().contains(q) ||
          r.evaluation.product.variant.toLowerCase().contains(q));
    }

    return results.toList();
  }



  /// Re-ranks the SAME comparison set (no new DB fetch, no new Gemini call)
  /// against a health profile narrowed to just [condition] -- or the full
  /// profile when [condition] is null ("Overall") -- and applies the given
  /// Product Type / Flavor tag selections. Runs through the exact same
  /// WhoCalculator.rankProducts pipeline as the default ranking; the only
  /// thing that changes is which condition(s) are on the profile passed
  /// in, so a single-condition filter naturally focuses the score on that
  /// condition's nutrient(s) without any separate ranking logic. Tag
  /// filtering happens afterward, in _computeFiltered -- it narrows which
  /// of the re-ranked results are shown, it never changes their order.
  void _reRankAndFilter({
    required Set<HealthCondition> conditions,
    required Set<String> typeTags,
    required Set<String> flavorTags,
  }) {
    final profile = _profile;
    if (profile == null) return;

    // Empty selection == "Overall" -- rank against the profile exactly as
    // saved (every condition the user has). A non-empty selection narrows
    // the effective profile to just those condition(s), which can be one
    // or several at once.
    final effectiveProfile = conditions.isEmpty
        ? profile
        : UserHealthProfile(
            userId: profile.userId,
            displayName: profile.displayName,
            conditions: conditions.toList(),
            allergies: profile.allergies,
            voiceAssistant: profile.voiceAssistant,
          );

    // Same Scenario B set as the initial load -- can legitimately exceed
    // kMaxProductsPerRanking, so the cap enforced for Scenario A must stay
    // off here too.
    final reRanked = BackendLocator.productRankingService.rankProducts(
      products: _comparisonProducts,
      user: effectiveProfile,
      enforceMaxCap: false,
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
      // Re-ranking/re-filtering can change which products land in the top
      // 5, so collapse back to the initial view rather than keep an
      // expansion state that no longer matches.
      _expanded = false;
    });
  }

  /// Quick single-change helper -- used by the inline "X" remove chips on
  /// the main screen, which only ever touch one filter at a time and keep
  /// everything else as-is.
  void _selectConditionFilter(Set<HealthCondition> conditions) {
    _reRankAndFilter(
      conditions: conditions,
      typeTags: _selectedTypeTags,
      flavorTags: _selectedFlavorTags,
    );
  }

  /// Removes a single condition from the current multi-select, keeping
  /// the rest of the selection (and the Product Type/Flavor filters)
  /// untouched. Mirrors _removeTypeTag/_removeFlavorTag below.
  void _removeConditionTag(HealthCondition condition) {
    final updated = Set<HealthCondition>.from(_selectedConditions)
      ..remove(condition);
    _selectConditionFilter(updated);
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
  /// Spicy/Non-Spicy are localized (small, fixed pair); everything else
  /// is a title-cased version of the raw catalog keyword -- see
  /// ProductCharacteristics.displayLabel for why those aren't localized.
  String _tagLabel(String tag) {
    final loc = AppLocalizations.of(context)!;
    if (tag == _spicyTag) return loc.spicyLabel;
    if (tag == _nonSpicyTag) return loc.nonSpicyLabel;
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
                onSelected: (_) => onTap(),
                selectedColor: colorScheme.primary.withOpacity(0.15),
                checkmarkColor: colorScheme.primary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
                ),
                side: BorderSide(
                  color: selected
                      ? colorScheme.primary.withOpacity(0.5)
                      : theme.dividerColor,
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
                    // Multi-select: any combination of the 3 conditions
                    // can be checked at once (e.g. Diabetes + Heart
                    // Condition together).
                    for (final condition in HealthCondition.values)
                      CheckboxListTile(
                        value: tempConditions.contains(condition),
                        activeColor: colorScheme.primary,
                        title: Text(_conditionLabel(condition)),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            tempConditions.add(condition);
                          } else {
                            tempConditions.remove(condition);
                          }
                        }),
                      ),

                    // ── Product Type (only shown if this comparison set
                    // actually has products with a curated type tag) ────
                    if (_availableTypeTags.isNotEmpty) ...[
                      Divider(height: 1, color: theme.dividerColor),
                      sectionTitle(loc.filterProductTypeTitle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                      Divider(height: 1, color: theme.dividerColor),
                      sectionTitle(loc.filterFlavorTitle),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                                selected:
                                    tempFlavorTags.contains(_nonSpicyTag),
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
                            child: OutlinedButton(
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
                        if (_selectedConditions.isNotEmpty || _hasActiveTagFilters)
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

          // ── Category chip + active filter chips ────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                Text(
                  loc.productCount(_allRanked.length),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                for (final condition in _selectedConditions)
                  _buildRemovableChip(
                    label: _conditionLabel(condition),
                    onRemove: () => _removeConditionTag(condition),
                  ),
                for (final tag in _selectedTypeTags)
                  _buildRemovableChip(
                    label: _tagLabel(tag),
                    onRemove: () => _removeTypeTag(tag),
                  ),
                for (final tag in _selectedFlavorTags)
                  _buildRemovableChip(
                    label: _tagLabel(tag),
                    onRemove: () => _removeFlavorTag(tag),
                  ),
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
                    : _buildRankedList(),
          ),
        ],
      ),

      // ── Floating mic button (matching design) ─────────────────────
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  /// Builds the ranked list with Scenario B's "top 5 + See More" behavior.
  /// While a search query is active, this is bypassed entirely -- every
  /// matching result is shown, since search is a deliberate lookup rather
  /// than browsing the ranked order.
  Widget _buildRankedList() {
    final isSearching = _searchCtrl.text.trim().isNotEmpty;
    final hasMore = !isSearching && _filtered.length > _initialVisibleCount;
    final showSeeMore = hasMore && !_expanded;
    final visibleCount = isSearching || _expanded
        ? _filtered.length
        : _filtered.length.clamp(0, _initialVisibleCount);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: visibleCount + (showSeeMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (showSeeMore && i == visibleCount) {
          return _buildSeeMoreButton();
        }

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
          color: colorScheme.secondary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.secondary.withOpacity(0.4)),
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

  Widget _buildSeeMoreButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final remaining = _filtered.length - _initialVisibleCount;

    return GestureDetector(
      onTap: () {
        HapticService().vibrate();
        setState(() => _expanded = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${loc.seeMore} ($remaining)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
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