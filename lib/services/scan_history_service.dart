import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../data/services/backend_locator.dart';

class ScanHistoryService {
  static final ScanHistoryService _instance = ScanHistoryService._internal();
  factory ScanHistoryService() => _instance;
  ScanHistoryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collectionName = 'scan_history';

  // In-memory cache of scanned products for instant retrieval and fallback
  final List<Product> _localHistory = [];

  List<Product> get localHistory => List.unmodifiable(_localHistory);

  /// Saves a product to history (moves to top if it exists, adds if new).
  /// Also pushes the record to Firestore in the background.
  Future<void> addProductToHistory(Product product) async {
    // 1. Update local cache
    _localHistory.removeWhere((p) => p.id == product.id);
    _localHistory.insert(0, product);

    // 2. Persist to Firestore
    try {
      await _db.collection(_collectionName).add({
        'product_id': product.id,
        'product_name': product.name,
        'brand': product.brand,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fail silently for user but log it
      debugPrint('Firestore scan history write failed: $e');
    }
  }

  /// Retrieves the scan history from Firestore (up to 50 items).
  /// Falls back to local in-memory history if Firestore fails.
  Future<List<Product>> getScanHistory() async {
    try {
      final snapshot = await _db
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final List<Product> history = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final productId = data['product_id'] as String?;
        if (productId != null) {
          try {
            final product =
                await BackendLocator.productRepository.getProductById(productId);
            // Avoid duplicates in the returned list
            if (!history.any((p) => p.id == product.id)) {
              history.add(product);
            }
          } catch (e) {
            debugPrint('ScanHistoryService: product not found for $productId: $e');
          }
        }
      }

      // Sync local history with Firestore results if successful
      if (history.isNotEmpty) {
        _localHistory.clear();
        _localHistory.addAll(history);
      }

      return history;
    } catch (e) {
      debugPrint('Firestore scan history fetch failed: $e');
      return _localHistory; // Fallback to memory
    }
  }

  /// Clears the scan history both locally and from Firestore.
  Future<void> clearHistory() async {
    _localHistory.clear();
    try {
      final snapshot = await _db.collection(_collectionName).get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore scan history clear failed: $e');
    }
  }
}