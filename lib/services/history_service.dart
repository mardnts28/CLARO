import 'dart:async';
import '../models/product_model.dart';
import 'product_db_service.dart';

enum HistoryType { scan, comparison }

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final HistoryType type;
  final String? productId;
  bool isFavorite;

  HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    this.productId,
    this.isFavorite = false,
  });
}

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;

  final StreamController<void> _updateController = StreamController<void>.broadcast();
  Stream<void> get onUpdate => _updateController.stream;

  final List<HistoryItem> _items = [];

  HistoryService._internal() {
    _loadMockHistory();
  }

  void _loadMockHistory() {
    final now = DateTime.now();
    // Match the today (Ngayon) and yesterday (Kahapon) entries from the screenshots
    _items.addAll([
      HistoryItem(
        id: 'mock_scan_1',
        title: 'Century Tuna Flakes in Vegetable Oil',
        subtitle: '180 g',
        timestamp: DateTime(now.year, now.month, now.day, 10, 30),
        type: HistoryType.scan,
        productId: 'century_tuna_flakes_oil',
        isFavorite: true, // Show red heart in Paborito
      ),
      HistoryItem(
        id: 'mock_comp_1',
        title: 'Century Tuna Variant Comparison',
        subtitle: '180 g',
        timestamp: DateTime(now.year, now.month, now.day, 10, 30),
        type: HistoryType.comparison,
      ),
      HistoryItem(
        id: 'mock_scan_2',
        title: 'Lucky Me! Pancit Canton Original',
        subtitle: '80g',
        timestamp: DateTime(now.year, now.month, now.day - 1, 15, 45),
        type: HistoryType.scan,
        productId: 'lucky_me_canton_original',
        isFavorite: false,
      ),
      HistoryItem(
        id: 'mock_comp_2',
        title: 'Instant Noodles Comparison',
        subtitle: '80g',
        timestamp: DateTime(now.year, now.month, now.day - 1, 16, 00),
        type: HistoryType.comparison,
      ),
    ]);
  }

  List<HistoryItem> getItems({
    required String filter, // 'Lahat', 'Paborito', 'Kumpara'
    String searchQuery = '',
  }) {
    Iterable<HistoryItem> filtered = _items;

    // 1. Filter by Tab
    if (filter == 'Paborito') {
      filtered = filtered.where((item) => item.isFavorite);
    } else if (filter == 'Kumpara') {
      filtered = filtered.where((item) => item.type == HistoryType.comparison);
    }

    // 2. Filter by Search Query
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((item) =>
          item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q));
    }

    // Sort chronologically (latest first)
    final sorted = filtered.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  void addScanRecord(Product product) {
    final now = DateTime.now();
    // Check if we already scanned this product recently (e.g. within last minute) to avoid duplicates
    final exists = _items.any((item) =>
        item.productId == product.id &&
        item.type == HistoryType.scan &&
        now.difference(item.timestamp).inMinutes < 2);

    if (!exists) {
      _items.add(HistoryItem(
        id: 'scan_${now.millisecondsSinceEpoch}',
        title: product.name,
        subtitle: product.nutritionalFacts.servingSize,
        timestamp: now,
        type: HistoryType.scan,
        productId: product.id,
      ));
      _updateController.add(null);
    }
  }

  void addComparisonRecord(String category, String title) {
    final now = DateTime.now();
    _items.add(HistoryItem(
      id: 'comp_${now.millisecondsSinceEpoch}',
      title: title,
      subtitle: 'Category: $category',
      timestamp: now,
      type: HistoryType.comparison,
    ));
    _updateController.add(null);
  }

  void toggleFavorite(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index].isFavorite = !_items[index].isFavorite;
      _updateController.add(null);
    }
  }

  void deleteRecord(String id) {
    _items.removeWhere((item) => item.id == id);
    _updateController.add(null);
  }

  void clearAllHistory() {
    _items.clear();
    _updateController.add(null);
  }

  // ── Analytics & Usage Tracking ──

  /// Calculates the most frequently scanned products, returning products mapped to count
  List<MapEntry<Product, int>> getMostScannedProducts({int limit = 5}) {
    final Map<String, int> counts = {};
    for (final item in _items) {
      if (item.type == HistoryType.scan && item.productId != null) {
        counts[item.productId!] = (counts[item.productId!] ?? 0) + 1;
      }
    }

    final db = ProductDbService();
    final List<MapEntry<Product, int>> list = [];
    counts.forEach((prodId, count) {
      final p = db.getProductById(prodId);
      if (p != null) {
        list.add(MapEntry(p, count));
      }
    });

    list.sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).toList();
  }

  /// Gets all products marked as favorites
  List<Product> getFavoriteProducts() {
    final db = ProductDbService();
    final List<Product> favs = [];
    for (final item in _items) {
      if (item.type == HistoryType.scan && item.isFavorite && item.productId != null) {
        final p = db.getProductById(item.productId!);
        if (p != null && !favs.any((f) => f.id == p.id)) {
          favs.add(p);
        }
      }
    }
    return favs;
  }
}
