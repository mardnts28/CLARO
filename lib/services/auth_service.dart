import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'haptic_service.dart';
import 'home_tab_controller.dart';
import 'package:intl/intl.dart';

// Base URL for the Cloudflare Worker that performs server-side encryption
// and decryption of health conditions/allergens. The key never lives on
// the client -- see health-data-worker/ for the Worker implementation.
const _workerUrl = 'https://health-data-worker.claro-app.workers.dev';
/// Outcome of a [AuthService.deleteAccount] attempt.
///
///  - [success]: both the Firestore doc and the Firebase Auth user are
///    gone. Nothing further to do -- AuthGate will react to the Auth
///    sign-out on its own.
///  - [reauthRequired]: Firebase Auth refused to delete the user because
///    the current session isn't "recent" enough (`requires-recent-login`).
///    The user is still signed in at this point -- deliberately NOT
///    signed out -- so the caller can prompt for fresh credentials and
///    retry by calling deleteAccount() again with a `credential`. See
///    [DeleteAccountResult.providerIds] for which credential type to ask
///    for (password vs. Google).
///  - [error]: something else failed. Nothing was left half-deleted
///    (Firestore delete is attempted first specifically so a failure
///    here never leaves an orphaned Auth user with no matching doc).
enum DeleteAccountStatus { success, reauthRequired, error }

class DeleteAccountResult {
  final DeleteAccountStatus status;
  final String? message;
  final List<String>? providerIds;

  const DeleteAccountResult._(this.status, this.message, this.providerIds);

  factory DeleteAccountResult.success() =>
      const DeleteAccountResult._(DeleteAccountStatus.success, null, null);

  factory DeleteAccountResult.reauthRequired(List<String> providerIds) =>
      DeleteAccountResult._(DeleteAccountStatus.reauthRequired, null, providerIds);

