import 'guest_session.dart';

/// In-memory favorites for guests. The set is deliberately never serialized.
class GuestFavoritesService {
  GuestFavoritesService._();

  static final Set<String> _favoriteProductIds = <String>{};

  static bool isFavorite(String productId) => _favoriteProductIds.contains(productId);

  static bool toggle(String productId) {
    if (!GuestSession.isGuest.value) return false;
    if (!_favoriteProductIds.add(productId)) {
      _favoriteProductIds.remove(productId);
      return false;
    }
    return true;
  }

  static void clear() => _favoriteProductIds.clear();
}
