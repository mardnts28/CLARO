import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/health_advisory.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserHealthProfile Fingerprint Tests', () {
    test('Identical health profiles produce identical fingerprints regardless of order', () {
      final profile1 = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: [HealthCondition.cardiovascularDisease, HealthCondition.diabetes],
        allergies: [AllergenType.peanuts, AllergenType.shellfish],
      );

      final profile2 = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: [HealthCondition.diabetes, HealthCondition.cardiovascularDisease],
        allergies: [AllergenType.shellfish, AllergenType.peanuts],
      );

      expect(profile1.profileFingerprint, equals(profile2.profileFingerprint));
    });

    test('Updating condition or allergy changes the fingerprint (invalidates cache)', () {
      final baseProfile = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: [HealthCondition.cardiovascularDisease],
        allergies: [AllergenType.peanuts],
      );

      final updatedProfile = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: [HealthCondition.cardiovascularDisease, HealthCondition.diabetes],
        allergies: [AllergenType.peanuts],
      );

      expect(baseProfile.profileFingerprint, isNot(equals(updatedProfile.profileFingerprint)));
    });
  });

  group('HealthAdvisory Serialization & Persistence Tests', () {
    test('HealthAdvisory correctly serializes to JSON and deserializes back', () {
      final now = DateTime.now();
      final advisory = HealthAdvisory(
        overallLevel: AdvisoryLevel.caution,
        warningText: 'High Sodium Warning',
        explanation: 'This product exceeds daily sodium limit for hypertensive users.',
        safeServingSize: 'Half can (100g)',
        comparisonExplanation: 'Better than alternative X.',
        source: AdvisorySource.aiGenerated,
        generatedAt: now,
      );

      final json = advisory.toJson();
      final reconstructed = HealthAdvisory.fromJson(json);

      expect(reconstructed.overallLevel, equals(advisory.overallLevel));
      expect(reconstructed.warningText, equals(advisory.warningText));
      expect(reconstructed.explanation, equals(advisory.explanation));
      expect(reconstructed.safeServingSize, equals(advisory.safeServingSize));
      expect(reconstructed.comparisonExplanation, equals(advisory.comparisonExplanation));
      expect(reconstructed.source, equals(advisory.source));
      expect(reconstructed.isFallback, isFalse);
    });
  });
}
