import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_profile.dart';
import 'firestore_label_mappings.dart';
import 'mock_data/mock_users.dart';

const _workerUrl = 'https://health-data-worker.claro-app.workers.dev';

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
// Health-sensitive fields (conditions, allergens) are decrypted server-side
// by the Cloudflare Worker -- never decrypted on-device, never handled with
// a client-held key.
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

    // 2. Check persistent disk cache (survives app restarts and eliminates
    //    a network round trip to the Worker)
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
        // Non-fatal: fallback to remote fetch if cache read fails
      }
    }

    // 3. Remote fetch: plain fields still come straight from Firestore,
    //    but conditions/allergens go through the Cloudflare Worker, which
    //    verifies the caller's Firebase ID token and decrypts server-side.
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      throw Exception('User profile not found: $userId');
    }
    final data = snapshot.data()!;

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw Exception('No authenticated user; cannot fetch health profile');
    }

    final res = await http.get(
      Uri.parse('$_workerUrl/health-profile'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch health profile: ${res.statusCode} ${res.body}');
    }
    final healthData = jsonDecode(res.body) as Map<String, dynamic>;

    final profile = UserHealthProfile(
      userId: userId,
      displayName: data['name'] as String? ?? '',
      conditions: mapConditionLabels(List<String>.from(healthData['conditions'] ?? [])),
      allergies: mapAllergenLabels(List<String>.from(healthData['allergens'] ?? [])),
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