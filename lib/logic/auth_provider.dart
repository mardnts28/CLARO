// lib/logic/auth_provider.dart
//
// Thin ChangeNotifier wrapper around FirebaseAuth so widgets can watch
// sign-in state via `context.watch<AuthProvider>()` without touching
// FirebaseAuth directly. UserProvider watches `uid` from here and loads
// the matching Firestore health profile once a user is signed in.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _authSubscription;

  User? _currentUser;
  User? get currentUser => _currentUser;
  String? get uid => _currentUser?.uid;
  bool get isSignedIn => _currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _onAuthStateChanged(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() => _auth.signOut();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
