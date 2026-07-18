import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'haptic_service.dart';
import 'package:intl/intl.dart';

class AuthService {
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;
  GoogleSignIn? _googleSignIn;

  /// Global flag to prevent AuthGate from navigating to the Home screen
  /// during the brief moment a login/signup is verifying credentials.
  static final isAuthenticating = ValueNotifier<bool>(false);
  static final pendingMfaChallenge = ValueNotifier<Map<String, dynamic>?>(null);

  /// Shared, app-wide notifier for the current user's display name.
  /// HomeScreen's greeting and ProfileScreen's header both listen to
  /// this instead of caching their own independent copy of the name.
  ///
  /// Previously, editing the name on PersonalInfoScreen only updated
  /// Firestore — HomeScreen and ProfileScreen are sibling tabs kept
  /// alive inside HomeScreen's IndexedStack, so navigating back from
  /// PersonalInfoScreen never recreated either of them or told them
  /// anything had changed. The old name stayed on screen until the
  /// user manually pulled to refresh. Any screen that loads or saves
  /// the name should update this notifier so every listener updates
  /// immediately.
  static final ValueNotifier<String> userNameNotifier = ValueNotifier<String>('User');

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
    isAuthenticating.value = true;
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await _firebaseDb.collection('users').doc(uid).set({
        'uid': uid,
        'email': email.trim().toLowerCase(),
        'createdAt': Timestamp.now(),
      });
      await _updateSessionId(uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } finally {
      isAuthenticating.value = false;
    }
  }

  Future<dynamic> login({
    required String email,
    required String password,
    bool skipMfa = false,
  }) async {
    isAuthenticating.value = true;
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      if (!skipMfa) {
        // mfaCheck is:
        //   true  -> MFA is enabled, must challenge with OTP
        //   false -> MFA is confirmed disabled, proceed normally
        //   null  -> status could NOT be reliably determined (see
        //            _checkMfaEnabled doc). Treat as "unknown" and fail
        //            CLOSED rather than silently letting the user in.
        final mfaCheck = await _checkMfaEnabled(uid);

        if (mfaCheck == null) {
          // Previously this case fell through to a normal successful
          // login, which meant any transient permission-denied/network
          // error during the MFA check silently bypassed MFA entirely.
          // Fail closed instead: sign the user back out and ask them to
          // retry, so a flaky read can never skip the OTP step.
          isAuthenticating.value = false;
          await _firebaseAuth.signOut();
          return 'Could not verify your account\'s security settings. Please check your connection and try logging in again.';
        }

        if (mfaCheck) {
          final challenge = await _prepareAndSendOtp(uid, email);
          pendingMfaChallenge.value = {
            'uid': uid,
            'code': challenge['code'],
            'emailSent': challenge['emailSent'],
            'email': email,
            'password': password,
          };
          return {'status': 'MFA_REQUIRED', ...challenge};
        }
      }

      await _updateSessionId(uid);
      isAuthenticating.value = false;
      return null;
    } on FirebaseAuthException catch (e) {
      isAuthenticating.value = false;
      return e.message ?? 'Invalid email or password';
    } catch (e) {
      isAuthenticating.value = false;
      return e.toString();
    }
  }

  /// Checks whether MFA is enabled for [uid], retrying on transient
  /// permission-denied errors.
  ///
  /// Right after signInWithEmailAndPassword() completes, the freshly
  /// issued auth token can take a brief moment to propagate to Firestore's
  /// security rules, so a Source.server read can throw permission-denied
  /// even though the user really is authenticated (the same race that
  /// isSessionValid() below already retries for).
  ///
  /// Returns:
  ///  - true/false when the check completes successfully
  ///  - null if the status could NOT be reliably determined after retries
  ///
  /// IMPORTANT: callers must treat null as "unknown" and fail closed
  /// (block login / require MFA), never as "MFA disabled". Silently
  /// proceeding on error here was the root cause of MFA being bypassed
  /// intermittently.
  Future<bool?> _checkMfaEnabled(String uid) async {
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        final userDoc = await _firebaseDb
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        final data = userDoc.data();
        return data != null && data['mfaEnabled'] == true;
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          // Token might still be propagating, wait a bit and retry.
          await Future.delayed(const Duration(milliseconds: 500));
          retryCount++;
          continue;
        }
        debugPrint('MFA check failed (non-retryable): $e');
        return null;
      }
    }
    debugPrint('MFA check failed: exhausted retries on permission-denied');
    return null;
  }

  /// Call this after a successful OTP verification to finish the login
  /// (the user is already signed in — we just finalize the session and
  /// let AuthGate proceed).
  Future<void> finishMfaLogin() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid != null) await _updateSessionId(uid);
    pendingMfaChallenge.value = null;
    isAuthenticating.value = false;
  }

  /// Internal helper to generate and store OTP without signing out yet.
  Future<Map<String, dynamic>> _prepareAndSendOtp(String uid, String email) async {
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

    bool emailSent = false;
    try {
      await _sendOtpEmail(email, code, expiresAt);
      emailSent = true;
    } catch (e) {
      // NOTE: if you keep seeing emailSent=false, check the console for
      // the "OTP email" debugPrint lines just above this — they contain
      // the actual HTTP status/body or network error from EmailJS and
      // are the fastest way to diagnose why delivery is failing.
      debugPrint('OTP email delivery failed: $e');
    }

    return {
      'uid': uid,
      'code': code,
      'emailSent': emailSent,
    };
  }

  /// Generates a new session ID, stores it in Firestore and locally.
  /// This ensures that if the user logs in elsewhere, this session becomes invalid.
  Future<void> _updateSessionId(String uid) async {
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    await _firebaseDb.collection('users').doc(uid).update({
      'currentSessionId': sessionId,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionId', sessionId);
  }

  Future<bool> isSessionValid(String uid) async {
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        // Use Source.server to bypass local cache which might be stale immediately after login
        final userDoc = await _firebaseDb.collection('users').doc(uid).get(const GetOptions(source: Source.server));
        if (!userDoc.exists) return false;

        final data = userDoc.data();
        final remoteSessionId = data?['currentSessionId'] as String?;
        if (remoteSessionId == null) return true;

        final prefs = await SharedPreferences.getInstance();
        // Reload prefs to ensure we have the latest written value
        await prefs.reload();
        final localSessionId = prefs.getString('sessionId');

        return localSessionId == remoteSessionId;
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          // Token might still be refreshing, wait a bit and retry
          await Future.delayed(const Duration(milliseconds: 500));
          retryCount++;
          continue;
        }
        debugPrint('isSessionValid check failed: $e');
        return true;
      }
    }
    return true;
  }

  Future<String?> _resolveUid({String? email}) async {
    final currentUid = _firebaseAuth.currentUser?.uid;
    if (currentUid != null) return currentUid;

    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail == null || normalizedEmail.isEmpty) return null;

    final query = await _firebaseDb
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  Future<bool> isMfaEnabledForCurrentUser() async {
    try {
      final uid = await _resolveUid();
      if (uid == null) return false;
      final userDoc = await _firebaseDb.collection('users').doc(uid).get();
      final data = userDoc.data();
      return data != null && data['mfaEnabled'] == true;
    } catch (e) {
      debugPrint('isMfaEnabledForCurrentUser failed: $e');
      return false;
    }
  }

  Future<void> setMfaEnabled({required bool enabled}) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;
    await _firebaseAuth.currentUser?.reload();
    final refreshedUid = _firebaseAuth.currentUser?.uid;
    if (refreshedUid == null) return;
    await _firebaseDb.collection('users').doc(refreshedUid).set({'mfaEnabled': enabled}, SetOptions(merge: true));
  }

  /// EmailJS Public Key (a.k.a. "user_id"). Safe to keep in client code —
  /// this is designed to be public and only identifies your account.
  static const String _emailJsPublicKey = 'wJyfTyTAuJIC6XQvn';

  /// Optional EmailJS Private Key (a.k.a. "accessToken"). Leave this as
  /// an empty string unless you've specifically enabled and generated a
  /// Private Key from EmailJS dashboard -> Account -> Security. If you
  /// have one, paste it here and it will be sent along with each
  /// request, which authenticates the call directly.
  ///
  /// If you DON'T have a Private Key, that's fine — you can still fix
  /// OTP delivery by instead turning on:
  ///   Account -> Security -> "Allow EmailJS API calls from
  ///   non-browser applications"
  /// That toggle alone removes the browser-origin requirement and does
  /// not need any key. Leave _emailJsPrivateKey empty in that case; the
  /// request below only attaches accessToken when this is non-empty.
  static const String _emailJsPrivateKey = 'TPESYD0VrS0MpTSbsQE7y';

  /// Sends the OTP code to the user's email using EmailJS.
  ///
  /// IMPORTANT: EmailJS's REST endpoint rejects calls that don't look like
  /// they came from a browser unless either (a) "Allow EmailJS API calls
  /// from non-browser applications" is enabled in the EmailJS dashboard
  /// under Account -> Security, or (b) the request includes a valid
  /// Private Key as `accessToken` (see _emailJsPrivateKey above). Without
  /// one of those, this call returns a non-200 response (commonly 403)
  /// and no email is ever delivered, even though the OTP code is still
  /// generated and stored in Firestore.
  ///
  /// This method logs the full response and rethrows on failure so the
  /// caller (_prepareAndSendOtp) can record emailSent=false AND you can
  /// see exactly why in the console instead of it failing silently.
  Future<void> _sendOtpEmail(
      String email,
      String code,
      Timestamp expiresAt,
      ) async {
    final expiry = expiresAt.toDate();

    // Format as 12-hour time (e.g. 7:18 PM)
    final formattedTime = DateFormat('h:mm a').format(expiry);

    final templateParams = {
      'service_id': 'service_5y6zi4d',
      'template_id': 'template_te10bxg',
      'user_id': 'wJyfTyTAuJIC6XQvn',
      if (_emailJsPrivateKey.isNotEmpty)
        'accessToken': _emailJsPrivateKey,
      'template_params': {
        'to_email': email,
        'passcode': code,
        'time': formattedTime,
      },
    };

    late final http.Response response;

    try {
      response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(templateParams),
      );
    } catch (e) {
      debugPrint('OTP email network error: $e');
      rethrow;
    }

    debugPrint(
      'OTP email response: ${response.statusCode} - ${response.body}',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'EmailJS rejected the request (${response.statusCode}): ${response.body}. '
            'If this is a 403, enable "Allow EmailJS API calls from non-browser '
            'applications" in EmailJS dashboard -> Account -> Security, or set '
            '_emailJsPrivateKey if you have one.',
      );
    }
  }

  /// TEMPORARY: Verifies credentials, generates an OTP, stores it keyed by uid, and
  /// emails it using direct Firestore operations. The user is signed OUT again
  /// immediately afterward so AuthGate does not let them into the app before OTP verification.
  ///
  /// This is a temporary workaround for testing while Cloud Functions are not deployed.
  /// Once Cloud Functions are deployed on Blaze plan, this should be reverted to use Cloud Functions.
  ///
  /// The returned map's 'uid' MUST be threaded through to verifyOtp()
  /// and clearOtpChallenge() — do NOT rely on _firebaseAuth.currentUser
  /// after this call, because the user is signed out by the time it
  /// returns.
  /// TEMPORARY: Re-runs the OTP challenge for resend functionality.
  Future<Map<String, dynamic>?> buildOtpChallenge({required String email, required String password}) async {
    isAuthenticating.value = true;
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final challenge = await _prepareAndSendOtp(uid, email);
      await _firebaseAuth.signOut();
      return {
        ...challenge,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
        'recipientEmail': email,
      };
    } catch (e) {
      debugPrint('buildOtpChallenge failed: $e');
      isAuthenticating.value = false;
      return null;
    }
  }

  /// Re-sends a fresh OTP for a user who is already signed in to
  /// Firebase Auth — this covers the Google-sign-in MFA case (where
  /// there's no password to re-verify with) as well as any other flow
  /// where re-authenticating with a password isn't possible. Unlike
  /// buildOtpChallenge, this does NOT sign the user out and back in; it
  /// relies on the current Firebase session still being the right one,
  /// which holds true for as long as isAuthenticating +
  /// pendingMfaChallenge keep AuthGate parked on the OTP screen.
  Future<Map<String, dynamic>?> resendOtpForCurrentSession({
    required String uid,
    required String email,
  }) async {
    try {
      return await _prepareAndSendOtp(uid, email);
    } catch (e) {
      debugPrint('resendOtpForCurrentSession failed: $e');
      return null;
    }
  }

  /// TEMPORARY: Verifies OTP using direct Firestore operations.
  /// [uid] must be the value returned from buildOtpChallenge — the user
  /// is NOT signed in at this point, so _firebaseAuth.currentUser is null.
  ///
  /// This is a temporary workaround for testing while Cloud Functions are not deployed.
  /// Once Cloud Functions are deployed on Blaze plan, this should be reverted to use Cloud Functions.
  Future<String?> verifyOtp({required String uid, required String code}) async {
    try {
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
    } catch (e) {
      debugPrint('verifyOtp failed: $e');
      return 'Something went wrong verifying your code. Please try again.';
    }
  }

  /// TEMPORARY: Clears OTP challenge using direct Firestore operations.
  /// [uid] must be the value returned from buildOtpChallenge.
  ///
  /// This is a temporary workaround for testing while Cloud Functions are not deployed.
  /// Once Cloud Functions are deployed on Blaze plan, this should be reverted to use Cloud Functions.
  Future<void> clearOtpChallenge({required String uid}) async {
    await _firebaseDb.collection('login_otps').doc(uid).delete();
  }

  /// Signs in with Google and returns one of:
  ///  - null: success, no MFA required, session established.
  ///  - String: an error message to show the user.
  ///  - Map: {'status': 'MFA_REQUIRED', ...} — the caller must NOT
  ///    navigate to Home/Onboarding. AuthGate will show
  ///    OtpVerificationScreen automatically (isAuthenticating stays true
  ///    and pendingMfaChallenge is set), exactly like the email/password
  ///    login() flow above.
  ///
  /// IMPORTANT: previously this method returned null (success) as soon
  /// as signInWithCredential succeeded, without ever checking whether
  /// the account had MFA enabled. That meant a user with MFA turned on
  /// could sign in with Google and land straight on the Home screen,
  /// completely bypassing the OTP step. The check below closes that gap
  /// using the same fail-closed logic as login().
  Future<dynamic> signInWithGoogle() async {
    isAuthenticating.value = true;
    try {
      // Clear previous sign-in state to ensure the account picker shows up
      try {
        await _firebaseGoogleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _firebaseGoogleSignIn.signIn();
      if (googleUser == null) {
        isAuthenticating.value = false;
        return 'Google sign-in cancelled';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final email = userCredential.user!.email ?? '';

      final userDoc = await _firebaseDb.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        final displayName = userCredential.user!.displayName ?? '';
        await _firebaseDb.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'name': displayName,
          'createdAt': Timestamp.now(),
        });
      }

      // Same fail-closed MFA check used by login(). See _checkMfaEnabled
      // doc: null means "could not be determined", which must NEVER be
      // treated as "MFA disabled".
      final mfaCheck = await _checkMfaEnabled(uid);

      if (mfaCheck == null) {
        isAuthenticating.value = false;
        await signOut();
        return 'Could not verify your account\'s security settings. Please check your connection and try again.';
      }

      if (mfaCheck) {
        final challenge = await _prepareAndSendOtp(uid, email);
        pendingMfaChallenge.value = {
          'uid': uid,
          'code': challenge['code'],
          'emailSent': challenge['emailSent'],
          'email': email,
          // No password for a Google-originated session — the OTP
          // screen's resend logic uses resendOtpForCurrentSession()
          // instead of buildOtpChallenge() when this is null.
          'password': null,
        };
        return {'status': 'MFA_REQUIRED', ...challenge};
      }

      await _updateSessionId(uid);
      isAuthenticating.value = false;
      return null;
    } catch (e) {
      isAuthenticating.value = false;
      if (e.toString().contains('ApiException: 10')) {
        return 'Google Sign-In Error (10): This usually means the SHA-1 fingerprint is missing or the package name is incorrect in the Firebase Console.';
      }
      return e.toString();
    }
  }

  Future<void> saveOnboardingData({
    required String name,
    required String age,
    required List<String> conditions,
    required List<String> allergens,
  }) async {
    final uid = _firebaseAuth.currentUser!.uid;
    final userDoc = await _firebaseDb.collection('users').doc(uid).get();

    final data = <String, dynamic>{
      'uid': uid,
      'conditions': conditions,
      'allergens': allergens,
      'onboardingComplete': true,
    };

    final docData = userDoc.data();
    // Only set name and age if they don't already exist (prevent system overwrites).
    // NOTE: this method is for the ONE-TIME onboarding flow only. Do NOT call
    // this method again from a profile/edit screen to change name or age —
    // this guard will silently block the update. Use updateUserData() instead.
    if (!userDoc.exists || docData == null || !docData.containsKey('name')) {
      data['name'] = name;
    }
    if (!userDoc.exists || docData == null || !docData.containsKey('age')) {
      data['age'] = age;
    }

    await _firebaseDb.collection('users').doc(uid).set(data, SetOptions(merge: true));
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
    isAuthenticating.value = false;
    // Reset personalized feedback on logout
    HapticService().updateEnabled(false);

    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid != null) {
        // Clear session ID in Firestore to prevent race conditions on next login
        await _firebaseDb.collection('users').doc(uid).update({'currentSessionId': null});
      }
    } catch (e) {
      debugPrint('Error clearing session ID on sign out: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionId');
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

  /// Safely updates the current user's document with [data]. This is the
  /// method profile/edit screens should call to change name/age — it has
  /// no "only set if missing" guard, unlike saveOnboardingData().
  /// Returns true on success, false on failure. Errors are logged via
  /// debugPrint; if edits still don't show up in Firestore, check your
  /// console output for a permission-denied error from your security rules.
  Future<bool> updateUserData(Map<String, dynamic> data) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      debugPrint('updateUserData failed: no authenticated user.');
      return false;
    }

    final docRef = _firebaseDb.collection('users').doc(uid);
    try {
      // Try update first to avoid accidentally creating duplicate/empty docs.
      await docRef.update(data);
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        try {
          await docRef.set(data, SetOptions(merge: true));
          return true;
        } catch (e2) {
          debugPrint('updateUserData fallback set failed: $e2');
          return false;
        }
      }
      debugPrint('updateUserData failed (${e.code}): ${e.message}');
      return false;
    } catch (e) {
      debugPrint('updateUserData unexpected error: $e');
      return false;
    }
  }
}