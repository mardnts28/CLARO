import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _db.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'createdAt': Timestamp.now(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      // Return generic error message for security
      return 'Invalid email or password';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google sign-in cancelled';

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final userDoc = await _db
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName,
          'createdAt': Timestamp.now(),
        });
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> saveOnboardingData({
    required String name,
    required List<String> conditions,
    required List<String> allergens,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'conditions': conditions,
      'allergens': allergens,
    }, SetOptions(merge: true));
  }

  Future<bool> hasCompletedOnboarding() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

        final userDoc = await _db.collection('users').doc(uid).get();
        if (!userDoc.exists) return false;

        final data = userDoc.data() as Map<String, dynamic>?;
        return data != null &&
          data.containsKey('name') &&
          data['name'] != null &&
          data['name'].toString().isNotEmpty &&
          data.containsKey('conditions') &&
          data.containsKey('allergens');
    } catch (e) {
      return false;
    }
  }

  Future<String?> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
  FirebaseFirestore get db => _db;

  /// Safely updates the current user's document with [data]. Tries `update()` first
  /// and falls back to `set(..., SetOptions(merge: true))` when the document
  /// does not exist. Returns true on success, false on failure.
  Future<bool> updateUserData(Map<String, dynamic> data) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      final docRef = _db.collection('users').doc(uid);
      // Try update first to avoid accidentally creating duplicate/empty docs.
      await docRef.update(data);
      return true;
    } on FirebaseException catch (e) {
      // If document not found, fallback to set with merge
      if (e.code == 'not-found') {
        try {
          final uid = _auth.currentUser?.uid;
          if (uid == null) return false;
          await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
          return true;
        } catch (e2) {
          debugPrint('Fallback set failed: $e2');
          return false;
        }
      }
      debugPrint('Update failed: $e');
      return false;
    } catch (e) {
      debugPrint('Unexpected error updating user data: $e');
      return false;
    }
  }
}