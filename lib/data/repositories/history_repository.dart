// lib/data/repositories/history_repository.dart
//
// Interface-first, same pattern as ProductRepository / UserRepository /
// FavoritesRepository -- HistoryService only ever talks to this
// abstraction, never to Firestore directly.
//
// Backed by `users/{userId}/history`, a per-user subcollection so history
// is private to each account, persists across restarts, and syncs across
// a user's devices the same way favorites and the health profile already
// do.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/history_item.dart';

abstract class HistoryRepository {
  /// Real-time, newest-first stream of every history record (scans +
  /// comparisons) for [userId]. Firestore's on-device cache means this
  /// keeps emitting from local data while offline and reconciles
  /// automatically once connectivity returns -- callers don't need any
  /// extra offline handling of their own.
  Stream<List<HistoryItem>> watchHistory(String userId);

  Future<void> addItem({required String userId, required HistoryItem item});

  Future<void> deleteItem({required String userId, required String itemId});

  Future<void> clearAll(String userId);

  /// Updates the legacy per-record favorite flag (see HistoryItem docs).
  Future<void> setFavoriteFlag({
    required String userId,
    required String itemId,
    required bool isFavorite,
  });
}

class FirebaseHistoryRepository implements HistoryRepository {
  FirebaseHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _historyCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('history');

  @override
  Stream<List<HistoryItem>> watchHistory(String userId) {
    return _historyCollection(userId)
        .orderBy('timestamp', descending: true)
        // includeMetadataChanges so pending offline writes (from the local
        // cache) show up immediately instead of waiting for server ack.
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> addItem({required String userId, required HistoryItem item}) async {
    // Use the caller-supplied id as the doc id (it's already a timestamp-
    // derived, per-record-type id -- see HistoryService) so retries of the
    // same logical write don't create duplicate rows.
    await _historyCollection(userId).doc(item.id).set(_toMap(item));
  }

  @override
  Future<void> deleteItem({required String userId, required String itemId}) async {
    await _historyCollection(userId).doc(itemId).delete();
  }

  @override
  Future<void> clearAll(String userId) async {
    final snapshot = await _historyCollection(userId).get();
    if (snapshot.docs.isEmpty) return;

    // Firestore batches cap at 500 writes -- chunk defensively in case a
    // user's history ever grows past that.
    const chunkSize = 450;
    for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
      final chunk = snapshot.docs.skip(i).take(chunkSize);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> setFavoriteFlag({
    required String userId,
    required String itemId,
    required bool isFavorite,
  }) async {
    await _historyCollection(userId).doc(itemId).update({'isFavorite': isFavorite});
  }

  HistoryItem _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return HistoryItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: (data['type'] as String?) == 'comparison'
          ? HistoryType.comparison
          : HistoryType.scan,
      productId: data['productId'] as String?,
      isFavorite: data['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _toMap(HistoryItem item) {
    return {
      'title': item.title,
      'subtitle': item.subtitle,
      'timestamp': Timestamp.fromDate(item.timestamp),
      'type': item.type == HistoryType.comparison ? 'comparison' : 'scan',
      'productId': item.productId,
      'isFavorite': item.isFavorite,
    };
  }
}
