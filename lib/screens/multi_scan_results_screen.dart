import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import 'product_detail_screen.dart';
import 'camera_scanner_screen.dart';
import 'history_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../data/models/ranked_product_result.dart';
import '../data/models/health_profile.dart';
import '../core/utils/nutrition_availability.dart';
import '../data/services/backend_locator.dart';

class MultiScanResultsScreen extends StatefulWidget {
  final List<Product> detectedProducts;

  const MultiScanResultsScreen({super.key, required this.detectedProducts});

  @override
  State<MultiScanResultsScreen> createState() => _MultiScanResultsScreenState();
}

class _MultiScanResultsScreenState extends State<MultiScanResultsScreen> {
  final _authService = AuthService();

  bool _loading = true;
  bool _nutritionUnavailable = false;
  List<RankedProductResult> _ranked = [];

  @override
  void initState() {
    super.initState();
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
        _ranked = ranked;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error ranking scanned products: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
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
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── Ranked description label ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              loc.rankedBySuitability,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _ranked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final ranked = _ranked[i];
                      return _buildProductCard(context, ranked);
                    },
                  ),
          ),
        ],
      ),

      // ── Floating mic button ───────────────────────────────────────
      floatingActionButton: const VoiceAssistantFab(),

      // ── Bottom Navigation Bar ─────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 4, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, 'Home', false),
            _navItemScan(context),
            _navItem(Icons.history, 'History', false),
            _navItem(Icons.person_outline, 'Profile', false),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, RankedProductResult ranked) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final p = ranked.evaluation.product;

    return GestureDetector(
      onTap: () {
        // Navigate to the individual detail screen, passing the full
        // ranked set so the detail screen can show the comparison matrix
        // and ranking explanation for this scan event too.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: p,
              comparisonSet: _ranked,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${ranked.rank}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.nutritionalFacts.servingSize,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () {
        if (label == loc.home) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CameraScannerScreen()),
          );
        } else if (label == loc.history) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        } else if (label == loc.profile) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.profileFeatureSoon, style: GoogleFonts.inter()),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? activeColor : inactiveColor,
              size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: active ? activeColor : inactiveColor,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _navItemScan(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner,
                color: colorScheme.primary, size: 26),
            const SizedBox(height: 2),
            Text(loc.scan,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}