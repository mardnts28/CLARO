import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import 'product_detail_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../data/models/ranked_product_result.dart';
import '../data/services/backend_locator.dart';

class CompareProductsScreen extends StatefulWidget {
  /// The product the user is currently viewing — used to filter by category
  /// and to highlight it in the list.
  final Product sourceProduct;

  const CompareProductsScreen({super.key, required this.sourceProduct});

  @override
  State<CompareProductsScreen> createState() => _CompareProductsScreenState();
}

class _CompareProductsScreenState extends State<CompareProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = true;
  String? _error;

  // Full ranked comparison set (scanned product + alternatives in the same
  // category), from ProductComparisonService.compareWithAlternatives --
  // backed by WhoCalculator.rankProducts under the hood. Free/pure-Dart,
  // no Gemini call happens just to build this list.
  List<RankedProductResult> _allRanked = [];
  List<RankedProductResult> _filtered = [];

  @override
  void initState() {
    super.initState();
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
      final ranked = await BackendLocator.productComparisonService.compareWithAlternatives(
        scannedProduct: widget.sourceProduct,
        user: profile,
      );

      if (!mounted) return;
      setState(() {
        _allRanked = ranked;
        _filtered = List.from(ranked);
        _loading = false;
      });
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

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_allRanked)
          : _allRanked
              .where((r) =>
                  r.evaluation.product.name.toLowerCase().contains(q) ||
                  r.evaluation.product.brand.toLowerCase().contains(q) ||
                  r.evaluation.product.variant.toLowerCase().contains(q))
              .toList();
    });
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
          if (!_loading && _error == null)
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
                          return _ProductCard(
                            ranked: ranked,
                            isCurrent: isCurrent,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  product: ranked.evaluation.product,
                                  comparisonSet: _allRanked,
                                ),
                              ),
                            ),
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

// ── Individual product list card ─────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final RankedProductResult ranked;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ProductCard({
    required this.ranked,
    required this.isCurrent,
    required this.onTap,
  });

  Color _labelColor() {
    switch (ranked.suitabilityRankLabel) {
      case SuitabilityRankLabel.mostSuitable:
        return Colors.green;
      case SuitabilityRankLabel.middle:
        return Colors.amber.shade800;
      case SuitabilityRankLabel.leastSuitable:
        return Colors.deepOrange;
      case SuitabilityRankLabel.forcedLast:
        return Colors.red;
    }
  }

  String _labelText() {
    switch (ranked.suitabilityRankLabel) {
      case SuitabilityRankLabel.mostSuitable:
        return 'Most Suitable';
      case SuitabilityRankLabel.middle:
        return 'Middle';
      case SuitabilityRankLabel.leastSuitable:
        return 'Least Suitable';
      case SuitabilityRankLabel.forcedLast:
        return 'Allergen Warning';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final product = ranked.evaluation.product;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(color: colorScheme.primary.withOpacity(0.5), width: 1.5)
              : Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _labelColor().withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: _labelColor()),
              ),
              child: Text(
                '${ranked.rank}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _labelColor(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Product name + size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCurrent) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Kasalukuyan',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          product.name,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        product.nutritionalFacts.servingSize,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _labelColor().withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _labelText(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _labelColor(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Nutrition quick-stats row
                  Row(
                    children: [
                      _miniStat(context,
                          '⚡', product.nutritionalFacts.calories),
                      const SizedBox(width: 10),
                      _miniStat(context,
                          '🥩', product.nutritionalFacts.protein),
                      const SizedBox(width: 10),
                      _miniStat(context,
                          '🫙', product.nutritionalFacts.sodium),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right,
                color: colorScheme.onSurfaceVariant, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, String emoji, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}