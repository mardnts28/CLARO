// lib/core/utils/health_data_crypto.dart
//
// Field-level AES-256-GCM encryption for the two Firestore fields that
// qualify as "sensitive personal information" under RA 10173 (Data
// Privacy Act of 2012, Sec. 3(l)): the user's health conditions and
// allergens on users/{uid}. All other profile fields (name, dateOfBirth,
// email, etc.) are ordinary personal information and are NOT touched by
// this file -- see the Chapter 4 security discussion for the scoping
// rationale.
//
// THREAT MODEL / DISCLOSED LIMITATION:
// The AES key is derived deterministically from the signed-in user's
// Firebase Auth UID plus an app-embedded pepper (_appPepper below). This
// means:
//   - Firestore data is protected against exposure via a data breach,
//     an overly permissive security rule, or someone with only Firestore
//     console/export access (the realistic threat this feature targets).
//   - It does NOT protect against an attacker who has reverse-engineered
//     the compiled app binary and extracted _appPepper, since the key
//     material never leaves the client. This is a client-only,
//     capstone-scope implementation; a production system would instead
//     mint/hold the key server-side (e.g. via a Cloud Function + KMS) so
//     it never touches the client at all. This tradeoff is intentional
//     and should be stated explicitly as a scope limitation in Chapter 5.
//
// No key is ever written to Firestore, SharedPreferences, or anywhere
// else -- it is re-derived on demand from the live Firebase Auth session.
//
// Dependencies to add to pubspec.yaml:
//   encrypt: ^5.0.3
//   crypto: ^3.0.3

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class HealthDataCrypto {
  HealthDataCrypto._();

  // See THREAT MODEL note above. Replace this placeholder with a real,
  // randomly-generated value before shipping, and keep it identical
  // across app builds/versions -- changing it invalidates every
  // previously-encrypted conditions/allergens field for every user.
  static const String _appPepper =
      'be7f139a0165d695ed8f78dc6b4b4bd05f6de389143e309480ce614d946af12d';

  static const int _ivLengthBytes = 12; // 96-bit nonce, standard for GCM

  /// Derives a per-user 256-bit AES key from [uid] + the app pepper.
  /// Deterministic: the same user always gets the same key, so the key
  /// never needs to be stored anywhere -- it's re-derived on every
  /// encrypt/decrypt call from the live Firebase Auth session.
  static enc.Key _deriveKey(String uid) {
    final material = utf8.encode('$uid::$_appPepper');
    final digest = crypto.sha256.convert(material); // 32 bytes = 256 bits
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  static enc.Key _currentUserKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError(
          'HealthDataCrypto: cannot encrypt/decrypt with no authenticated user.');
    }
    return _deriveKey(uid);
  }

  /// Encrypts a list of selected condition/allergen labels (e.g.
  /// `['Diabetes', 'Alta-presyon']`) into a single opaque, base64 string
  /// safe to store in a Firestore string field.
  ///
  /// Returns an empty string for an empty list, so "user selected
  /// nothing" is stored as `''` rather than a misleading non-empty blob.
  /// Callers should write this return value in place of the old
  /// `List<String>` for the `conditions`/`allergens` fields.
  static String encryptField(List<String> values) {
    if (values.isEmpty) return '';

    final key = _currentUserKey();
    final iv = enc.IV.fromSecureRandom(_ivLengthBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    final plaintext = jsonEncode(values);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // Store IV + ciphertext(+tag) together, base64-encoded, so decryption
    // only needs the single stored string -- no separate IV field.
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64.encode(combined);
  }

  /// Reverses [encryptField]. Returns `[]` for a null/empty stored value
  /// (matches "no conditions/allergens selected").
  ///
  /// Handles both encrypted Base64 String payloads and unencrypted legacy List<dynamic>
  /// arrays gracefully, ensuring backward compatibility without runtime type-cast crashes.
  static List<String> decryptField(dynamic stored) {
    if (stored == null) return [];
    if (stored is List) {
      return stored.map((e) => e.toString()).toList();
    }
    if (stored is! String || stored.isEmpty) return [];

    try {
      final key = _currentUserKey();
      final combined = base64.decode(stored);

      if (combined.length <= _ivLengthBytes) {
        throw const FormatException('Encrypted payload too short.');
      }

      final ivBytes = combined.sublist(0, _ivLengthBytes);
      final cipherBytes = combined.sublist(_ivLengthBytes);

      final iv = enc.IV(Uint8List.fromList(ivBytes));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final decrypted = encrypter.decrypt(
        enc.Encrypted(Uint8List.fromList(cipherBytes)),
        iv: iv,
      );

      final decoded = jsonDecode(decrypted) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('HealthDataCrypto.decryptField failed, returning []: $e');
      return [];
    }
  }
}