import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/data/models/health_advisory.dart';

void main() {
  group('HealthAdvisory Model Tests', () {
    test('isFallback evaluates correctly based on source', () {
      final aiAdvisory = HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: 'Suitable for you',
        explanation: 'Low in sodium',
        safeServingSize: '1 full can (155g)',
        source: AdvisorySource.aiGenerated,
        generatedAt: DateTime.now(),
      );
      expect(aiAdvisory.isFallback, isFalse);

      final fallbackAdvisory = HealthAdvisory(
        overallLevel: AdvisoryLevel.caution,
        warningText: 'Caution',
        explanation: 'High in sodium',
        safeServingSize: 'Up to 50g',
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
      expect(fallbackAdvisory.isFallback, isTrue);
    });

    test('toJson and fromJson round-trips correctly', () {
      final now = DateTime(2026, 10, 22, 12, 0);
      final advisory = HealthAdvisory(
        overallLevel: AdvisoryLevel.moderate,
        warningText: 'Moderate Consumption',
        explanation: 'Contains moderate sugars',
        safeServingSize: '80g',
        comparisonExplanation: 'Ranks 2 of 3 products compared',
        source: AdvisorySource.aiGenerated,
        generatedAt: now,
      );

      final json = advisory.toJson();
      final reconstructed = HealthAdvisory.fromJson(json);

      expect(reconstructed.overallLevel, AdvisoryLevel.moderate);
      expect(reconstructed.warningText, 'Moderate Consumption');
      expect(reconstructed.explanation, 'Contains moderate sugars');
      expect(reconstructed.safeServingSize, '80g');
      expect(reconstructed.comparisonExplanation, 'Ranks 2 of 3 products compared');
      expect(reconstructed.source, AdvisorySource.aiGenerated);
      expect(reconstructed.generatedAt.toIso8601String(), now.toIso8601String());
    });
  });
}
