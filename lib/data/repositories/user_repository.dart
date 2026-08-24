import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/health_data_crypto.dart';
import '../models/health_profile.dart';
import 'firestore_label_mappings.dart';
import 'mock_data/mock_users.dart';

abstract class UserRepository {
  Future<UserHealthProfile> getHealthProfile(String userId, {bool forceRefresh = false});
  void invalidateCache([String? userId]);
  void updateCachedProfile(UserHealthProfile profile);
}

class MockUserRepository implements UserRepository {
  static const _simulatedDelay = Duration(milliseconds: 200);
  final Map<String, UserHealthProfile> _memoryCache = {};

  @override
  Future<UserHealthProfile> getHealthProfile(String userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache.containsKey(userId)) {
      return _memoryCache[userId]!;
    }
    await Future.delayed(_simulatedDelay);
    final match = mockUsersJson.firstWhere(
      (u) => u['userId'] == userId,
      orElse: () => throw Exception('User profile not found: $userId'),
    );
    final profile = UserHealthProfile.fromJson(match);
    _memoryCache[userId] = profile;
    return profile;
  }

  @override
  void invalidateCache([String? userId]) {
    if (userId != null) {
      _memoryCache.remove(userId);
    } else {
      _memoryCache.clear();
    }
  }

  @override
  void updateCachedProfile(UserHealthProfile profile) {
    _memoryCache[profile.userId] = profile;
  }
}

// Reads from your groupmate's `users/{uid}` collection with local memory
// and persistent storage caching so subsequent scans/screens load instantly.
class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, UserHealthProfile> _memoryCache = {};

  static String _persistentCacheKey(String userId) =>
      'user_health_profile_cache_$userId';

  @override
  Future<UserHealthProfile> getHealthProfile(String userId, {bool forceRefresh = false}) async {
    // 1. Check in-memory cache first for instant (<1ms) response
    if (!forceRefresh && _memoryCache.containsKey(userId)) {
      return _memoryCache[userId]!;
    }

    // 2. Check persistent disk cache (survives app restarts and eliminates Firestore read)
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString(_persistentCacheKey(userId));
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          final profile = UserHealthProfile.fromJson(decoded);
          _memoryCache[userId] = profile;
          return profile;
        }
      } catch (e) {
        // Non-fatal: fallback to Firestore if cache read fails
      }
    }

    // 3. Remote fetch from Firestore
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      throw Exception('User profile not found: $userId');
    }
    final data = snapshot.data()!;

    final decryptedConditions = HealthDataCrypto.decryptField(
      data['conditions'],
    );
    final decryptedAllergens = HealthDataCrypto.decryptField(
      data['allergens'],
    );

    final profile = UserHealthProfile(
      userId: userId,
      displayName: data['name'] as String? ?? '',
      conditions: mapConditionLabels(decryptedConditions),
      allergies: mapAllergenLabels(decryptedAllergens),
      voiceAssistant: data['voiceAssistant'] as bool? ?? false,
    );

    _memoryCache[userId] = profile;
    _persistProfile(userId, profile);
    return profile;
  }

  @override
  void invalidateCache([String? userId]) {
    if (userId != null) {
      _memoryCache.remove(userId);
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_persistentCacheKey(userId));
      }).catchError((_) {});
    } else {
      _memoryCache.clear();
    }
  }

  @override
  void updateCachedProfile(UserHealthProfile profile) {
    _memoryCache[profile.userId] = profile;
    _persistProfile(profile.userId, profile);
  }

  void _persistProfile(String userId, UserHealthProfile profile) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_persistentCacheKey(userId), jsonEncode(profile.toJson()));
    }).catchError((e) {
      // Non-fatal logging
    });
  }
}