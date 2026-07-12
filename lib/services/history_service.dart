// lib/services/history_service.dart
//
// UI-facing facade over HistoryRepository (data/repositories/history_repository.dart).
// Keeps the same synchronous getItems()/singleton/onUpdate-stream contract
// the History screen already depends on, so the screen itself needed almost
// no changes -- but the data underneath is now Firestore
// (`users/{userId}/history`) instead of an in-memory mock list, so history
// persists across restarts and syncs across a user's devices.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/history_repository.dart';
import '../data/services/backend_locator.dart';
import '../models/history_item.dart';
import '../models/product_model.dart';
import 'product_db_service.dart';

// HistoryItem/HistoryType now live in models/history_item.dart, but every
// existing `import '../services/history_service.dart'` (history_screen.dart,
// camera_scanner_screen.dart, etc.) still expects to get them from here.
export '../models/history_item.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;

  final StreamController<void> _updateController = StreamController<void>.broadcast();

  /// Fires whenever the cached history list changes -- either because a
  /// Firestore snapshot came in, or because of an optimistic local update.
  /// The History screen listens to this and calls setState().
  Stream<void> get onUpdate => _updateController.stream;

  final HistoryRepository _repository;

  List<HistoryItem> _items = [];
  bool _loading = true;
  String? _currentUserId;

  StreamSubscription<List<HistoryItem>>? _historySubscription;
  StreamSubscription<User?>? _authSubscription;

  /// True while the initial Firestore snapshot for the current user hasn't
  /// arrived yet. The History screen can use this to show a spinner instead
  /// of a premature "no history yet" empty state.
  bool get isLoading => _loading;

  HistoryService._internal({HistoryRepository? repository})
      : _repository = repository ?? BackendLocator.historyRepository {
    // Re-subscribe to the right user's `users/{uid}/history` collection
    // whenever auth state changes (sign in, sign out, account switch),
    // rather than only reading the uid once at construction time.
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    _onAuthChanged(FirebaseAuth.instance.currentUser);
  }

  void _onAuthChanged(User? user) {
    _historySubscription?.cancel();
    _currentUserId = user?.uid;

    if (_currentUserId == null) {
      _items = [];
      _loading = false;
      _updateController.add(null);
      return;
    }

    _loading = true;
    _updateController.add(null);

    _historySubscription = _repository.watchHistory(_currentUserId!).listen(
      (items) {
        _items = items;
        _loading = false;
        _updateController.add(null);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('HistoryService: failed to load history: $e');
        _loading = false;
        _updateController.add(null);
      },
    );
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

  /// Fire-and-forget by design (callers like camera_scanner_screen.dart
  /// don't await this) -- errors are caught and logged rather than thrown,
  /// so a transient Firestore failure can't crash the scan flow.
  Future<void> addScanRecord(Product product) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('HistoryService.addScanRecord: no signed-in user, skipping.');
      return;
    }

    final now = DateTime.now();
    // Check if we already scanned this product recently (e.g. within last
    // minute) to avoid duplicates. Uses the local cache rather than a
    // Firestore query so this stays instant even offline.
    final exists = _items.any((item) =>
        item.productId == product.id &&
        item.type == HistoryType.scan &&
        now.difference(item.timestamp).inMinutes < 2);
    if (exists) return;

    final item = HistoryItem(
      id: 'scan_${now.millisecondsSinceEpoch}',
      title: product.name,
      subtitle: product.nutritionalFacts.servingSize,
      timestamp: now,
      type: HistoryType.scan,
      productId: product.id,
    );

    // Optimistic insert -- Firestore's local cache will normally echo this
    // back via the snapshot listener almost immediately anyway, but this
    // guarantees the UI updates even if that round-trip is slow.
    _items = [item, ..._items];
    _updateController.add(null);

    try {
      await _repository.addItem(userId: userId, item: item);
    } catch (e) {
      debugPrint('HistoryService.addScanRecord failed: $e');
      _items = _items.where((i) => i.id != item.id).toList();
      _updateController.add(null);
    }
  }

  Future<void> addComparisonRecord(String category, String title) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('HistoryService.addComparisonRecord: no signed-in user, skipping.');
      return;
    }

    final now = DateTime.now();
    final item = HistoryItem(
      id: 'comp_${now.millisecondsSinceEpoch}',
      title: title,
      subtitle: 'Category: $category',
      timestamp: now,
      type: HistoryType.comparison,
    );

    _items = [item, ..._items];
    _updateController.add(null);

    try {
      await _repository.addItem(userId: userId, item: item);
    } catch (e) {
      debugPrint('HistoryService.addComparisonRecord failed: $e');
      _items = _items.where((i) => i.id != item.id).toList();
      _updateController.add(null);
    }
  }

  /// Flips the legacy per-record favorite flag. Kept for backward
  /// compatibility -- the History screen's Favorites tab actually reads
  /// BackendLocator.favoritesRepository (product-level) instead, see
  /// history_screen.dart.
  Future<void> toggleFavorite(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final newValue = !_items[index].isFavorite;
    _items[index].isFavorite = newValue;
    _updateController.add(null);

    try {
      await _repository.setFavoriteFlag(
        userId: userId,
        itemId: id,
        isFavorite: newValue,
      );
    } catch (e) {
      debugPrint('HistoryService.toggleFavorite failed: $e');
      final revertIndex = _items.indexWhere((item) => item.id == id);
      if (revertIndex != -1) {
        _items[revertIndex].isFavorite = !newValue;
        _updateController.add(null);
      }
    }
  }

  Future<void> deleteRecord(String id) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final removedIndex = _items.indexWhere((item) => item.id == id);
    if (removedIndex == -1) return;
    final removed = _items[removedIndex];

    _items = _items.where((item) => item.id != id).toList();
    _updateController.add(null);

    try {
      await _repository.deleteItem(userId: userId, itemId: id);
    } catch (e) {
      debugPrint('HistoryService.deleteRecord failed: $e');
      // Restore on failure (e.g. Dismissible swipe while offline and the
      // delete never lands) so the record isn't silently lost from the UI.
      _items = [..._items, removed];
      _updateController.add(null);
    }
  }

  Future<void> clearAllHistory() async {
    final userId = _currentUserId;
    if (userId == null) return;

    final backup = List<HistoryItem>.from(_items);
    _items = [];
    _updateController.add(null);

    try {
      await _repository.clearAll(userId);
    } catch (e) {
      debugPrint('HistoryService.clearAllHistory failed: $e');
      _items = backup;
      _updateController.add(null);
    }
  }

  // ── Analytics & Usage Tracking ──
  // Unchanged: still synchronous, and still reads the local product catalog
  // via ProductDbService -- only the history data feeding it now comes from
  // Firestore instead of a hardcoded list.

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

  /// Call from app teardown/tests only -- the real instance lives for the
  /// app's lifetime via the singleton factory.
  void dispose() {
    _authSubscription?.cancel();
    _historySubscription?.cancel();
    _updateController.close();
  }
}
