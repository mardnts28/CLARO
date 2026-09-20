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
import '../widgets/selectable_scanned_product_card.dart';
import '../data/models/ranked_product_result.dart';
import '../data/services/backend_locator.dart';
import '../core/utils/nutrition_availability.dart';
import '../core/utils/product_characteristics.dart';
import '../core/utils/success_feedback_utils.dart';
import '../data/models/health_profile.dart';
import '../widgets/ranked_product_card.dart';
import 'product_detail_screen.dart';
import 'camera_scanner_screen.dart';

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

  List<RankedProductResult> _allRanked = [];
  List<RankedProductResult> _filtered = [];

  UserHealthProfile? _profile;
  List<Product> _comparisonProducts = [];

  Set<HealthCondition> _selectedConditions = {};

  static const String _spicyTag = '__spicy__';
  static const String _nonSpicyTag = '__non_spicy__';

  final Set<String> _selectedTypeTags = {};
  final Set<String> _selectedFlavorTags = {};

  Set<String> _availableTypeTags = {};
  Set<String> _availableFlavorTags = {};
  bool _hasSpicyOption = false;

  bool get _hasActiveTagFilters =>
      _selectedTypeTags.isNotEmpty || _selectedFlavorTags.isNotEmpty;

  bool _expanded = false;

  static const int _initialVisibleCount = 5;

  @override
  void initState() {
    super.initState();

    if (_authService.currentUser != null &&
        VoiceAssistantService.instance.isEnabled) {
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

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () {
        if (mounted) {
          setState(() {
            _filtered = _computeFiltered(_allRanked);
          });
        }
      },
    );
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

      final profile =
          await BackendLocator.userRepository.getHealthProfile(uid);

      if (!NutritionAvailability.isAvailable(widget.sourceProduct)) {
        if (mounted) {
          setState(() {
            _nutritionUnavailable = true;
            _loading = false;
          });
        }
        return;
      }

      final ranked =
          await BackendLocator.productComparisonService.compareWithAlternatives(
        scannedProduct: widget.sourceProduct,
        user: profile,
      );

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _comparisonProducts =
            ranked.map((r) => r.evaluation.product).toList();
        _allRanked = ranked;
        _filtered = List.from(ranked);
        _loading = false;

        _computeAvailableTags();

        _selectedConditions = HealthCondition.values
            .where(profile.conditions.contains)
            .toSet();
      });

      _updateVoiceSummary(ranked);

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

  void _updateVoiceSummary(List<RankedProductResult> ranked) {
    if (ranked.isEmpty) return;

    final source = widget.sourceProduct;
    final top = ranked.first;
    final topProduct = top.evaluation.product;

    final isTagalog =
        VoiceAssistantService.languageNotifier.value == VoiceLang.tagalog;

    final summary = isTagalog
        ? 'Resulta ng paghahambing para sa ${source.name}. Mayroong ${ranked.length} na mga produkto sa kategoryang ito. Ang nangungunang rekomendasyon ay ${topProduct.name}.'
        : 'Comparison results for ${source.name}. Found ${ranked.length} products in this category. The top recommendation is ${topProduct.name}.';

    VoiceAssistantService.setLatestScanSummary(summary);
  }

  void _computeAvailableTags() {
    final typeTags = <String>{};
    final flavorTags = <String>{};
    var hasSpicy = false;

    for (final product in _comparisonProducts) {
      typeTags.addAll(ProductCharacteristics.typeTags(product));

      final flavors = ProductCharacteristics.flavorTags(product);

      flavorTags.addAll(
        flavors.where(
          (f) => !ProductCharacteristics.spicyKeywords.contains(f),
        ),
      );

      if (flavors.any(ProductCharacteristics.spicyKeywords.contains)) {
        hasSpicy = true;
      }
    }

    _availableTypeTags = typeTags;
    _availableFlavorTags = flavorTags;
    _hasSpicyOption = hasSpicy;
  }

  bool _matchesTagFilters(Product product) {
    if (_selectedTypeTags.isNotEmpty) {
      final productTypeTags = ProductCharacteristics.typeTags(product);

      if (productTypeTags.intersection(_selectedTypeTags).isEmpty) {
        return false;
      }
    }

    if (_selectedFlavorTags.isNotEmpty) {
      final productFlavorTags =
          ProductCharacteristics.flavorTags(product);

      final isSpicy = ProductCharacteristics.isSpicy(product);

      final spicySelection =
          _selectedFlavorTags.intersection({
        _spicyTag,
        _nonSpicyTag,
      });

      final keywordSelection =
          _selectedFlavorTags.difference({
        _spicyTag,
        _nonSpicyTag,
      });

      if (spicySelection.isNotEmpty) {
        final matchesSpicy = spicySelection.any((tag) {
          if (tag == _spicyTag) {
            return isSpicy;
          }

          return !isSpicy;
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

  List<RankedProductResult> _computeFiltered(
    List<RankedProductResult> source,
  ) {
    Iterable<RankedProductResult> results = source;

    if (_hasActiveTagFilters) {
      results = results.where(
        (r) => _matchesTagFilters(r.evaluation.product),
      );
    }

    final q = _searchCtrl.text.toLowerCase().trim();

    if (q.isNotEmpty) {
      results = results.where(
        (r) =>
            r.evaluation.product.name.toLowerCase().contains(q) ||
            r.evaluation.product.brand.toLowerCase().contains(q) ||
            r.evaluation.product.variant.toLowerCase().contains(q),
      );
    }

    return results.toList();
  }

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

    final reRanked =
        BackendLocator.productRankingService.rankProducts(
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
      _expanded = false;
    });
  }

  void _selectConditionFilter(Set<HealthCondition> conditions) {
    _reRankAndFilter(
      conditions: conditions,
      typeTags: _selectedTypeTags,
      flavorTags: _selectedFlavorTags,
    );
  }

  void _removeConditionTag(HealthCondition condition) {
    final updated =
        Set<HealthCondition>.from(_selectedConditions)
          ..remove(condition);

    _selectConditionFilter(updated);
  }

  void _removeTypeTag(String tag) {
    final updated =
        Set<String>.from(_selectedTypeTags)..remove(tag);

    _reRankAndFilter(
      conditions: _selectedConditions,
      typeTags: updated,
      flavorTags: _selectedFlavorTags,
    );
  }

  void _removeFlavorTag(String tag) {
    final updated =
        Set<String>.from(_selectedFlavorTags)..remove(tag);

    _reRankAndFilter(
      conditions: _selectedConditions,
      typeTags: _selectedTypeTags,
      flavorTags: updated,
    );
  }

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

    final tempConditions =
        Set<HealthCondition>.from(_selectedConditions);

    final tempTypeTags =
        Set<String>.from(_selectedTypeTags);

    final tempFlavorTags =
        Set<String>.from(_selectedFlavorTags);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget sectionTitle(String text) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  8,
                ),
                child: Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              );
            }

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
                selectedColor:
                    colorScheme.primary.withOpacity(0.15),
                checkmarkColor: colorScheme.primary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                side: BorderSide.none,
                elevation: 2,
                pressElevation: 4,
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

                    for (final condition in HealthCondition.values)
                      CheckboxListTile(
                        value: tempConditions.contains(condition),
                        activeColor: colorScheme.primary,
                        title: Text(
                          _conditionLabel(condition),
                        ),
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

                    if (_availableTypeTags.isNotEmpty) ...[
                      Divider(
                        height: 1,
                        color: theme.dividerColor,
                      ),

                      sectionTitle(
                        loc.filterProductTypeTitle,
                      ),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in _availableTypeTags)
                              tagChip(
                                label: _tagLabel(tag),
                                selected:
                                    tempTypeTags.contains(tag),
                                onTap: () =>
                                    setSheetState(() {
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

                    if (_hasSpicyOption ||
                        _availableFlavorTags.isNotEmpty) ...[
                      Divider(
                        height: 1,
                        color: theme.dividerColor,
                      ),

                      sectionTitle(
                        loc.filterFlavorTitle,
                      ),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_hasSpicyOption) ...[
                              tagChip(
                                label: loc.spicyLabel,
                                selected:
                                    tempFlavorTags.contains(
                                  _spicyTag,
                                ),
                                onTap: () =>
                                    setSheetState(() {
                                  if (!tempFlavorTags.remove(
                                    _spicyTag,
                                  )) {
                                    tempFlavorTags
                                      ..remove(_nonSpicyTag)
                                      ..add(_spicyTag);
                                  }
                                }),
                              ),

                              tagChip(
                                label: loc.nonSpicyLabel,
                                selected:
                                    tempFlavorTags.contains(
                                  _nonSpicyTag,
                                ),
                                onTap: () =>
                                    setSheetState(() {
                                  if (!tempFlavorTags.remove(
                                    _nonSpicyTag,
                                  )) {
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
                                selected:
                                    tempFlavorTags.contains(tag),
                                onTap: () =>
                                    setSheetState(() {
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setSheetState(() {
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
                                backgroundColor:
                                    colorScheme.primary,
                                foregroundColor:
                                    colorScheme.onPrimary,
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

  void _handleBack() {
    HapticService().vibrate();

    if (widget.saveToHistory) {
      Navigator.pop(
        context,
        _allRanked.isNotEmpty
            ? {
                'product': widget.sourceProduct,
                'comparisonSet': _allRanked,
              }
            : null,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
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
                    onTap: _handleBack,
                    child: Icon(
                      Icons.arrow_back,
                      color: colorScheme.primary,
                      size: 24,
                    ),
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
                ],
              ),
            ),

            Divider(
              height: 1,
              color: theme.dividerColor,
            ),

            // ── Category chip + active filter chips ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  for (final condition in _selectedConditions)
                    _buildRemovableChip(
                      label: _conditionLabel(condition),
                      onRemove: () =>
                          _removeConditionTag(condition),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),

                  // Changed from outline to soft shadow
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.08),
                      blurRadius: 18,
                      spreadRadius: -5,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        theme.brightness == Brightness.dark
                            ? 0.12
                            : 0.045,
                      ),
                      blurRadius: 10,
                      spreadRadius: -6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  cursorColor: colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: loc.searchHint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurfaceVariant
                          .withOpacity(0.72),
                    ),

                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(
                        left: 15,
                        right: 9,
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: colorScheme.primary,
                        size: 23,
                      ),
                    ),

                    prefixIconConstraints:
                        const BoxConstraints(
                      minWidth: 48,
                      minHeight: 54,
                    ),

                    suffixIcon:
                        _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear search',
                                splashRadius: 20,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color:
                                      colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  FocusScope.of(context).unfocus();
                                  setState(() {});
                                },
                              )
                            : null,

                    suffixIconConstraints:
                        const BoxConstraints(
                      minWidth: 48,
                      minHeight: 54,
                    ),

                    filled: true,
                    fillColor: Colors.transparent,

                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),

                    // No outline/border
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Ranked-by-suitability label ───────────────────────────
            if (!_loading &&
                _error == null &&
                !_nutritionUnavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  4,
                ),
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
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _nutritionUnavailable
                      ? _buildNutritionUnavailable()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : _buildRankedList(),
            ),
          ],
        ),

        floatingActionButton:
            const VoiceAssistantFab(),
      ),
    );
  }

  Widget _buildRankedList() {
    final isSearching =
        _searchCtrl.text.trim().isNotEmpty;

    final hasMore =
        !isSearching &&
        _filtered.length > _initialVisibleCount;

    final showSeeMore =
        hasMore && !_expanded;

    final visibleCount =
        isSearching || _expanded
            ? _filtered.length
            : _filtered.length.clamp(
                0,
                _initialVisibleCount,
              );

    final addProductIndex =
        visibleCount + (showSeeMore ? 1 : 0);

    final bottomSafeInset =
        MediaQuery.of(context).padding.bottom;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + bottomSafeInset + 24,
      ),
      itemCount: addProductIndex + 1,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (showSeeMore && i == visibleCount) {
          return _buildSeeMoreButton();
        }

        if (i == addProductIndex) {
          return _buildAddProductButton();
        }

        final ranked = _filtered[i];

        final isCurrent =
            ranked.evaluation.product.id ==
                widget.sourceProduct.id;

        return RankedProductCard(
          ranked: ranked,
          isCurrent: isCurrent,
          onTap: () async {
            if (widget.saveToHistory) {
              Navigator.pop(
                context,
                {
                  'product': ranked.evaluation.product,
                  'comparisonSet': _allRanked,
                },
              );
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(
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

  Widget _buildAddProductButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: _openAddProductFlow,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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

  Future<void> _openAddProductFlow() async {
    HapticService().vibrate();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CameraScannerScreen(
          returnResultsOnDetect: true,
        ),
      ),
    );

    if (!mounted || result is! Map) return;

    final recognized = result['products'];

    if (recognized is! List) return;

    final products =
        recognized.whereType<Product>().toList();

    if (products.isEmpty) {
      final loc = AppLocalizations.of(context)!;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.noNewProductsDetected,
          ),
        ),
      );

      return;
    }

    _showAddProductSheet(products);
  }

  void _showAddProductSheet(
    List<Product> recognizedProducts,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    final Map<String, Product> distinctById = {
      for (final p in recognizedProducts) p.id: p,
    };

    final products =
        distinctById.values.toList();

    final existingIds =
        _comparisonProducts.map((p) => p.id).toSet();

    final Set<String> selectedIds = {};

    final bool anySelectable =
        products.any(
      (p) => !existingIds.contains(p.id),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            sheetContext,
            setSheetState,
          ) {
            final hasSelection =
                selectedIds.isNotEmpty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  sheetContext,
                ).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(sheetContext)
                              .size
                              .height *
                          0.85,
                ),
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius:
                      const BorderRadius.only(
                    topLeft:
                        Radius.circular(20),
                    topRight:
                        Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc
                            .selectProductsToAddTitle,
                        style:
                            GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              colorScheme
                                  .onSurface,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      if (!anySelectable)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: Text(
                            loc
                                .noNewProductsDetected,
                            style:
                                GoogleFonts.inter(
                              fontSize: 12,
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),

                      Flexible(
                        child:
                            ListView.separated(
                          shrinkWrap: true,
                          itemCount:
                              products.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(
                            height: 10,
                          ),
                          itemBuilder:
                              (context, i) {
                            final product =
                                products[i];

                            final alreadyRanked =
                                existingIds
                                    .contains(
                              product.id,
                            );

                            return SelectableScannedProductCard(
                              product: product,
                              selected:
                                  selectedIds
                                      .contains(
                                product.id,
                              ),
                              alreadyRanked:
                                  alreadyRanked,
                              onTap: () {
                                HapticService()
                                    .vibrate();

                                setSheetState(
                                  () {
                                    if (selectedIds
                                        .contains(
                                      product.id,
                                    )) {
                                      selectedIds
                                          .remove(
                                        product.id,
                                      );
                                    } else {
                                      selectedIds
                                          .add(
                                        product.id,
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            ElevatedButton(
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                colorScheme
                                    .primary,
                            foregroundColor:
                                colorScheme
                                    .onPrimary,
                            disabledBackgroundColor:
                                colorScheme
                                    .primary
                                    .withOpacity(
                                        0.3),
                            disabledForegroundColor:
                                colorScheme
                                    .onPrimary
                                    .withOpacity(
                                        0.7),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 14,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                          ),
                          onPressed:
                              hasSelection
                                  ? () {
                                      final selectedProducts =
                                          products
                                              .where(
                                                (p) =>
                                                    selectedIds.contains(
                                                  p.id,
                                                ),
                                              )
                                              .toList();

                                      Navigator.pop(
                                        sheetContext,
                                      );

                                      _addProductsToRanking(
                                        selectedProducts,
                                      );
                                    }
                                  : null,
                          child: Text(
                            loc.apply,
                            style:
                                GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight
                                      .bold,
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

  void _addProductsToRanking(
    List<Product> newProducts,
  ) {
    final profile = _profile;

    if (profile == null) return;

    final existingIds =
        _comparisonProducts.map((p) => p.id).toSet();

    final toAdd = <Product>[];

    for (final p in newProducts) {
      if (existingIds.contains(p.id)) continue;

      if (toAdd.any((q) => q.id == p.id)) {
        continue;
      }

      toAdd.add(p);
    }

    if (toAdd.isEmpty) return;

    _comparisonProducts = [
      ..._comparisonProducts,
      ...toAdd,
    ];

    _computeAvailableTags();

    _reRankAndFilter(
      conditions: _selectedConditions,
      typeTags: _selectedTypeTags,
      flavorTags: _selectedFlavorTags,
    );

    if (!mounted) return;

    final loc = AppLocalizations.of(context)!;

    SuccessFeedbackUtils.showSuccessSnackBar(
      context,
      loc.productsAddedToRanking(
        toAdd.length,
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
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color:
              colorScheme.secondary
                  .withOpacity(0.12),
          borderRadius:
              BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.secondary.withOpacity(0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color:
                    colorScheme.secondary,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(width: 4),

            Icon(
              Icons.close,
              size: 14,
              color:
                  colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeeMoreButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    final remaining =
        _filtered.length -
            _initialVisibleCount;

    return GestureDetector(
      onTap: () {
        HapticService().vibrate();

        setState(() {
          _expanded = true;
        });
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              colorScheme.primary
                  .withOpacity(0.08),
          borderRadius:
              BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.14),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              '${loc.seeMore} ($remaining)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color:
                    colorScheme.primary,
              ),
            ),

            const SizedBox(width: 4),

            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color:
                  colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionUnavailable() {
    final colorScheme =
        Theme.of(context).colorScheme;

    final loc =
        AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 32,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.6),
            ),

            const SizedBox(height: 16),

            Text(
              loc.nutritionDataUnavailable,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final colorScheme =
        Theme.of(context).colorScheme;

    final loc =
        AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme
                .onSurfaceVariant
                .withOpacity(0.4),
          ),

          const SizedBox(height: 16),

          Text(
            loc.noProductsFound,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            loc.noSearchMatchDesc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
