import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  static encrypt.Key _deriveKey(String uid) {
    final bytes = utf8.encode(uid);
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  // Consistent 16-byte IV for deterministic encryption/decryption of simple fields
  static final _iv = encrypt.IV.fromLength(16);

  /// Encrypts plain text using a key derived from the user's UID.
  static String encryptText(String text, String uid) {
    if (text.isEmpty) return '';
    try {
      final key = _deriveKey(uid);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(text, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return text;
    }
  }

  /// Decrypts encrypted base64 text using a key derived from the user's UID.
  static String decryptText(String encryptedBase64, String uid) {
    if (encryptedBase64.isEmpty) return '';
    try {
      final key = _deriveKey(uid);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      return encrypter.decrypt64(encryptedBase64, iv: _iv);
    } catch (e) {
      return encryptedBase64; // Fallback if data is not encrypted
    }
  }
}
