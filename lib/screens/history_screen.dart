import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/history_service.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../data/services/backend_locator.dart';
import 'product_detail_screen.dart';
import 'compare_products_screen.dart';
import 'report_detail_screen.dart';
import '../generated/l10n/app_localizations.dart';
import '../widgets/voice_assistant_fab.dart';
import '../models/product_model.dart';
import '../models/report_model.dart';
import '../services/home_tab_controller.dart';
import '../services/haptic_service.dart';
import '../services/voice_assistant_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class HistoryScreen extends StatefulWidget {
  final bool embeddedMode;
  const HistoryScreen({super.key, this.embeddedMode = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  final TextEditingController _searchController = TextEditingController();

  // Caches in-flight/completed product lookups by product ID so the list
  // doesn't re-hit Firestore on every rebuild (search typing, tab switches,
  // favorites stream updates, etc.) -- each ID is only ever fetched once.
  final Map<String, Future<Product?>> _productLookupCache = {};

  Future<Product?> _lookupProduct(String productId) {
    return _productLookupCache.putIfAbsent(productId, () async {
      try {
        return await BackendLocator.productRepository.getProductById(productId);
      } catch (e) {
        debugPrint('HistoryScreen: product not found for $productId: $e');
        return null;
      }
    });
  }
  final _authService = AuthService();
  StreamSubscription<void>? _subscription;
  StreamSubscription<List<Product>>? _favoritesSubscription;

  String _activeTab = 'Lahat'; // 'Lahat', 'Paborito', 'Kumpara'
  String _searchQuery = '';

  // Favorites are loaded directly from BackendLocator.favoritesService
  // as full Product objects, independent of scan history. This shows all
  // favorited products regardless of how they were discovered (scan, compare, etc.).
  List<Product> _favoriteProducts = [];
  bool _favoritesLoading = true;

  static const _tabs = ['Lahat', 'Paborito', 'Kumpara', 'Mga Ulat'];

  StreamSubscription<QuerySnapshot>? _reportsSubscription;
  List<ReportModel> _reports = [];
  bool _reportsLoading = true;

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    HomeTabController.tabNotifier.addListener(_handleTabChange);
    HomeTabController.historySubTabNotifier.addListener(_handleSubTabChange);
    _announceIfVisible();
    _subscription = _historyService.onUpdate.listen((_) {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _searchQuery = _searchController.text);
        }
      });
    });
    _subscribeFavorites();
    _subscribeReports();
    // Listen for language changes to refresh the UI with localized labels
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  void _handleSubTabChange() {
    if (mounted) {
      setState(() {
        _activeTab = HomeTabController.historySubTabNotifier.value;
      });
    }
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {}); // Force rebuild to update localized labels
    }
  }

  void _handleTabChange() {
    _announceIfVisible();
  }

  void _announceIfVisible() {
    if (HomeTabController.tabNotifier.value == 2 &&
        _authService.currentUser != null &&
        VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('history');
    }
  }

  @override
  void dispose() {
    HomeTabController.tabNotifier.removeListener(_handleTabChange);
    HomeTabController.historySubTabNotifier.removeListener(_handleSubTabChange);
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    _subscription?.cancel();
    _favoritesSubscription?.cancel();
    _reportsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeReports() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _reportsLoading = false);
      return;
    }

    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('reportedBy', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _reports = snapshot.docs
              .map((doc) => ReportModel.fromFirestore(doc))
              .toList();
          // Sort descending by date
          _reports.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
          _reportsLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error watching reports: $e');
      if (mounted) setState(() => _reportsLoading = false);
    });
  }

  // Live Firestore stream -- this is the single source of truth for the
  // Favorites tab now. It's what makes favoriting correct from EVERY
  // navigation path (All tab, Compare tab -> saved comparison -> ranked
  // list, multi-scan results, etc.) without each screen needing to call
  // back into History to trigger a refresh. The previous pattern relied on
  // each screen remembering to do that after its own specific
  // Navigator.push returned -- _buildScanCard did it, _buildCompareCard
  // didn't, and multi_scan_results_screen.dart's path to ProductDetailScreen
  // had no connection to History at all. That asymmetry was the actual bug.
  void _subscribeFavorites() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _favoritesLoading = false);
      return;
    }
    _favoritesSubscription =
        BackendLocator.favoritesService.watchFavoriteProducts(uid).listen(
      (products) {
        if (mounted) {
          setState(() {
            _favoriteProducts = products;
            _favoritesLoading = false;
          });
        }
      },
      onError: (e) {
        debugPrint('Error watching favorites: $e');
        if (mounted) setState(() => _favoritesLoading = false);
      },
    );
  }

  Future<void> _toggleFavoriteForItem(HistoryItem item) async {
    final uid = _authService.currentUser?.uid;
    final productId = item.productId;
    if (uid == null || productId == null) return;

    try {
      await BackendLocator.favoritesService.toggleFavorite(
        userId: uid,
        productId: productId,
      );
      // No manual refresh needed -- _favoritesSubscription above picks this
      // up automatically, the same way it picks up every other navigation
      // path's favorite toggles.
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  // ── Group items by date label ──────────────
  Map<String, List<HistoryItem>> _groupItems(List<HistoryItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final loc = AppLocalizations.of(context)!;

    final Map<String, List<HistoryItem>> grouped = {
      loc.historyToday: [],
      loc.historyYesterday: [],
      loc.historyLastWeek: [],
      loc.historyLastMonth: [],
    };

    for (final item in items) {
      final d = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      
      // "no last year" -> ignore items from previous years
      if (d.year < now.year) continue;

      if (d == today) {
        grouped[loc.historyToday]!.add(item);
      } else if (d == yesterday) {
        grouped[loc.historyYesterday]!.add(item);
      } else if (d.isAfter(lastWeek) || d == lastWeek) {
        grouped[loc.historyLastWeek]!.add(item);
      } else {
        grouped[loc.historyLastMonth]!.add(item);
      }
    }

    // Remove empty groups
    grouped.removeWhere((_, list) => list.isEmpty);
    return grouped;
  }

  // ── Group reports by date label ──────────────
  Map<String, List<ReportModel>> _groupReports(List<ReportModel> reports) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final loc = AppLocalizations.of(context)!;

    final Map<String, List<ReportModel>> grouped = {
      loc.historyToday: [],
      loc.historyYesterday: [],
      loc.historyLastWeek: [],
      loc.historyLastMonth: [],
    };

    for (final report in reports) {
      final d = DateTime(report.dateSubmitted.year, report.dateSubmitted.month, report.dateSubmitted.day);
      
      // "no last year" -> ignore items from previous years
      if (d.year < now.year) continue;

      if (d == today) {
        grouped[loc.historyToday]!.add(report);
      } else if (d == yesterday) {
        grouped[loc.historyYesterday]!.add(report);
      } else if (d.isAfter(lastWeek) || d == lastWeek) {
        grouped[loc.historyLastWeek]!.add(report);
      } else {
        grouped[loc.historyLastMonth]!.add(report);
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
      // Product lookup is now an async Firestore read instead of an
      // instant in-memory one, so the tile itself carries its own loading
      // state via FutureBuilder rather than the whole screen blocking.
      child: FutureBuilder<Product?>(
        future: item.productId != null ? _lookupProduct(item.productId!) : null,
        builder: (context, snapshot) {
          final product = snapshot.data;
          final isLoadingProduct = item.productId != null &&
              snapshot.connectionState != ConnectionState.done;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              if (product != null) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
                // Favorites no longer need a manual refresh here --
                // _favoritesSubscription (Firestore stream) keeps this screen's
                // Favorites tab in sync in real time regardless of what
                // happened on the screen(s) we navigated to.
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
                  // Product image, loading spinner, or placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: colorScheme.surfaceContainerHighest,
                      child: isLoadingProduct
                          ? Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : (product != null && product.imageUrl.isNotEmpty
                              ? Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                  cacheHeight: 150,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.inventory_2_outlined,
                                      color: colorScheme.primary,
                                      size: 30),
                                )
                              : Icon(Icons.inventory_2_outlined,
                                  color: colorScheme.primary, size: 30)),
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
          );
        },
      ),
    );
  }

  Future<Product?> _findProductForComparison(HistoryItem item) async {
    final targetId = item.sourceProductId ?? item.productId;
    if (targetId != null && targetId.isNotEmpty) {
      final p = await _lookupProduct(targetId);
      if (p != null) return p;
    }

    try {
      final allProducts = await BackendLocator.productRepository.getAllProducts();
      if (allProducts.isEmpty) return null;

      final cleanTitle = item.title
          .replaceAll(RegExp(r'\s+Comparison\s+Result', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+Resulta\s+ng\s+Paghahambing', caseSensitive: false), '')
          .trim()
          .toLowerCase();

      if (cleanTitle.isNotEmpty) {
        for (final p in allProducts) {
          final pName = p.name.toLowerCase();
          if (pName == cleanTitle || pName.contains(cleanTitle) || cleanTitle.contains(pName)) {
            return p;
          }
        }
      }

      final parts = item.subtitle.split(':');
      if (parts.length > 1) {
        final cat = parts.sublist(1).join(':').trim().toLowerCase();
        for (final p in allProducts) {
          if (p.category.toLowerCase() == cat) {
            return p;
          }
        }
      }
    } catch (e) {
      debugPrint('HistoryScreen: error looking up comparison product: $e');
    }
    return null;
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
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticService().vibrate();
          final sourceProduct = await _findProductForComparison(item);
          if (sourceProduct != null && mounted) {
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

  Widget _buildReportCard(ReportModel report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Status Badge colors
    Color statusBg;
    Color statusText;
    final status = report.status.toLowerCase();

    if (status == 'approved') {
      statusBg = Colors.green.withOpacity(0.15);
      statusText = Colors.green[700]!;
    } else if (status == 'rejected') {
      statusBg = Colors.red.withOpacity(0.15);
      statusText = Colors.red[700]!;
    } else { // pending
      statusBg = Colors.orange.withOpacity(0.15);
      statusText = Colors.orange[800]!;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(report: report),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    report.productName.isEmpty ? 'Unknown Product' : report.productName,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusText,
                    ),
                  ),
                ),
              ],
            ),
            if (report.category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                report.category,
                style: GoogleFonts.inter(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                _formatTime(report.dateSubmitted),
                style: GoogleFonts.inter(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    ),
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
            final isSelected = index == 2;
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

    final groupedReportsMap = _groupReports(_reports);
    final flattenedReports = <dynamic>[];
    for (final entry in groupedReportsMap.entries) {
      flattenedReports.add(entry.key);
      flattenedReports.addAll(entry.value);
    }

    final flattenedHistory = <dynamic>[];
    for (final entry in grouped.entries) {
      flattenedHistory.add(entry.key);
      flattenedHistory.addAll(entry.value);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: widget.embeddedMode ? null : const VoiceAssistantFab(),
      bottomNavigationBar: widget.embeddedMode ? null : _buildBottomNav(),
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
                      if (tab == 'Mga Ulat') tabLabel = loc.tabReports;

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

          // ── Scrollable content (virtualized on-demand rendering) ───────────
          Expanded(
            child: _activeTab == 'Mga Ulat'
                ? (_reportsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : flattenedReports.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            key: const PageStorageKey<String>('reports_scroll'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: flattenedReports.length,
                            itemBuilder: (context, index) {
                              final item = flattenedReports[index];
                              if (item is String) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 18, bottom: 10),
                                  child: Text(
                                    item,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                );
                              } else if (item is ReportModel) {
                                return _buildReportCard(item);
                              }
                              return const SizedBox.shrink();
                            },
                          ))
                : ((_activeTab == 'Paborito' && _favoritesLoading) ||
                        _historyService.isLoading)
                    ? const Center(child: CircularProgressIndicator())
                    : flattenedHistory.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            key: const PageStorageKey<String>('history_scroll'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: flattenedHistory.length,
                            itemBuilder: (context, index) {
                              final item = flattenedHistory[index];
                              if (item is String) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 18, bottom: 10),
                                  child: Text(
                                    item,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                );
                              } else if (item is HistoryItem) {
                                return item.type == HistoryType.comparison
                                    ? _buildCompareCard(item)
                                    : _buildScanCard(item);
                              }
                              return const SizedBox.shrink();
                            },
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