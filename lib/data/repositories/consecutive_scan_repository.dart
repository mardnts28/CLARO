// lib/data/repositories/consecutive_scan_repository.dart
//
// Tracks consecutive-day scanning behavior per product per user.
// Backed by Firestore at `users/{userId}/consecutive_scans/{productId}`.
// Used to display health warnings when a product is scanned on 2+ consecutive days.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ConsecutiveScanRepository {
  /// Gets the consecutive scan data for a specific product.
  Future<Map<String, dynamic>?> getConsecutiveScans({
    required String userId,
    required String productId,
  });

  /// Updates the consecutive scan data after a new scan.
  /// Returns the updated consecutive day count.
  Future<int> recordScan({
    required String userId,
    required String productId,
  });

  /// Clears the consecutive scan data for a product (e.g., if user deletes all history).
  Future<void> clearProduct({
    required String userId,
    required String productId,
  });
}

class FirebaseConsecutiveScanRepository implements ConsecutiveScanRepository {
  FirebaseConsecutiveScanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('consecutive_scans');

  @override
  Future<Map<String, dynamic>?> getConsecutiveScans({
    required String userId,
    required String productId,
  }) async {
    final doc = await _collection(userId).doc(productId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  @override
  Future<int> recordScan({
    required String userId,
    required String productId,
  }) async {
    final now = DateTime.now();
    final today = _formatDate(now);
    final yesterday = _formatDate(now.subtract(const Duration(days: 1)));

    final docRef = _collection(userId).doc(productId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // First scan of this product
      await docRef.set({
        'consecutiveDays': 1,
        'lastScanDate': today,
        'scanDates': [today],
      });
      return 1;
    }

    final data = doc.data()!;
    final lastScanDate = data['lastScanDate'] as String? ?? '';
    final consecutiveDays = data['consecutiveDays'] as int? ?? 0;
    final scanDates = List<String>.from(data['scanDates'] as List? ?? []);

    if (lastScanDate == today) {
      // Already scanned today - no change needed
      return consecutiveDays;
    } else if (lastScanDate == yesterday) {
      // Scanned yesterday - increment consecutive days
      final newCount = consecutiveDays + 1;
      scanDates.add(today);
      await docRef.update({
        'consecutiveDays': newCount,
        'lastScanDate': today,
        'scanDates': scanDates,
      });
      return newCount;
    } else {
      // Streak broken - reset to 1
      await docRef.update({
        'consecutiveDays': 1,
        'lastScanDate': today,
        'scanDates': [today],
      });
      return 1;
    }
  }

  @override
  Future<void> clearProduct({
    required String userId,
    required String productId,
  }) async {
    await _collection(userId).doc(productId).delete();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
