// test/gemini_advisory_service_test.dart
//
// Manual integration check -- makes a REAL call to Gemini and consumes
// real tokens. Run on demand only, not part of routine `flutter test` runs.
//
// Run with:
// flutter test test/gemini_advisory_service_test.dart --dart-define=GEMINI_API_KEY=your_key_here

import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/repositories/product_repository.dart';
import 'package:claro/data/repositories/user_repository.dart';

void main() {
  test('generateAdvisory returns a real AI advisory for a mock product/user', () async {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    expect(apiKey.isNotEmpty, true);

    final productRepo = MockProductRepository();
    final userRepo = MockUserRepository();

    final product = await productRepo.getProductById('p006');
final user = await userRepo.getHealthProfile('u004');
    final evaluation = WhoCalculator.evaluateProduct(product, user);

    final geminiService = GeminiAdvisoryService(apiKey: apiKey);
    final advisory = await geminiService.generateAdvisory(
      scanEventId: 'manual-test-1',
      evaluation: evaluation,
      user: user,
    );

    print('Warning: ${advisory.warningText}');
    print('Explanation: ${advisory.explanation}');
    print('Safe serving: ${advisory.safeServingSize}');
    print('Source: ${advisory.source}');
    print('Is fallback: ${advisory.isFallback}');

    expect(advisory.warningText, isNotEmpty);
    expect(advisory.explanation, isNotEmpty);
  });
}