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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/product_model.dart';
import '../../services/nutrition_service.dart';

abstract class ProductRepository {
  Future<Product> getProductById(String id);
  Future<List<Product>> getAllProducts();
  /// Look up a product by its `yolo_label` field (the exact class name from labels.json).
  Future<Product> getProductByYoloLabel(String yoloLabel);
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
// at all -- they're filled in by NutritionService, which reads them from
// `product_nutrition_data`, keyed by this repository's document id. That
// collection is populated by the OCR + Gemini extraction pipeline (the
// initial dev-phase catalog population, and later, admin-approved user
// reports of unrecognized products) -- never by a live external API call.
// Every getProductById / getAllProducts call below goes through that
// enrichment step, so every screen sees the same data.
// servingInstructions has no source yet (Phase 5 fallback collection) and
// stays at its default.
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const String _collection = 'fda_products';
  static const String _persistentCachePrefix = 'claro_product_offline_';

  // Global in-memory product cache to avoid redundant Firestore reads
  static final Map<String, Product> _productCache = {};
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<Product?> _getFromPersistentCache(String key) async {
    try {
      final p = await _getPrefs();
      final raw = p.getString('$_persistentCachePrefix$key');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final product = Product.fromJson(map);
        _productCache[key] = product;
        _productCache[product.id] = product;
        return product;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _saveToPersistentCache(String key, Product product) async {
    try {
      final p = await _getPrefs();
      final jsonStr = jsonEncode(product.toJson());
      await p.setString('$_persistentCachePrefix$key', jsonStr);
      await p.setString('$_persistentCachePrefix${product.id}', jsonStr);
    } catch (_) {}
  }

  /// Pre-caches top FDA products and their nutrition data in local storage
  /// so that evaluations, comparisons, and scans work 100% offline in grocery basements.
  Future<void> preloadOfflineCatalog({int limit = 100}) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in snapshot.docs) {
        try {
          final base = _productFromDoc(doc.id, doc.data());
          final enriched = await NutritionService().enrichProduct(base);
          _productCache[doc.id] = enriched;
          _productCache[enriched.id] = enriched;
          final yolo = (doc.data()['yolo_label'] as String? ?? '').trim().toLowerCase();
          if (yolo.isNotEmpty) {
            _productCache[yolo] = enriched;
            await _saveToPersistentCache(yolo, enriched);
          }
          await _saveToPersistentCache(doc.id, enriched);
        } catch (_) {}
      }
      debugPrint('FirestoreProductRepository: Preloaded ${snapshot.docs.length} products to offline storage.');
    } catch (e) {
      debugPrint('Offline preload skipped: $e');
    }
  }

  @override
  Future<Product> getProductById(String id) async {
    final cached = _productCache[id];
    if (cached != null) return cached;

    final persistentCached = await _getFromPersistentCache(id);
    if (persistentCached != null) return persistentCached;

    try {
      final doc = await _db.collection(_collection).doc(id).get().timeout(const Duration(seconds: 5));
      if (doc.exists) {
        final base = _productFromDoc(doc.id, doc.data()!);
        final enriched = await NutritionService().enrichProduct(base);
        _productCache[id] = enriched;
        _productCache[enriched.id] = enriched;
        await _saveToPersistentCache(id, enriched);
        return enriched;
      }
    } catch (_) {}

    // Fallback: match by normalized product name or slug if doc.id differs from YOLO label
    try {
      final snapshot = await _db.collection(_collection).get().timeout(const Duration(seconds: 5));
      final normId = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      for (final d in snapshot.docs) {
        final pName = (d.data()['product_name'] as String? ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (d.id == id ||
            pName == normId ||
            pName.contains(normId) ||
            normId.contains(pName)) {
          final base = _productFromDoc(d.id, d.data());
          final enriched = await NutritionService().enrichProduct(base);
          _productCache[id] = enriched;
          _productCache[enriched.id] = enriched;
          await _saveToPersistentCache(id, enriched);
          return enriched;
        }
      }
    } catch (_) {}

    throw Exception('Product not found: $id');
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedCatalogDocs;

  @override
  Future<Product> getProductByYoloLabel(String yoloLabel) async {
    final cleanLabel = yoloLabel.trim().toLowerCase();
    final cached = _productCache[cleanLabel];
    if (cached != null) return cached;

    final persistentCached = await _getFromPersistentCache(cleanLabel);
    if (persistentCached != null) return persistentCached;

    // 1. Direct Firestore query on the yolo_label field (with 6s timeout)
    try {
      final query = await _db
          .collection(_collection)
          .where('yolo_label', isEqualTo: cleanLabel)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));
      if (query.docs.isNotEmpty) {
        final d = query.docs.first;
        final base = _productFromDoc(d.id, d.data());
        final enriched = await NutritionService().enrichProduct(base);
        _productCache[cleanLabel] = enriched;
        _productCache[enriched.id] = enriched;
        await _saveToPersistentCache(cleanLabel, enriched);
        return enriched;
      }
    } catch (_) {}

    // 2. Multi-pass token matching against cached or freshly fetched catalog
    try {
      if (_cachedCatalogDocs == null) {
        final snapshot = await _db
            .collection(_collection)
            .get()
            .timeout(const Duration(seconds: 6));
        _cachedCatalogDocs = snapshot.docs;
      }
      final docs = _cachedCatalogDocs!;
      final normYolo = cleanLabel.replaceAll(RegExp(r'[^a-z0-9]'), '');

      // Pass A: Exact match on doc ID or yolo_label field
      for (final d in docs) {
        final data = d.data();
        final docYolo = (data['yolo_label'] as String? ?? '').trim().toLowerCase();
        if (d.id == yoloLabel || docYolo == cleanLabel) {
          final base = _productFromDoc(d.id, data);
          return NutritionService().enrichProduct(base);
        }
      }

      // Pass B: Smart Token Overlap matching against product_name
      final yoloTokens = cleanLabel
          .split('_')
          .where((t) => t.length > 2 && !['and', 'with', 'the', 'pck', 'sauce'].contains(t))
          .toList();

      QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
      int maxMatches = 0;

      for (final d in docs) {
        final data = d.data();
        final pName = (data['product_name'] as String? ?? '').toLowerCase();
        final normPName = pName.replaceAll(RegExp(r'[^a-z0-9]'), '');

        // Direct normalized substring match
        if (normPName.contains(normYolo) || normYolo.contains(normPName)) {
          final base = _productFromDoc(d.id, data);
          return NutritionService().enrichProduct(base);
        }

        // Count token matches
        int matchCount = 0;
        for (final token in yoloTokens) {
          if (pName.contains(token)) {
            matchCount++;
          }
        }

        if (matchCount > maxMatches) {
          maxMatches = matchCount;
          bestDoc = d;
        }
      }

      if (bestDoc != null && maxMatches >= 2) {
        final base = _productFromDoc(bestDoc.id, bestDoc.data());
        final enriched = await NutritionService().enrichProduct(base);
        _productCache[cleanLabel] = enriched;
        _productCache[enriched.id] = enriched;
        return enriched;
      }
    } catch (e) {
      debugPrint('Firestore lookup error in getProductByYoloLabel: $e');
    }

    // 3. Fallback: format YOLO label into human-readable product representation
    final fallback = _fallbackProductFromYoloLabel(cleanLabel);
    final enriched = await NutritionService().enrichProduct(fallback);
    _productCache[cleanLabel] = enriched;
    _productCache[enriched.id] = enriched;
    return enriched;
  }

  Product _fallbackProductFromYoloLabel(String label) {
    final words = label.split('_').map((w) {
      if (w == 'lm') return 'Lucky Me';
      if (w == 'pc') return 'Pancit Canton';
      if (w == 'pck') return 'Pack';
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).where((w) => w.isNotEmpty).toList();

    final formattedName = words.join(' ');

    return Product(
      id: label,
      name: formattedName,
      brand: words.isNotEmpty ? words.first : 'Recognized Product',
      category: 'Packaged Food',
      fdaStatus: _mapFdaStatus(true, null),
      fdaRegistrationNumber: 'FDA-RECOGNIZED',
      cprNumber: 'FDA-RECOGNIZED',
      fdaValidityDate: '',
      imageUrl: '',
      allergens: const [],
      ingredients: const [],
      servingInstructions: '',
      availableSizes: const [100],
      sizeOptions: const [],
      nutritionalFacts: NutritionalFacts(),
    );
  }

  @override
  Future<List<Product>> getAllProducts() async {
    final snapshot = await _db.collection(_collection).get();
    final base = snapshot.docs
        .map((doc) => _productFromDoc(doc.id, doc.data()))
        .toList();
    // Enriched in parallel -- each lookup is a single cheap Firestore doc
    // read against `product_nutrition_data`, so this stays fast even for a
    // full-catalog fetch.
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
    final cprNumber = data['cpr_number']?.toString() ?? '';
    final rawSizes = data['available_sizes'] as List? ?? [];
    final sizeOptions = rawSizes
        .map(_parseSizeOption)
        .whereType<ProductSizeOption>()
        .toList();
    final availableSizes = sizeOptions.map((s) => s.sizeGrams).toList();

    return Product(
      id: docId,
      name: data['product_name']?.toString() ?? '',
      brand: data['brand']?.toString() ?? '',
      category: _formatCategory(data['product_category']?.toString() ?? ''),
      fdaStatus: _mapFdaStatus(isRegistered, validUntil),
      // fda_products only has one registration-number field (cpr_number);
      // mapped onto both of Product's corresponding fields so either one
      // renders correctly regardless of which the UI currently reads.
      fdaRegistrationNumber: cprNumber,
      cprNumber: cprNumber,
      fdaValidityDate: validUntil != null ? _formatIsoDate(validUntil) : '',
      imageUrl: (data['imageURL'] ?? data['imageUrl'])?.toString() ?? '',
      allergens: const [],
      ingredients: const [],
      servingInstructions: '',
      availableSizes: availableSizes,
      sizeOptions: sizeOptions,
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

  /// Parses one `available_sizes` array entry into a [ProductSizeOption].
  ///
  /// Supports two shapes, so existing documents keep working unchanged
  /// while new/updated ones can attach a per-size Cloudinary photo:
  /// - Legacy: a bare number/string, e.g. `155` or `"400g"` -- size only,
  ///   [ProductSizeOption.imageUrl] is left null (falls back to the
  ///   product's default `imageURL` in the UI).
  /// - With image: a map, e.g.
  ///   `{ "size_grams": 155, "image_url": "https://res.cloudinary.com/.../155g.png" }`.
  ///   Accepts `size_grams`/`size`/`grams` for the size key and
  ///   `image_url`/`imageURL`/`imageUrl` for the image key, so it's
  ///   forgiving of whichever naming convention gets used when uploading.
  ProductSizeOption? _parseSizeOption(dynamic e) {
    if (e is Map) {
      final sizeRaw = e['size_grams'] ?? e['size'] ?? e['grams'];
      final grams = _parseGramValue(sizeRaw);
      if (grams == null) return null;
      final imageUrl = (e['image_url'] ?? e['imageURL'] ?? e['imageUrl']) as String?;
      return ProductSizeOption(
        sizeGrams: grams,
        imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      );
    }
    final grams = _parseGramValue(e);
    if (grams == null) return null;
    return ProductSizeOption(sizeGrams: grams);
  }
}