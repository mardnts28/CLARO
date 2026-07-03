import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
import '../services/product_db_service.dart';
import 'camera_scanner_screen.dart';
import 'product_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  final ProductDbService _dbService = ProductDbService();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<void>? _subscription;

  String _activeTab = 'Lahat'; // 'Lahat', 'Paborito', 'Kumpara'
  String _searchQuery = '';

  static const _tabs = ['Lahat', 'Paborito', 'Kumpara'];

  @override
  void initState() {
    super.initState();
    _subscription = _historyService.onUpdate.listen((_) {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Group items by date label (Ngayon / Kahapon / Mas Maaga) ──────────────
  Map<String, List<HistoryItem>> _groupItems(List<HistoryItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<HistoryItem>> grouped = {
      'Ngayon': [],
      'Kahapon': [],
      'Mas Maaga': [],
    };

    for (final item in items) {
      final d = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      if (d == today) {
        grouped['Ngayon']!.add(item);
      } else if (d == yesterday) {
        grouped['Kahapon']!.add(item);
      } else {
        grouped['Mas Maaga']!.add(item);
      }
    }

    // Remove empty groups
    grouped.removeWhere((_, list) => list.isEmpty);
    return grouped;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Burahin ang Lahat?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Mabubura ang lahat ng kasaysayan ng iyong mga scan. Hindi ito maibabalik.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Kanselahin',
                style: GoogleFonts.inter(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              _historyService.clearAllHistory();
              Navigator.pop(ctx);
            },
            child: Text('Burahin',
                style: GoogleFonts.inter(
                    color: const Color(0xFFB71C1C),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build a single scan-type card ─────────────────────────────────────────
  Widget _buildScanCard(HistoryItem item) {
    final product = item.productId != null
        ? _dbService.getProductById(item.productId!)
        : null;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _historyService.deleteRecord(item.id),
      child: GestureDetector(
        onTap: () {
          if (product != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Product image or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFFF5F5F5),
                  child: product != null
                      ? Image.asset(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFFB71C1C),
                              size: 30),
                        )
                      : const Icon(Icons.inventory_2_outlined,
                          color: Color(0xFFB71C1C), size: 30),
                ),
              ),
              const SizedBox(width: 12),
              // Product name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.timestamp),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              // Favorite heart toggle
              GestureDetector(
                onTap: () => _historyService.toggleFavorite(item.id),
                child: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: item.isFavorite
                      ? const Color(0xFFB71C1C)
                      : Colors.black26,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build a single comparison-type card (same layout as scan card) ─────────
  Widget _buildCompareCard(HistoryItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _historyService.deleteRecord(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Compare icon placeholder — same size as product image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                height: 52,
                color: const Color(0xFFFFEBEE),
                child: const Center(
                  child: Icon(Icons.compare_arrows_rounded,
                      color: Color(0xFFB71C1C), size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(item.timestamp),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            // Compare badge icon on right
            const Icon(Icons.bar_chart_rounded,
                color: Color(0xFFB71C1C), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(String label, List<HistoryItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          label,
          style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => item.type == HistoryType.comparison
            ? _buildCompareCard(item)
            : _buildScanCard(item)),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  Widget _navItem(IconData icon, String label, bool active,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active ? const Color(0xFFB71C1C) : Colors.black38,
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

  Widget _navItemScan() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CameraScannerScreen())),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner, color: Colors.black38, size: 26),
          const SizedBox(height: 2),
          Text('Scan',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.black38,
                  fontWeight: FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final items = _historyService.getItems(
        filter: _activeTab, searchQuery: _searchQuery);
    final grouped = _groupItems(items);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EE),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.mic, size: 26),
      ),
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
            _navItemScan(),
            // History tab is active
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history,
                        color: Color(0xFFB71C1C), size: 26),
                    const SizedBox(height: 2),
                    Text('History',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFB71C1C),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            _navItem(Icons.person_outline, 'Profile', false),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
                top: topPadding + 8, left: 20, right: 20, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: title + clear button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'History',
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showClearAllDialog,
                      child: Text(
                        'Burahin Lahat',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFB71C1C),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      const Icon(Icons.search,
                          color: Colors.black38, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 14, color: Colors.black38),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: const Icon(Icons.close,
                              color: Colors.black38, size: 18),
                        ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Tab row
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EAEA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: _tabs.map((tab) {
                      final isActive = _activeTab == tab;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _activeTab = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                tab,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFFB71C1C)
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable content ───────────────────────────────────────────
          Expanded(
            child: grouped.isEmpty
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    children: grouped.entries
                        .map((e) =>
                            _buildGroupSection(e.key, e.value))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_activeTab == 'Paborito') {
      message = 'Wala pang mga paboritong produkto.\nI-tap ang ❤️ upang mag-save.';
    } else if (_activeTab == 'Kumpara') {
      message = 'Wala pang mga pag-uugnayan ng produkto.';
    } else if (_searchQuery.isNotEmpty) {
      message = 'Walang resulta para sa "$_searchQuery".';
    } else {
      message =
          'Wala pang kasaysayan ng scan.\nI-scan ang isang produkto upang magsimula!';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history,
                color: Color(0xFFDDBBBB), size: 72),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black38,
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
