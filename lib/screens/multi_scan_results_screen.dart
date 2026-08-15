import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/voice_assistant_service.dart';
import 'product_detail_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_mic_overlay.dart';
import '../data/models/ranked_product_result.dart';
import '../data/models/health_profile.dart';
import '../core/utils/nutrition_availability.dart';
import '../data/services/backend_locator.dart';
import '../widgets/ranked_product_card.dart';
import '../services/home_tab_controller.dart';
import '../services/haptic_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.detectedProducts.isNotEmpty) {
      VoiceAssistantService.setLatestScanProduct(widget.detectedProducts.first);
    }
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('multi_scan_results');
    }
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
        products: widget.detectedProducts,
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
      products: widget.detectedProducts,
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
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color: colorScheme.primary, size: 24),
                  ),
                ),
                // Right Filter Ranking Button (matches compare_products_screen)
                if (_profile != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _ranked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
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