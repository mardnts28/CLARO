// lib/data/repositories/product_repository.dart
//
// Interface-first design so your scoring/advisory/comparison logic never
// talks to mock data or Firestore directly -- it only ever talks to this
// interface. When the real dataset/Firestore/OpenFoodFactsService is ready,
// swap MockProductRepository() -> FirebaseProductRepository() in one place
// (likely wherever your Provider is constructed) and nothing else changes.

import '../models/product.dart';
import 'mock_data/mock_products.dart';

abstract class ProductRepository {
  Future<Product> getProductById(String id);
  Future<List<Product>> getAllProducts();
  // Renamed from getSameCategoryProducts(ProductCategory) -- matching on the
  // broad packaging category (cannedFood/instantNoodles) mixed unrelated
  // products (e.g. sardines with spaghetti sauce). This now matches on the
  // finer-grained subCategory field instead, so "Compare" alternatives are
  // actually comparable products.
  Future<List<Product>> getSimilarProducts(String subCategory, {String? excludeId});
}

class MockProductRepository implements ProductRepository {
  // Simulates network latency so your UI's loading states get exercised
  // during development instead of only being written and never tested.
  static const _simulatedDelay = Duration(milliseconds: 300);

  @override
  Future<Product> getProductById(String id) async {
    await Future.delayed(_simulatedDelay);
    final match = mockProductsJson.firstWhere(
      (p) => p['id'] == id,
      orElse: () => throw Exception('Product not found: $id'),
    );
    return Product.fromJson(match);
  }

  @override
  Future<List<Product>> getAllProducts() async {
    await Future.delayed(_simulatedDelay);
    return mockProductsJson.map((json) => Product.fromJson(json)).toList();
  }

  @override
  Future<List<Product>> getSimilarProducts(
    String subCategory, {
    String? excludeId,
  }) async {
    await Future.delayed(_simulatedDelay);
    return mockProductsJson
        .map((json) => Product.fromJson(json))
        .where((p) => p.subCategory == subCategory && p.id != excludeId)
        .toList();
  }
}

// TODO (Phase 6): implement once teammate's Firestore/Open Food Facts
// integration is ready.
// class FirebaseProductRepository implements ProductRepository { ... }