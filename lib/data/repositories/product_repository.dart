// lib/data/repositories/product_repository.dart
//
// Interface-first design so your scoring/advisory/comparison logic never
// talks to the product data source directly -- it only ever talks to this
// interface.
//
// Backed by FirestoreProductRepository (below), which reads directly from
// the `fda_products` Firestore collection. The old ProductDbRepository
// (backed by the hardcoded services/product_db_service.dart mock catalog)
// was retired in Phase 3 once FirestoreProductRepository was confirmed
// stable end-to-end.
//
// Uses models/product_model.dart's Product -- the single source of truth
// for product data -- throughout. No separate backend Product model.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/product_model.dart';
import '../../services/nutrition_service.dart';

abstract class ProductRepository {
  Future<Product> getProductById(String id);
  Future<List<Product>> getAllProducts();
  // Matches on Product.category (e.g. "Canned Fish", "Instant Noodles") --
  // the grouping field the UI's compare screen uses. [excludeId] is fully
  // excluded from the result (not just moved to the end), since callers
  // use this to fetch ALTERNATIVES to a product they already have.
  Future<List<Product>> getSimilarProducts(String category, {String? excludeId});
}

// ─── Firestore-backed implementation ───────────────────────────────────────
//
// Reads directly from the `fda_products` collection. Wired up as
// BackendLocator.productRepository as of Phase 3.
//
// imageUrl is read directly from the fda_products document's `imageURL`
// field (a Cloudinary URL) -- Firestore stays the single source of truth for
// product data, Cloudinary is only ever an image host.
//
// allergens / ingredients / nutritionalFacts aren't stored in fda_products
// at all -- they're filled in by NutritionService, which looks them up on
// Open Food Facts and caches the result in Firestore (`nutrition_cache`),
// keyed by this repository's document id, so OFF only gets called once ever
// per product. Every getProductById / getAllProducts call below goes
// through that enrichment step, so every screen sees the same data.
// servingInstructions has no source yet (Phase 5 fallback collection) and
// stays at its default.
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'fda_products';

  @override
  Future<Product> getProductById(String id) async {
    // id is the Firestore document ID (e.g. "TwKsaC2cIm2SiaW8astc"), not the
    // human-readable slug ProductDbService used to use (e.g.
    // "century_tuna_flakes_oil"). Every caller that stores/passes around a
    // product id needs to be storing this document ID going forward -- see
    // Phase 2.
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists) {
      throw Exception('Product not found: $id');
    }
    final base = _productFromDoc(doc.id, doc.data()!);
    return NutritionService().enrichProduct(base);
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final snapshot = await _db.collection(_collection).get();
    final base = snapshot.docs
        .map((doc) => _productFromDoc(doc.id, doc.data()))
        .toList();
    // Enriched in parallel -- each lookup is either a single cheap Firestore
    // doc read (cache hit) or a one-time Open Food Facts call (cache miss),
    // so this stays fast even for a full-catalog fetch.
    return Future.wait(base.map((p) => NutritionService().enrichProduct(p)));
  }

  @override
  Future<List<Product>> getSimilarProducts(
    String category, {
    String? excludeId,
  }) async {
    // Filtered client-side against the already-formatted category label
    // (see _formatCategory) rather than queried server-side against the raw
    // snake_case product_category field, so callers keep passing the same
    // "Canned Fish"-style string the rest of the app already uses. Fine at
    // this catalog size; worth revisiting with a server-side query if the
    // collection grows large enough for that to matter.
    final all = await getAllProducts();
    return all
        .where((p) => p.category == category && p.id != excludeId)
        .toList();
  }

  Product _productFromDoc(String docId, Map<String, dynamic> data) {
    final isRegistered = data['registration_status'] as bool? ?? false;
    final validUntil = (data['validity_date'] as Timestamp?)?.toDate();
    final cprNumber = data['cpr_number'] as String? ?? '';
    final rawSizes = data['available_sizes'] as List? ?? [];
    final availableSizes = rawSizes
        .map((e) => _parseGramValue(e))
        .whereType<double>()
        .toList();

    return Product(
      id: docId,
      name: data['product_name'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
      category: _formatCategory(data['product_category'] as String? ?? ''),
      fdaStatus: _mapFdaStatus(isRegistered, validUntil),
      // fda_products only has one registration-number field (cpr_number);
      // mapped onto both of Product's corresponding fields so either one
      // renders correctly regardless of which the UI currently reads.
      fdaRegistrationNumber: cprNumber,
      cprNumber: cprNumber,
      fdaValidityDate: validUntil != null ? _formatIsoDate(validUntil) : '',
      imageUrl: data['imageURL'] as String? ?? '',
      allergens: const [],
      ingredients: const [],
      servingInstructions: '',
      availableSizes: availableSizes,
      nutritionalFacts: NutritionalFacts(),
    );
  }

  // Mirrors FdaVerificationService._buildResult's status mapping. Keep the
  // two in sync if the registration_status/validity_date semantics ever
  // change -- this duplication is intentional for now rather than forcing
  // an unrelated shared-utility refactor into this migration.
  String _mapFdaStatus(bool isRegistered, DateTime? validUntil) {
    if (!isRegistered) return 'UNVERIFIED';
    if (validUntil != null && DateTime.now().isAfter(validUntil)) {
      return 'EXPIRED';
    }
    return 'ACTIVE';
  }

  // "canned_fish" -> "Canned Fish"
  String _formatCategory(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatIsoDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  /// Parses a Firestore available_sizes entry into grams.
  /// Handles: numbers (100, 155.0), plain strings ("155"),
  /// gram-suffixed strings ("155g", "155 g"), and kg strings ("1.8kg", "1.8 kg").
  double? _parseGramValue(dynamic e) {
    if (e is num) return e.toDouble();
    if (e is String) {
      final s = e.trim().toLowerCase();
      // "1.8kg" or "1.8 kg"
      final kgMatch = RegExp(r'^([\d.]+)\s*kg$').firstMatch(s);
      if (kgMatch != null) {
        final kg = double.tryParse(kgMatch.group(1)!);
        if (kg != null) return kg * 1000;
      }
      // "155g" or "155 g" or plain "155"
      final gMatch = RegExp(r'^([\d.]+)\s*g?$').firstMatch(s);
      if (gMatch != null) return double.tryParse(gMatch.group(1)!);
    }
    return null;
  }
}