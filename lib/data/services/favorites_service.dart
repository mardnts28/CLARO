// lib/data/services/favorites_service.dart
//
// Orchestrates FavoritesRepository (which productIds a user has favorited)
// with ProductRepository (turning those IDs into full Product objects for
// a favorites list screen). The heart-button UI should call toggleFavorite()
// and use its return value to update the icon immediately, rather than
// re-fetching favorite status separately.

import '../../models/product_model.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/product_repository.dart';

class FavoritesService {
  FavoritesService({
    required FavoritesRepository favoritesRepository,
    required ProductRepository productRepository,
  })  : _favoritesRepository = favoritesRepository,
        _productRepository = productRepository;

  final FavoritesRepository _favoritesRepository;
  final ProductRepository _productRepository;

  Future<bool> isFavorite({required String userId, required String productId}) {
    return _favoritesRepository.isFavorite(userId: userId, productId: productId);
  }

  /// Toggles the heart-button state for a product. Returns the NEW state
  /// (true = now favorited, false = now un-favorited) so the UI can update
  /// the icon immediately without a second round-trip.
  Future<bool> toggleFavorite({required String userId, required String productId}) {
    // Delegate to the repository's own toggle rather than doing a separate
    // isFavorite() read here first -- that read-then-write pattern has a
    // race window on rapid double-taps; the repository's toggle reads and
    // writes as one step.
    return _favoritesRepository.toggleFavorite(userId: userId, productId: productId);
  }

  /// Full Product objects for the user's "Saved Products" list screen.
  Future<List<Product>> getFavoriteProducts(String userId) async {
    final ids = await _favoritesRepository.getFavoriteProductIds(userId);
    return _resolveProducts(ids);
  }

  /// Live version of getFavoriteProducts, backed by Firestore's real-time
  /// snapshots. This is the single source of truth the History screen's
  /// Favorites tab should subscribe to -- it updates automatically no
  /// matter which screen or navigation path the favorite was toggled from
  /// (All tab, a saved comparison's ranked list, multi-scan results,
  /// etc.), so no screen needs to remember to call back into History to
  /// refresh it.
  Stream<List<Product>> watchFavoriteProducts(String userId) {
    return _favoritesRepository
        .watchFavoriteProductIds(userId)
        .asyncMap(_resolveProducts);
  }

  Future<List<Product>> _resolveProducts(List<String> ids) async {
    final products = <Product>[];
    for (final id in ids) {
      try {
        products.add(await _productRepository.getProductById(id));
      } catch (_) {
        // Product may have been removed from the catalog since being
        // favorited -- skip it rather than crash the whole favorites list.
      }
    }
    return products;
  }
}