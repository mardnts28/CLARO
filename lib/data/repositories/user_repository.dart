// lib/data/repositories/user_repository.dart
//
// Same interface-first pattern as ProductRepository. Your advisory logic
// only depends on this abstraction, not on where the profile actually
// comes from.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/health_data_crypto.dart';
import '../models/health_profile.dart';
import 'firestore_label_mappings.dart';
import 'mock_data/mock_users.dart';

abstract class UserRepository {
  Future<UserHealthProfile> getHealthProfile(String userId);
}

class MockUserRepository implements UserRepository {
  static const _simulatedDelay = Duration(milliseconds: 200);

  @override
  Future<UserHealthProfile> getHealthProfile(String userId) async {
    await Future.delayed(_simulatedDelay);
    final match = mockUsersJson.firstWhere(
      (u) => u['userId'] == userId,
      orElse: () => throw Exception('User profile not found: $userId'),
    );
    return UserHealthProfile.fromJson(match);
  }
}

// Reads from your groupmate's `users/{uid}` collection. The document ID is
// expected to be the Firebase Auth uid (confirmed from the schema
// screenshot -- the doc ID matches Auth's 28-char uid format).
//
// The user doc stores exactly: id (doc ID), name, health condition(s),
// allergy(ies), and voiceAssistant -- no dietary restrictions field.
//
// Field-name/shape differences from UserHealthProfile.fromJson() are
// translated here rather than in the model, so the model stays a clean
// representation of what your logic layer expects, independent of how any
// one data source happens to store it:
//   - Firestore's `name`      -> our `displayName`
//   - Firestore's `allergens` -> our `allergies`
//   - Firestore's `conditions`/`allergens` are English/Tagalog display
//     labels from the app's language toggle (e.g. "Alta-presyon" or
//     "Hypertension" for the same underlying selection), translated via
//     firestore_label_mappings.dart.
class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<UserHealthProfile> getHealthProfile(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    if (!snapshot.exists) {
      throw Exception('User profile not found: $userId');
    }
    final data = snapshot.data()!;

    // 'conditions'/'allergens' are stored encrypted (see
    // core/utils/health_data_crypto.dart). Decrypt back into the same
    // List<String> of English/Tagalog labels mapConditionLabels() and
    // mapAllergenLabels() already expected -- this is the ONLY place
    // decryption needs to happen for the advisory/ranking/comparison
    // pipeline, since everything downstream of this repository already
    // consumes the resulting UserHealthProfile, never raw Firestore
    // fields directly.
    final decryptedConditions = HealthDataCrypto.decryptField(
      data['conditions'],
    );
    final decryptedAllergens = HealthDataCrypto.decryptField(
      data['allergens'],
    );

    return UserHealthProfile(
      userId: userId,
      displayName: data['name'] as String? ?? '',
      conditions: mapConditionLabels(decryptedConditions),
      allergies: mapAllergenLabels(decryptedAllergens),
      voiceAssistant: data['voiceAssistant'] as bool? ?? false,
    );
  }
}