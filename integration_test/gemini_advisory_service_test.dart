// integration_test/gemini_advisory_service_test.dart
//
// Manual integration check -- makes REAL calls to Firestore (for the user
// profile) and Gemini (for the advisory). Consumes real tokens and requires
// a live Firebase connection. Run on demand only, not part of routine
// `flutter test` runs.
//
// WHY THIS LIVES IN integration_test/, NOT test/:
// FirebaseUserRepository talks to Firestore over native platform channels
// (cloud_firestore), not plain HTTP. Plain `flutter test` runs in the Dart
// VM with no platform channels registered, so any real Firestore call
// throws MissingPluginException there -- it has nothing to do with whether
// your data or credentials are correct. GeminiAdvisoryService, by contrast,
// uses `google_generative_ai`, which is plain HTTP, so it works fine under
// `flutter test`. This file needs a connected device, emulator, or Chrome,
// because only those provide real platform channel implementations.
//
// Run with (device/emulator must be running):
// flutter test integration_test/gemini_advisory_service_test.dart \
//   --dart-define-from-file=.env
//
// Or on Chrome:
// flutter test integration_test/gemini_advisory_service_test.dart \
//   -d chrome --dart-define-from-file=.env

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:claro/firebase_options.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/repositories/product_repository.dart';
import 'package:claro/data/repositories/user_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  test(
    'generateAdvisory returns a real AI advisory for a mock product + a '
    'REAL Firestore user profile',
    () async {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      expect(apiKey.isNotEmpty, true);

      // Product data: still mock, per plan -- FirebaseProductRepository
      // doesn't exist yet (Phase 6 TODO in product_repository.dart).
      final productRepo = MockProductRepository();

      // User data: now real Firestore, via the same repository main.dart
      // already wires up in production.
      final userRepo = FirebaseUserRepository();

      // TODO: replace with a real Firebase Auth uid (28-char doc ID) that
      // actually exists in your groupmate's `users` collection. Mock IDs
      // like 'u004' won't be found in Firestore -- those only exist in
      // mock_users.dart.
      const testUserId = 'sSQDzjkeqTWkcoLttexPTW1nKdE3';

      final product = await productRepo.getProductById('p006');
      final user = await userRepo.getHealthProfile(testUserId);

      // If this line runs, the connection worked: displayName/conditions/
      // allergies below came from your live `users/{uid}` document, not
      // from mock_users.dart.
      debugPrint(
        'Loaded from Firestore -- displayName: ${user.displayName}, '
        'conditions: ${user.conditions}, allergies: ${user.allergies}, '
        'voiceAssistant: ${user.voiceAssistant}',
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      final geminiService = GeminiAdvisoryService(apiKey: apiKey);
      final advisory = await geminiService.generateAdvisory(
        scanEventId: 'manual-integration-test-1',
        evaluation: evaluation,
        user: user,
      );

      debugPrint('Warning: ${advisory.warningText}');
      debugPrint('Explanation: ${advisory.explanation}');
      debugPrint('Safe serving: ${advisory.safeServingSize}');
      debugPrint('Source: ${advisory.source}');
      debugPrint('Is fallback: ${advisory.isFallback}');

      expect(advisory.warningText, isNotEmpty);
      expect(advisory.explanation, isNotEmpty);
    },
  );
}