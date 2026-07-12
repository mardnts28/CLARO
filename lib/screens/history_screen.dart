import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
import '../services/product_db_service.dart';
import '../services/auth_service.dart';
import '../data/services/backend_locator.dart';
import 'camera_scanner_screen.dart';
import 'product_detail_screen.dart';
import 'compare_products_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/product_model.dart';

class HistoryScreen extends StatefulWidget {
  final bool embeddedMode;
  const HistoryScreen({super.key, this.embeddedMode = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ── DEV-ONLY: seeds two real catalog products into this user's Firestore
  // history so the screen has something to show while testing. Gated by
  // kDebugMode so it never compiles into a release build. Delete this
  // method + the "Seed (dev)" button in build() once you're done testing.
  Future<void> _seedTestHistory() async {
    final db = ProductDbService();
    final tuna = db.getProductById('century_tuna_flakes_oil');
    final canton = db.getProductById('lucky_me_canton_hot_chili');

    if (tuna != null) await _historyService.addScanRecord(tuna);
    if (canton != null) await _historyService.addScanRecord(canton);
  }

  final HistoryService _historyService = HistoryService();
  final ProductDbService _dbService = ProductDbService();
  final TextEditingController _searchController = TextEditingController();
  final _authService = AuthService();
  StreamSubscription<void>? _subscription;

  String _activeTab = 'Lahat'; // 'Lahat', 'Paborito', 'Kumpara'
  String _searchQuery = '';

  // Favorites are loaded directly from BackendLocator.favoritesService
  // as full Product objects, independent of scan history. This shows all
  // favorited products regardless of how they were discovered (scan, compare, etc.).
  List<Product> _favoriteProducts = [];
  bool _favoritesLoading = true;

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
    _loadFavoriteProducts();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteProducts() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _favoritesLoading = false);
      return;
    }
    final products = await BackendLocator.favoritesService.getFavoriteProducts(uid);
    if (mounted) {
      setState(() {
        _favoriteProducts = products;
        _favoritesLoading = false;
      });
    }
  }

  Future<void> _toggleFavoriteForItem(HistoryItem item) async {
    final uid = _authService.currentUser?.uid;
    final productId = item.productId;
    if (uid == null || productId == null) return;

    // Optimistic update so the tap feels responsive.
    final wasFavorite = _favoriteProducts.any((p) => p.id == productId);
    setState(() {
      if (wasFavorite) {
        _favoriteProducts.removeWhere((p) => p.id == productId);
      } else {
        // For optimistic add, we'd need the full product. Since we don't have it
        // in the HistoryItem, we'll skip optimistic add and just show loading state.
        // The actual toggle will refresh the list.
      }
    });

    try {
      await BackendLocator.favoritesService.toggleFavorite(
        userId: uid,
        productId: productId,
      );
      // Refresh the full favorites list to get the correct state
      await _loadFavoriteProducts();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      // Revert by refreshing the list
      await _loadFavoriteProducts();
    }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.clearAllTitle,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        content: Text(
          loc.clearAllConfirm,
          style: GoogleFonts.inter(
              fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel,
                style: GoogleFonts.inter(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              _historyService.clearAllHistory();
              Navigator.pop(ctx);
            },
            child: Text(loc.clear,
                style: GoogleFonts.inter(
                    color: colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Build a single scan-type card ─────────────────────────────────────────
  Widget _buildScanCard(HistoryItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final product = item.productId != null
        ? _dbService.getProductById(item.productId!)
        : null;
    final isFavorite =
        item.productId != null && _favoriteProducts.any((p) => p.id == item.productId);

    // For Favorites tab, use unfavorite logic instead of delete
    final isFavoritesTab = _activeTab == 'Paborito';

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onPrimary, size: 26),
      ),
      onDismissed: (_) {
        if (isFavoritesTab && item.productId != null) {
          // Use unfavorite logic for Favorites tab
          _toggleFavoriteForItem(item);
        } else {
          // Use delete logic for All tab
          _historyService.deleteRecord(item.id);
        }
      },
      child: GestureDetector(
        onTap: () async {
          if (product != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
            // The heart button on the detail screen may have changed this
            // product's favorite state -- refresh so this list reflects it.
            _loadFavoriteProducts();
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
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
                  color: colorScheme.surfaceContainerHighest,
                  child: product != null
                      ? Image.asset(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.inventory_2_outlined,
                              color: colorScheme.primary,
                              size: 30),
                        )
                      : Icon(Icons.inventory_2_outlined,
                          color: colorScheme.primary, size: 30),
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
                          color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(item.timestamp),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Favorite heart toggle
              GestureDetector(
                onTap: () => _toggleFavoriteForItem(item),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withOpacity(0.4),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onPrimary, size: 26),
      ),
      onDismissed: (_) => _historyService.deleteRecord(item.id),
      child: GestureDetector(
        onTap: () async {
          // Reopen the comparison by navigating to CompareProductsScreen
          // Set saveToHistory: false to avoid creating duplicate history entries
          if (item.sourceProductId != null) {
            final sourceProduct = _dbService.getProductById(item.sourceProductId!);
            if (sourceProduct != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CompareProductsScreen(
                    sourceProduct: sourceProduct,
                    saveToHistory: false,
                  ),
                ),
              );
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
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
                  color: colorScheme.primary.withOpacity(0.12),
                  child: Center(
                    child: Icon(Icons.compare_arrows_rounded,
                      color: colorScheme.primary, size: 28),
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
                        color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(item.timestamp),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // Compare badge icon on right
            Icon(Icons.bar_chart_rounded,
                color: colorScheme.primary, size: 22),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildGroupSection(String label, List<HistoryItem> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          label,
          style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => item.type == HistoryType.comparison
            ? _buildCompareCard(item)
            : _buildScanCard(item)),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, bool active,
      {VoidCallback? onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 26),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _navItemScan() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CameraScannerScreen())),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, color: colorScheme.onSurfaceVariant, size: 26),
          const SizedBox(height: 2),
          Text('Scan',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.of(context).padding.top;
    final items = _activeTab == 'Paborito'
        // Favorites are loaded directly from BackendLocator.favoritesService
        // as full Product objects, independent of scan history. Convert them to
        // HistoryItem-like objects for display in the existing card UI.
        ? _favoriteProducts
            .where((product) =>
                _searchQuery.isEmpty ||
                product.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .map((product) => HistoryItem(
                  id: 'fav_${product.id}',
                  title: product.name,
                  subtitle: product.nutritionalFacts.servingSize,
                  timestamp: DateTime.now(), // Could use favorited timestamp if tracked
                  type: HistoryType.scan,
                  productId: product.id,
                ))
            .toList()
        : _historyService.getItems(filter: _activeTab, searchQuery: _searchQuery);
    final grouped = _groupItems(items);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: widget.embeddedMode ? null : const VoiceAssistantFab(),
      bottomNavigationBar: widget.embeddedMode ? null : Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 4, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, loc.home, false),
            _navItemScan(),
            // History tab is active
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        color: colorScheme.primary, size: 26),
                    const SizedBox(height: 2),
                    Text(loc.history,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            _navItem(Icons.person_outline, loc.profile, false),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Container(
            color: colorScheme.surface,
            padding: EdgeInsets.only(
                top: topPadding + 8, left: 20, right: 20, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: title + clear button (+ dev-only seed button)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.history,
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
                      ),
                    ),
                    if (kDebugMode) ...[
                      GestureDetector(
                        onTap: _seedTestHistory,
                        child: const Text(
                          'Seed (dev)',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    GestureDetector(
                      onTap: _showClearAllDialog,
                      child: Text(
                        loc.clearAll,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colorScheme.primary,
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
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search,
                          color: colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(
                              fontSize: 14, color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: loc.searchHint,
                            hintStyle: GoogleFonts.inter(
                                fontSize: 14, color: colorScheme.onSurfaceVariant),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: Icon(Icons.close,
                              color: colorScheme.onSurfaceVariant, size: 18),
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
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: _tabs.map((tab) {
                      final isActive = _activeTab == tab;
                      String tabLabel = tab;
                      if (tab == 'Lahat') tabLabel = loc.tabAll;
                      if (tab == 'Paborito') tabLabel = loc.tabFavorites;
                      if (tab == 'Kumpara') tabLabel = loc.tabCompare;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _activeTab = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.cardColor
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
                                tabLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
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
            child: ((_activeTab == 'Paborito' && _favoritesLoading) ||
                    _historyService.isLoading)
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    String message;
    if (_activeTab == 'Paborito') {
      message = loc.emptyFavorites;
    } else if (_activeTab == 'Kumpara') {
      message = loc.emptyComparisons;
    } else if (_searchQuery.isNotEmpty) {
      message = loc.noSearchResults(_searchQuery);
    } else {
      message = loc.emptyHistory;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                color: colorScheme.primary.withOpacity(0.2), size: 72),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}