  factory DeleteAccountResult.error(String message) =>
      DeleteAccountResult._(DeleteAccountStatus.error, message, null);
}

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
      
      try {
        await _firebaseDb.collection('users').doc(uid).set({
          'uid': uid,
          'email': email.trim().toLowerCase(),
          'createdAt': Timestamp.now(),
        });
        debugPrint('Firestore user document created successfully for UID: $uid');
      } on FirebaseException catch (e) {
        debugPrint('Firestore write failed during signup for UID $uid: ${e.code} - ${e.message}');
        // Clean up the auth user since we couldn't create their document
        await credential.user?.delete();
        return 'Failed to create your account data. Please check your connection and try again.';
      }
      
      await _updateSessionId(uid);
      
      // TEMPORARY: Print Firebase ID token for API testing
      try {
        final user = _firebaseAuth.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken(true);
          debugPrint('=== FIREBASE ID TOKEN FOR API TESTING ===');
          debugPrint(idToken);
          debugPrint('=== END TOKEN ===');
        }
      } catch (e) {
        debugPrint('Error getting ID token: $e');
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth signup failed: ${e.code} - ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('Unexpected error during signup: $e');
      return 'An unexpected error occurred. Please try again.';
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
      
      // TEMPORARY: Print Firebase ID token for API testing
      try {
        final user = _firebaseAuth.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken(true);
          debugPrint('=== FIREBASE ID TOKEN FOR API TESTING ===');
          debugPrint(idToken);
          debugPrint('=== END TOKEN ===');
        }
      } catch (e) {
        debugPrint('Error getting ID token: $e');
      }
      
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
    
    // TEMPORARY: Print Firebase ID token for API testing
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken(true);
        debugPrint('=== FIREBASE ID TOKEN FOR API TESTING ===');
        debugPrint(idToken);
        debugPrint('=== END TOKEN ===');
      }
    } catch (e) {
      debugPrint('Error getting ID token: $e');
    }
    
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
    try {
      await _firebaseDb.collection('users').doc(uid).update({
        'currentSessionId': sessionId,
      });
    } on FirebaseException catch (e) {
      debugPrint('Failed to update session ID for UID $uid: ${e.code} - ${e.message}');
      // If the document doesn't exist, try to create it
      if (e.code == 'not-found') {
        try {
          await _firebaseDb.collection('users').doc(uid).set({
            'uid': uid,
            'currentSessionId': sessionId,
          }, SetOptions(merge: true));
        } catch (e2) {
          debugPrint('Failed to create user document for session ID: $e2');
        }
      }
    }
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
      'user_id': _emailJsPublicKey,
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
        try {
          final displayName = userCredential.user!.displayName ?? '';
          await _firebaseDb.collection('users').doc(uid).set({
            'uid': uid,
            'email': email,
            'name': displayName,
            'createdAt': Timestamp.now(),
          });
          debugPrint('Firestore user document created for Google Sign-In UID: $uid');
        } on FirebaseException catch (e) {
          debugPrint('Firestore write failed during Google Sign-In for UID $uid: ${e.code} - ${e.message}');
          // Clean up the auth user since we couldn't create their document
          await _firebaseAuth.signOut();
          return 'Failed to create your account data. Please check your connection and try again.';
        }
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
      
      // TEMPORARY: Print Firebase ID token for API testing
      try {
        final user = _firebaseAuth.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken(true);
          debugPrint('=== FIREBASE ID TOKEN FOR API TESTING ===');
          debugPrint(idToken);
          debugPrint('=== END TOKEN ===');
        }
      } catch (e) {
        debugPrint('Error getting ID token: $e');
      }
      
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

  /// Sends [conditions]/[allergens] to the Cloudflare Worker for
  /// server-side encryption. Returns true on success. This is the ONLY
  /// path that writes those two fields anywhere -- Firestore Security
  /// Rules reject direct client writes to them (see Phase 10 of the
  /// migration guide), so this call is required, not optional, for
  /// onboarding to actually persist a user's health data.
  Future<bool> _pushHealthDataToWorker({
    required List<String> conditions,
    required List<String> allergens,
  }) async {
    try {
      final idToken = await _firebaseAuth.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('_pushHealthDataToWorker failed: no authenticated user / no ID token');
        return false;
      }
      final res = await http.post(
        Uri.parse('$_workerUrl/health-profile'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'conditions': conditions,
          'allergens': allergens,
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('_pushHealthDataToWorker failed: ${res.statusCode} ${res.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('_pushHealthDataToWorker error: $e');
      return false;
    }
  }

  Future<void> saveOnboardingData({
    required String name,
    // age/dateOfBirth are no longer collected during onboarding. Left as
    // optional (rather than removed outright) so this method still works
    // if a caller elsewhere in the app (e.g. a future profile/edit screen)
    // wants to backfill them -- onboarding itself never passes these now.
    String? age,
    DateTime? dateOfBirth,
    required List<String> conditions,
    required List<String> allergens,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      debugPrint('saveOnboardingData failed: no authenticated user');
      throw Exception('No authenticated user found');
    }

    try {
      final userDoc = await _firebaseDb.collection('users').doc(uid).get();

      // conditions/allergens are NOT included in this write. Firestore
      // Security Rules now reject direct client writes to those two
      // fields entirely (they qualify as "sensitive personal
      // information" under RA 10173 Sec. 3(l)) -- they're sent to the
      // Cloudflare Worker separately below, which encrypts them
      // server-side before persisting. Every other field here (name,
      // dateOfBirth, onboardingComplete) is unaffected and stays
      // plaintext, written directly as before.
      final data = <String, dynamic>{
        'uid': uid,
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
      if (age != null && (!userDoc.exists || docData == null || !docData.containsKey('age'))) {
        data['age'] = age;
      }
      // Store dateOfBirth as Firestore Timestamp if provided
      if (dateOfBirth != null) {
        if (!userDoc.exists || docData == null || !docData.containsKey('dateOfBirth')) {
          data['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
        }
      }

      await _firebaseDb.collection('users').doc(uid).set(data, SetOptions(merge: true));
      debugPrint('Onboarding data (plain fields) saved successfully for UID: $uid');

      // Now send conditions/allergens to the Worker for server-side
      // encryption. This must succeed for onboarding to be considered
      // complete from a data standpoint -- if it fails, the user's
      // Firestore doc exists but has no encrypted health data yet, so
      // this throws rather than silently continuing, letting the
      // caller's error handling / retry UI take over.
      final healthDataSaved = await _pushHealthDataToWorker(
        conditions: conditions,
        allergens: allergens,
      );
      if (!healthDataSaved) {
        throw Exception(
          'Failed to save health conditions and allergens. Please check your connection and try again.',
        );
      }
      debugPrint('Onboarding health data (encrypted) saved successfully for UID: $uid');

      // Update the global name notifier so other screens can display the new name
      userNameNotifier.value = name;
    } on FirebaseException catch (e) {
      debugPrint('Firestore write failed during onboarding for UID $uid: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during onboarding data save: $e');
      rethrow;
    }
  }

  Future<bool> hasCompletedOnboarding() async {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) return false;

      final userDoc = await _firebaseDb.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        debugPrint('hasCompletedOnboarding: user document does not exist for UID: $uid');
        return false;
      }

      final data = userDoc.data();
      // 'conditions'/'allergens' no longer live on this Firestore doc as
      // plaintext-checkable keys the way they used to -- they're still
      // present as encrypted strings, so containsKey(...) still works
      // the same as before; this check doesn't need to change.
      final isComplete = data != null &&
          data.containsKey('name') &&
          data['name'] != null &&
          data['name'].toString().isNotEmpty &&
          data.containsKey('conditions') &&
          data.containsKey('allergens');
      
      debugPrint('hasCompletedOnboarding for UID $uid: $isComplete');
      return isComplete;
    } on FirebaseException catch (e) {
      debugPrint('Firestore error in hasCompletedOnboarding: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected error in hasCompletedOnboarding: $e');
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
    HomeTabController.switchToTab(0);
    // Reset personalized feedback on logout
    HapticService().updateEnabled(false);

    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid != null) {
        // Clear session ID in Firestore to prevent race conditions on next login
        try {
          await _firebaseDb.collection('users').doc(uid).update({'currentSessionId': null});
        } on FirebaseException catch (e) {
          debugPrint('Error clearing session ID on sign out for UID $uid: ${e.code} - ${e.message}');
          // Continue with sign out even if Firestore update fails
        }
      }
    } catch (e) {
      debugPrint('Error during sign out cleanup: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionId');
    await _firebaseGoogleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  /// Deletes the signed-in user's Firestore doc and Firebase Auth account.
  ///
  /// If [credential] is null, this is a first attempt: it deletes the
  /// Firestore doc, then tries to delete the Auth user with whatever
  /// session is currently active.
  ///
  /// If Firebase Auth reports `requires-recent-login`, the user is left
  /// signed in on purpose (see [DeleteAccountResult.reauthRequired]) --
  /// the caller should obtain fresh credentials (via
  /// [buildGoogleReauthCredential] or [buildEmailReauthCredential]) and
  /// call this again passing them as [credential]. That retry re-runs the
  /// Firestore delete too, but deleting an already-deleted doc is a
  /// harmless no-op, not an error, so it's safe to just replay the whole
  /// method rather than needing a separate "resume" code path.
  ///
  /// This never signs the user out on failure. The previous version did,
  /// which meant the only way to "retry" was logging back in through the
  /// normal login() flow -- and login()'s own session-tracking logic
  /// would silently recreate a bare-bones Firestore doc for the uid,
  /// undoing the deletion that had already happened and dropping the
  /// user into onboarding instead of actually finishing the deletion.
  Future<DeleteAccountResult> deleteAccount({AuthCredential? credential}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return DeleteAccountResult.error('No authenticated user found.');
    }

    final uid = user.uid;

    try {
      if (credential != null) {
        try {
          await user.reauthenticateWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          debugPrint('Reauthentication error: ${e.code} - ${e.message}');
          return DeleteAccountResult.error(
            e.message ?? 'Re-authentication failed. Please try again.',
          );
        }
      }

      // Delete the Firestore user document FIRST, while the user is still
      // authenticated.
      //
      // This used to run the other way around (Auth account deleted,
      // then Firestore document deleted). But deleting the Firebase Auth
      // user signs them out immediately and invalidates their ID token,
      // so the Firestore delete that followed was running as an
      // unauthenticated request. Firestore's security rules for the
      // `users` collection require the requester to be the owner
      // (request.auth.uid == uid), so that delete would fail with
      // permission-denied -- leaving an orphaned `users/{uid}` document
      // behind even though the Auth account was already gone. Deleting
      // Firestore first, based on the authenticated user's own uid,
      // avoids that: if it fails, nothing has been deleted yet and we
      // can report the failure honestly instead of silently leaving a
      // stray document.
      try {
        await _firebaseDb.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint('Firestore user document deletion error: $e');
        return DeleteAccountResult.error(
          'Failed to delete your account data. Please try again.',
        );
      }

      // Now delete the Firebase Authentication account.
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase Auth deletion error: $e');
        if (e.code == 'requires-recent-login') {
          // Deliberately NOT signing out here -- the caller prompts for
          // fresh credentials and calls deleteAccount() again with them.
          // The Firestore doc is already gone at this point; the retry
          // will just find nothing left to delete there and go straight
          // to removing the Auth user.
          return DeleteAccountResult.reauthRequired(
            user.providerData.map((p) => p.providerId).toList(),
          );
        }
        rethrow;
      }

      // Clear local session data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sessionId');

      // Reset personalized feedback
      HapticService().updateEnabled(false);

      return DeleteAccountResult.success();
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth deletion error: $e');
      return DeleteAccountResult.error(
        e.message ?? 'Failed to delete account. Please try again.',
      );
    } catch (e) {
      debugPrint('Account deletion error: $e');
      return DeleteAccountResult.error(
        'An error occurred while deleting your account. Please try again.',
      );
    }
  }

  /// Builds a fresh Google credential for re-authentication (e.g. to
  /// recover from `requires-recent-login` during account deletion) by
  /// re-triggering the Google account picker. Returns null if the user
  /// cancels the picker.
  ///
  /// This does NOT sign the credential into Firebase itself -- the
  /// caller (deleteAccount) is expected to pass it to
  /// `user.reauthenticateWithCredential`, which re-verifies the *current*
  /// user's identity rather than switching to a different account.
  Future<AuthCredential?> buildGoogleReauthCredential() async {
    try {
      final GoogleSignInAccount? googleUser = await _firebaseGoogleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      return GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    } catch (e) {
      debugPrint('Error building Google reauth credential: $e');
      return null;
    }
  }

  /// Builds an email/password credential for re-authentication, using the
  /// currently signed-in user's own email address (so this can't be used
  /// to authenticate as anyone else) and the password the caller collected.
  /// Returns null if there's no signed-in user or no email on the account
  /// (e.g. a Google-only account).
  AuthCredential? buildEmailReauthCredential(String password) {
    final email = _firebaseAuth.currentUser?.email;
    if (email == null || email.isEmpty) return null;
    return EmailAuthProvider.credential(email: email, password: password);
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
  ///
  /// NOTE: do NOT pass 'conditions' or 'allergens' in [data] -- Firestore
  /// Security Rules reject direct client writes to those two fields (see
  /// Phase 10 of the migration guide). Use AuthService's Worker-backed
  /// path (or PersonalInfoScreen's _pushHealthData) for those instead.
  ///
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