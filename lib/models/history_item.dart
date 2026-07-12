// lib/models/history_item.dart
//
// Pure data model for a single history-screen entry (a scan or a
// comparison). Deliberately has no knowledge of Firestore or any other data
// source -- mapping to/from Firestore documents lives in
// data/repositories/history_repository.dart, the same split used by
// UserHealthProfile / FirebaseUserRepository.

enum HistoryType { scan, comparison }

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final HistoryType type;
  final String? productId;

  // For comparison items, store the source product ID to enable reopening
  final String? sourceProductId;

  // Legacy per-record favorite flag. The History screen's "Paborito" tab no
  // longer reads this -- it filters against BackendLocator.favoritesService
  // (the product-level, cross-device source of truth) instead. This field
  // is kept only so HistoryService.toggleFavorite()/existing callers don't
  // break, and is persisted to Firestore for backward compatibility.
  bool isFavorite;

  HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    this.productId,
    this.sourceProductId,
    this.isFavorite = false,
  });

  HistoryItem copyWith({
    String? title,
    String? subtitle,
    DateTime? timestamp,
    HistoryType? type,
    String? productId,
    String? sourceProductId,
    bool? isFavorite,
  }) {
    return HistoryItem(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      productId: productId ?? this.productId,
      sourceProductId: sourceProductId ?? this.sourceProductId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
