import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/services/auth_service.dart';

void main() {
  group('AuthService.getFriendlyAuthErrorMessage Tests', () {
    test('maps invalid-credential and wrong-password to friendly error', () {
      final exc1 = FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The supplied auth credential is incorrect, malformed or expired.',
      );
      expect(
        AuthService.getFriendlyAuthErrorMessage(exc1),
        'Incorrect email or password. Please try again.',
      );

      final exc2 = FirebaseAuthException(
        code: 'wrong-password',
        message: 'The password is invalid or the user does not have a password.',
      );
      expect(
        AuthService.getFriendlyAuthErrorMessage(exc2),
        'Incorrect email or password. Please try again.',
      );
    });

    test('maps user-not-found to friendly error', () {
      final exc = FirebaseAuthException(
        code: 'user-not-found',
        message: 'There is no user record corresponding to this identifier.',
      );
      expect(
        AuthService.getFriendlyAuthErrorMessage(exc),
        'No account found with this email address.',
      );
    });

    test('maps network-request-failed to friendly error', () {
      final exc = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'A network error (such as timeout, interrupted connection or unreachable host) has occurred.',
      );
      expect(
        AuthService.getFriendlyAuthErrorMessage(exc),
        'No internet connection. Please check your network and try again.',
      );
    });

    test('maps too-many-requests to friendly error', () {
      final exc = FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Access to this account has been temporarily disabled due to many failed login attempts.',
      );
      expect(
        AuthService.getFriendlyAuthErrorMessage(exc),
        'Too many failed login attempts. Please try again later or reset your password.',
      );
    });

    test('maps raw credential messages in unknown codes', () {
      final exc = FirebaseAuthException(
        code: 'unknown',
        message: 'The supplied auth credential is incorrect, malformed or expired.',
      );
      expect(
        AuthService.getFriendlyAuthErrorMessage(exc),
        'Incorrect email or password. Please try again.',
      );
    });
  });
}
