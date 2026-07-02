import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../services/product_db_service.dart';
import '../services/history_service.dart';
import 'product_detail_screen.dart';

class CompareProductsScreen extends StatefulWidget {
  /// The product the user is currently viewing — used to filter by category
  /// and to highlight it in the list.
  final Product sourceProduct;

  const CompareProductsScreen({super.key, required this.sourceProduct});

  @override
  State<CompareProductsScreen> createState() => _CompareProductsScreenState();
}

class _CompareProductsScreenState extends State<CompareProductsScreen> {
  final ProductDbService _db = ProductDbService();
  final HistoryService _historyService = HistoryService();
  final TextEditingController _searchCtrl = TextEditingController();

  late List<Product> _allInCategory;
  List<Product> _filtered = [];

  @override
  void initState() {
    super.initState();
    _allInCategory = _db.getProductsByCategory(
      widget.sourceProduct.category,
      excludeId: widget.sourceProduct.id,
    );
    _filtered = List.from(_allInCategory);
    _searchCtrl.addListener(_onSearch);
    // ── Log comparison session to history ──
    _historyService.addComparisonRecord(
      widget.sourceProduct.category,
      '${widget.sourceProduct.name} Variant Comparison',
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_allInCategory)
          : _allInCategory
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  p.brand.toLowerCase().contains(q) ||
                  p.variant.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: back + title ──────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: topPadding + 14,
              bottom: 14,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back,
                      color: Color(0xFF8B1A1A), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Kahalintulad na Produkto',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B1A1A),
                  ),
                ),
              ],
            ),
          ),

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
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEF9A9A)),
                  ),
                  child: Text(
                    widget.sourceProduct.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF8B1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_allInCategory.length} produkto',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.black45),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search,
                        color: Colors.black38, size: 22),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 14, color: Colors.black38),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.close,
                            color: Colors.black38, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Product list ──────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final product = _filtered[i];
                      final isCurrent =
                          product.id == widget.sourceProduct.id;
                      return _ProductCard(
                        product: product,
                        isCurrent: isCurrent,
                        onTap: () {
                          // Log the compared product view as a scan record
                          _historyService.addScanRecord(product);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: product,
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

      // ── Floating mic button (matching design) ─────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.mic, size: 26),
      ),

      // ── Bottom nav ────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4,
          top: 8,
        ),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            'Walang nahanap',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black45),
          ),
          const SizedBox(height: 6),
          Text(
            'No products matched your search.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active
                  ? const Color(0xFFB71C1C)
                  : Colors.black38,
              size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: active
                      ? const Color(0xFFB71C1C)
                      : Colors.black38,
                  fontWeight: active
                      ? FontWeight.w600
                      : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _navItemScan(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

// ── Individual product list card ─────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(color: const Color(0xFFEF9A9A), width: 1.5)
              : Border.all(color: const Color(0xFFEEEEEE)),
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
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Kasalukuyan',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF8B1A1A),
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
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.nutritionalFacts.servingSize,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.black45),
                  ),
                  const SizedBox(height: 6),
                  // Nutrition quick-stats row
                  Row(
                    children: [
                      _miniStat(
                          '⚡', product.nutritionalFacts.calories),
                      const SizedBox(width: 10),
                      _miniStat(
                          '🥩', product.nutritionalFacts.protein),
                      const SizedBox(width: 10),
                      _miniStat(
                          '🫙', product.nutritionalFacts.sodium),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            const Icon(Icons.chevron_right,
                color: Colors.black38, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
