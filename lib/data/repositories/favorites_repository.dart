// lib/data/repositories/favorites_repository.dart
//
// Backs the heart-button "save to favorites" feature. Same interface-first
// pattern as ProductRepository/UserRepository -- logic and UI only ever
// talk to this abstraction, so swapping to real Firestore later is a
// one-line change (MockFavoritesRepository() -> FirebaseFavoritesRepository()).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FavoritesRepository {
  Future<List<String>> getFavoriteProductIds(String userId);
  Future<bool> isFavorite({required String userId, required String productId});
  Future<void> addFavorite({required String userId, required String productId});
  Future<void> removeFavorite({required String userId, required String productId});

  // Convenience for the heart-button tap handler -- flips the state and
  // returns the NEW state, so the UI can update the icon in one call
  // without a separate isFavorite() check first.
  Future<bool> toggleFavorite({
    required String userId,
    required String productId,
    bool? isCurrentlyFavorite,
  });

  /// Real-time stream of a user's favorited productIds. Any screen that
  /// shows favorite status should subscribe to this rather than doing a
  /// one-off fetch tied to a specific Navigator.push/pop pair -- that
  /// pattern is exactly what caused favoriting from a saved comparison's
  /// ranked list to not show up in the Favorites tab: whichever screen you
  /// favorited from, and however you navigated back, is irrelevant to a
  /// live stream -- it reflects Firestore directly.
  Stream<List<String>> watchFavoriteProductIds(String userId);
}

class MockFavoritesRepository implements FavoritesRepository {
  static const _simulatedDelay = Duration(milliseconds: 150);

  // In-memory only -- resets on app restart. Real persistence (Firestore or
  // local storage) comes later; this exists so the heart-button UI has
  // something real to call and test against right now.
  final Map<String, Set<String>> _favoritesByUser = {};

  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notifyChanged() => _changes.add(null);

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
    _notifyChanged();
  }

  @override
  Future<void> removeFavorite({required String userId, required String productId}) async {
    await Future.delayed(_simulatedDelay);
    _favoritesByUser[userId]?.remove(productId);
    _notifyChanged();
  }

  @override
  Future<bool> toggleFavorite({
    required String userId,
    required String productId,
    bool? isCurrentlyFavorite,
  }) async {
    await Future.delayed(_simulatedDelay);
    final favorites = _favoritesByUser.putIfAbsent(userId, () => <String>{});
    final bool result;
    if (isCurrentlyFavorite != null) {
      if (isCurrentlyFavorite) {
        favorites.remove(productId);
        result = false;
      } else {
        favorites.add(productId);
        result = true;
      }
    } else if (favorites.contains(productId)) {
      favorites.remove(productId);
      result = false; // now NOT a favorite
    } else {
      favorites.add(productId);
      result = true; // now IS a favorite
    }
    _notifyChanged();
    return result;
  }

  @override
  Stream<List<String>> watchFavoriteProductIds(String userId) async* {
    yield _favoritesByUser[userId]?.toList() ?? [];
    yield* _changes.stream.map((_) => _favoritesByUser[userId]?.toList() ?? []);
  }
}

// Backed by `users/{userId}/favorites`, a per-user subcollection -- one doc
// per favorited product, doc ID == productId (so add/remove/isFavorite are
// all simple, race-free doc-id lookups rather than array-membership
// updates). This is what makes favorites persist across restarts and sync
// across a user's devices.
class FirebaseFavoritesRepository implements FavoritesRepository {
  FirebaseFavoritesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _favoritesCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('favorites');

  @override
  Future<List<String>> getFavoriteProductIds(String userId) async {
    try {
      final snapshot = await _favoritesCollection(userId)
          .get(const GetOptions(source: Source.cache));
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => doc.id).toList();
      }
    } catch (_) {}

    try {
      final snapshot = await _favoritesCollection(userId)
          .get()
          .timeout(const Duration(milliseconds: 2000));
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> isFavorite({required String userId, required String productId}) async {
    try {
      final doc = await _favoritesCollection(userId)
          .doc(productId)
          .get(const GetOptions(source: Source.cache));
      return doc.exists;
    } catch (_) {
      try {
        final doc = await _favoritesCollection(userId)
            .doc(productId)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        return doc.exists;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Future<void> addFavorite({required String userId, required String productId}) async {
    await _favoritesCollection(userId).doc(productId).set({
      'productId': productId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeFavorite({required String userId, required String productId}) async {
    await _favoritesCollection(userId).doc(productId).delete();
  }

  @override
  Future<bool> toggleFavorite({
    required String userId,
    required String productId,
    bool? isCurrentlyFavorite,
  }) async {
    final docRef = _favoritesCollection(userId).doc(productId);
    bool wasFavorite = false;

    if (isCurrentlyFavorite != null) {
      wasFavorite = isCurrentlyFavorite;
    } else {
      try {
        final doc = await docRef.get(const GetOptions(source: Source.cache));
        wasFavorite = doc.exists;
      } catch (_) {
        try {
          final doc = await docRef.get().timeout(const Duration(milliseconds: 1500));
          wasFavorite = doc.exists;
        } catch (_) {
          wasFavorite = false;
        }
      }
    }

    if (wasFavorite) {
      await docRef.delete();
      return false; // now NOT a favorite
    } else {
      await docRef.set({
        'productId': productId,
        'addedAt': FieldValue.serverTimestamp(),
      });
      return true; // now IS a favorite
    }
  }

  @override
  Stream<List<String>> watchFavoriteProductIds(String userId) {
    return _favoritesCollection(userId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}