// lib/data/repositories/favorites_repository.dart
//
// Backs the heart-button "save to favorites" feature. Same interface-first
// pattern as ProductRepository/UserRepository -- logic and UI only ever
// talk to this abstraction, so swapping to real Firestore later is a
// one-line change (MockFavoritesRepository() -> FirebaseFavoritesRepository()).

abstract class FavoritesRepository {
  Future<List<String>> getFavoriteProductIds(String userId);
  Future<bool> isFavorite({required String userId, required String productId});
  Future<void> addFavorite({required String userId, required String productId});
  Future<void> removeFavorite({required String userId, required String productId});

  // Convenience for the heart-button tap handler -- flips the state and
  // returns the NEW state, so the UI can update the icon in one call
  // without a separate isFavorite() check first.
  Future<bool> toggleFavorite({required String userId, required String productId});
}

class MockFavoritesRepository implements FavoritesRepository {
  static const _simulatedDelay = Duration(milliseconds: 150);

  // In-memory only -- resets on app restart. Real persistence (Firestore or
  // local storage) comes later; this exists so the heart-button UI has
  // something real to call and test against right now.
  final Map<String, Set<String>> _favoritesByUser = {};

  @override
  Future<List<String>> getFavoriteProductIds(String userId) async {
    await Future.delayed(_simulatedDelay);
    return _favoritesByUser[userId]?.toList() ?? [];
  }

  @override
  Future<bool> isFavorite({required String userId, required String productId}) async {
    await Future.delayed(_simulatedDelay);
    return _favoritesByUser[userId]?.contains(productId) ?? false;
  }

  @override
  Future<void> addFavorite({required String userId, required String productId}) async {
    await Future.delayed(_simulatedDelay);
    _favoritesByUser.putIfAbsent(userId, () => <String>{}).add(productId);
  }

  @override
  Future<void> removeFavorite({required String userId, required String productId}) async {
    await Future.delayed(_simulatedDelay);
    _favoritesByUser[userId]?.remove(productId);
  }

  @override
  Future<bool> toggleFavorite({required String userId, required String productId}) async {
    await Future.delayed(_simulatedDelay);
    final favorites = _favoritesByUser.putIfAbsent(userId, () => <String>{});
    if (favorites.contains(productId)) {
      favorites.remove(productId);
      return false; // now NOT a favorite
    } else {
      favorites.add(productId);
      return true; // now IS a favorite
    }
  }
}

// TODO (Phase 6): implement once the real Firebase project + Firestore
// collections exist.
// class FirebaseFavoritesRepository implements FavoritesRepository { ... }