// lib/logic/user_provider.dart
//
// Loads the signed-in user's UserHealthProfile through UserRepository and
// exposes it to the widget tree. Construct with FirebaseUserRepository()
// for the real app (see main.dart), or MockUserRepository() in tests/local
// dev when you don't want a live Firestore connection.
//
// This class only depends on the UserRepository interface, not Firestore
// directly -- same interface-first pattern as the rest of data/repositories.

import 'package:flutter/foundation.dart';

import '../data/models/health_profile.dart';
import '../data/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({required UserRepository userRepository})
      : _userRepository = userRepository;

  final UserRepository _userRepository;

  UserHealthProfile? _profile;
  UserHealthProfile? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Call this whenever AuthProvider's uid changes (see main.dart's
  // ChangeNotifierProxyProvider wiring). Safe to call with the same id
  // repeatedly -- it just re-fetches.
  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _profile = await _userRepository.getHealthProfile(userId);
    } catch (e) {
      _errorMessage = e.toString();
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Call on sign-out so a stale profile doesn't linger in memory/UI.
  void clear() {
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }
}
