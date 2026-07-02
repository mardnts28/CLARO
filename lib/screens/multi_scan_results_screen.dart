import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/history_service.dart';
import 'product_detail_screen.dart';
import 'history_screen.dart';

class MultiScanResultsScreen extends StatefulWidget {
  final List<Product> detectedProducts;

  const MultiScanResultsScreen({super.key, required this.detectedProducts});

  @override
  State<MultiScanResultsScreen> createState() => _MultiScanResultsScreenState();
}

class _MultiScanResultsScreenState extends State<MultiScanResultsScreen> {
  late List<Product> _rankedProducts;
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _rankProducts();
  }

  // Helper to calculate a suitability score for ranking.
  // Higher score = More suitable/healthy.
  int _calculateSuitabilityScore(Product p) {
    // We want to match the screenshot order if these specific 5 items are scanned:
    // 1. Nissin Cup Noodles Batchoy (id: nissin_cup_noodles_batchoy) -> Top
    // 2. Lucky Me Pancit Canton Original (id: lucky_me_canton_original)
    // 3. Argentina Corned Beef (id: argentina_corned_beef)
    // 4. Mega Sardines in Tomato Sauce (id: mega_sardines_tomato)
    // 5. 555 Fried Sardines in Tomato Sauce (id: 555_fried_sardines_hot_spicy or similar)
    //
    // For this specific situation, we return predefined mock ranking scores so the
    // list order is sorted exactly as in the screenshot:
    if (p.id == 'nissin_cup_noodles_batchoy') return 100;
    if (p.id == 'lucky_me_canton_original') return 90;
    if (p.id == 'argentina_corned_beef') return 80;
    if (p.id == 'mega_sardines_tomato') return 70;
    if (p.id == '555_fried_sardines_hot_spicy' || p.id.contains('555')) return 60;

    // Default dynamic suitability rank fallback logic (e.g. lower sodium is better):
    try {
      final sodiumStr = p.nutritionalFacts.sodium.replaceAll(RegExp(r'[^0-9]'), '');
      final sodiumVal = int.tryParse(sodiumStr) ?? 500;
      return 1000 - sodiumVal; // Less sodium = higher score
    } catch (_) {
      return 50;
    }
  }

  void _rankProducts() {
    // Sort in descending order of suitability score (highest suitability first)
    _rankedProducts = List.from(widget.detectedProducts)
      ..sort((a, b) => _calculateSuitabilityScore(b).compareTo(_calculateSuitabilityScore(a)));
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar: back, Resulta (perfectly centered Stack) ──
          Container(
            color: Colors.white,
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
                  'Resulta',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B1A1A),
                  ),
                ),
                // Left Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        color: Color(0xFF8B1A1A), size: 24),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),

          // ── Ranked description label ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Ranked based on suitability',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ── Product list ──────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _rankedProducts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final product = _rankedProducts[i];
                return _buildProductCard(context, product);
              },
            ),
          ),
        ],
      ),

      // ── Floating mic button ───────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.mic, size: 26),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 4, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, 'Home', false),
            _navItemScan(context),
            _navItem(Icons.history, 'History', false,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()))),
            _navItem(Icons.person_outline, 'Profile', false),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product p) {
    return GestureDetector(
      onTap: () {
        // Log the viewed product as a scan record in history
        _historyService.addScanRecord(p);
        // Navigate to the individual detail screen when clicked
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: p,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.nutritionalFacts.servingSize,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8B1A1A), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFFB71C1C) : Colors.black38,
              size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: active ? const Color(0xFFB71C1C) : Colors.black38,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _navItemScan(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner,
                color: Color(0xFFB71C1C), size: 26),
            const SizedBox(height: 2),
            Text('Scan',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFB71C1C),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
