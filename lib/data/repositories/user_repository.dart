// lib/data/repositories/user_repository.dart
//
// Same interface-first pattern as ProductRepository. Your advisory logic
// only depends on this abstraction, not on where the profile actually
// comes from.

import '../models/health_profile.dart';
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

// TODO (Phase 6): implement once user_provider.dart's real Firestore-backed
// auth/profile system is ready.
// class FirebaseUserRepository implements UserRepository { ... }
