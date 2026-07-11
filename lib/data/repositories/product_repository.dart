// lib/data/repositories/product_repository.dart
//
// Interface-first design so your scoring/advisory/comparison logic never
// talks to the product data source directly -- it only ever talks to this
// interface.
//
// Backed by ProductDbService (services/product_db_service.dart), which is
// the actual in-app product catalog the scanning/search screens already
// use. This repository does not own a second copy of the data -- it just
// adapts ProductDbService's synchronous, UI-facing API to the
// Future-based, backend-facing ProductRepository contract that the
// ranking/comparison/advisory logic depends on.
//
// Uses models/product_model.dart's Product -- the single source of truth
// for product data -- throughout. No separate backend Product model.

import '../../models/product_model.dart';
import '../../services/product_db_service.dart';

abstract class ProductRepository {
  Future<Product> getProductById(String id);
  Future<List<Product>> getAllProducts();
  // Matches on Product.category (e.g. "Canned Fish", "Instant Noodles") --
  // the grouping field ProductDbService and the UI's own compare screen
  // already use. [excludeId] is fully excluded from the result (not just
  // moved to the end), since callers use this to fetch ALTERNATIVES to a
  // product they already have.
  Future<List<Product>> getSimilarProducts(String category, {String? excludeId});
}

class ProductDbRepository implements ProductRepository {
  ProductDbRepository({ProductDbService? productDbService})
      : _db = productDbService ?? ProductDbService();

  final ProductDbService _db;

  @override
  Future<Product> getProductById(String id) async {
    final match = _db.getProductById(id);
    if (match == null) {
      throw Exception('Product not found: $id');
    }
    return match;
  }

  @override
  Future<List<Product>> getAllProducts() async {
    return _db.getAllProducts();
  }

  @override
  Future<List<Product>> getSimilarProducts(
    String category, {
    String? excludeId,
  }) async {
    return _db
        .getProductsByCategory(category, excludeId: excludeId)
        .where((p) => p.id != excludeId)
        .toList();
  }
}