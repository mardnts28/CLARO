import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  GoogleSignIn? _googleSignIn;

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseAuth get _firebaseAuth {
    if (!_isFirebaseReady) {
      throw FirebaseException(
        plugin: 'firebase_core',
        code: 'no-app',
        message: 'Firebase has not been initialized.',
      );
    }
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  FirebaseFirestore get _firebaseDb {
    if (!_isFirebaseReady) {
      throw FirebaseException(
        plugin: 'firebase_core',
        code: 'no-app',
        message: 'Firebase has not been initialized.',
      );
    }
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  GoogleSignIn get _firebaseGoogleSignIn {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firebaseDb.collection('users').doc(credential.user!.uid).set({
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
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Invalid email or password';
    }
  }

  Future<bool> isMfaEnabledForCurrentUser() async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return false;
      final userDoc = await _firebaseDb.collection('users').doc(uid).get();
      final data = userDoc.data();
      return data != null && data['mfaEnabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setMfaEnabled({required bool enabled}) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;
    await _firebaseDb.collection('users').doc(uid).set({'mfaEnabled': enabled}, SetOptions(merge: true));
  }

  /// Sends the OTP code to the user's email using EmailJS.
  /// Template variable names must match exactly what's defined in your
  /// EmailJS "One-Time Password" template: {{passcode}} for the code
  /// and {{time}} for the expiry time.
  /// Replace YOUR_SERVICE_ID, YOUR_TEMPLATE_ID, and YOUR_PUBLIC_KEY
  /// with the actual values from your EmailJS dashboard.
  Future<void> _sendOtpEmail(String email, String code, Timestamp expiresAt) async {
    try {
      // Format the expiry time in a human-readable way, e.g. "14:35".
      final expiry = expiresAt.toDate();
      final formattedTime =
          '${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': 'service_5y6zi4d',
          'template_id': 'template_te10bxg',
          'user_id': 'wJyfTyTAuJIC6XQvn',
          'template_params': {
            'to_email': email,
            'passcode': code,
            'time': formattedTime,
          },
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('Failed to send OTP email: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending OTP email: $e');
    }
  }

  Future<Map<String, dynamic>?> buildOtpChallenge({required String email, required String password}) async {
    final emailResult = await login(email: email, password: password);
    if (emailResult != null) {
      return null;
    }

    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return null;

    final code = (100000 + DateTime.now().microsecondsSinceEpoch % 900000).toString().padLeft(6, '0');
    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(now.toDate().add(const Duration(minutes: 5)));

    await _firebaseDb.collection('login_otps').doc(uid).set({
      'uid': uid,
      'code': code,
      'createdAt': now,
      'expiresAt': expiresAt,
      'attempts': 0,
    });

    await _sendOtpEmail(email, code, expiresAt);

    return {
      'uid': uid,
      'code': code,
      'expiresAt': expiresAt,
    };
  }

  Future<String?> verifyOtp({required String code}) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return 'Unable to verify your identity right now.';
    final otpDoc = await _firebaseDb.collection('login_otps').doc(uid).get();
    if (!otpDoc.exists) return 'This verification code has expired.';
    final data = otpDoc.data();
    if (data == null) return 'This verification code has expired.';
    if ((data['attempts'] as int? ?? 0) >= 5) return 'Too many failed attempts. Please log in again.';
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      await otpDoc.reference.delete();
      return 'This verification code has expired.';
    }
    final matches = data['code'] == code;
    if (!matches) {
      await otpDoc.reference.update({'attempts': FieldValue.increment(1)});
      return 'Invalid verification code.';
    }
    return null;
  }

  Future<void> clearOtpChallenge() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;
    await _firebaseDb.collection('login_otps').doc(uid).delete();
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _firebaseGoogleSignIn.signIn();
      if (googleUser == null) return 'Google sign-in cancelled';

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      final userDoc = await _firebaseDb
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _firebaseDb.collection('users').doc(userCredential.user!.uid).set({
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
    final uid = _firebaseAuth.currentUser!.uid;
    await _firebaseDb.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'conditions': conditions,
      'allergens': allergens,
    }, SetOptions(merge: true));
  }

  Future<bool> hasCompletedOnboarding() async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return false;

      final userDoc = await _firebaseDb.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
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
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _firebaseGoogleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  User? get currentUser {
    if (!_isFirebaseReady) return null;
    return _firebaseAuth.currentUser;
  }

  FirebaseFirestore get db {
    if (!_isFirebaseReady) {
      throw FirebaseException(
        plugin: 'firebase_core',
        code: 'no-app',
        message: 'Firebase has not been initialized.',
      );
    }
    return _firebaseDb;
  }

  /// Safely updates the current user's document with [data]. Tries `update()` first
  /// and falls back to `set(..., SetOptions(merge: true))` when the document
  /// does not exist. Returns true on success, false on failure.
  Future<bool> updateUserData(Map<String, dynamic> data) async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return false;
      final docRef = _firebaseDb.collection('users').doc(uid);
      // Try update first to avoid accidentally creating duplicate/empty docs.
      await docRef.update(data);
      return true;
    } on FirebaseException catch (e) {
      // If document not found, fallback to set with merge
      if (e.code == 'not-found') {
        try {
          final uid = _firebaseAuth.currentUser?.uid;
          if (uid == null) return false;
          await _firebaseDb.collection('users').doc(uid).set(data, SetOptions(merge: true));
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