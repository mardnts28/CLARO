import 'package:flutter_test/flutter_test.dart';
import 'package:claro/data/models/health_profile.dart';

void main() {
  group('UserHealthProfile Model Tests', () {
    test('profileFingerprint is deterministic and changes when condition changes', () {
      final p1 = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: const [HealthCondition.hypertension, HealthCondition.diabetes],
        allergies: const [AllergenType.fish],
      );

      final p2 = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: const [HealthCondition.diabetes, HealthCondition.hypertension], // reversed order
        allergies: const [AllergenType.fish],
      );

      // Condition order should not change fingerprint because it sorts internally
      expect(p1.profileFingerprint, equals(p2.profileFingerprint));

      final p3 = UserHealthProfile(
        userId: 'user_123',
        displayName: 'Juan',
        conditions: const [HealthCondition.hypertension], // diabetes removed
        allergies: const [AllergenType.fish],
      );
      expect(p1.profileFingerprint, isNot(equals(p3.profileFingerprint)));
    });

    test('toJson and fromJson round-trips correctly', () {
      final profile = UserHealthProfile(
        userId: 'user_999',
        displayName: 'Maria Clara',
        conditions: const [
          HealthCondition.gerd,
          HealthCondition.kidneyDisease,
        ],
        allergies: const [
          AllergenType.shellfish,
          AllergenType.dairy,
        ],
        voiceAssistant: true,
      );

      final json = profile.toJson();
      final reconstructed = UserHealthProfile.fromJson(json);

      expect(reconstructed.userId, 'user_999');
      expect(reconstructed.displayName, 'Maria Clara');
      expect(reconstructed.hasGerd, isTrue);
      expect(reconstructed.hasKidneyDisease, isTrue);
      expect(reconstructed.hasHypertension, isFalse);
      expect(reconstructed.allergies, containsAll([AllergenType.shellfish, AllergenType.dairy]));
      expect(reconstructed.voiceAssistant, isTrue);
    });

    test('AllergenTypeDisplay produces expected display labels', () {
      expect(AllergenType.shellfish.displayLabel, 'Shellfish');
      expect(AllergenType.fish.displayLabel, 'Fish');
      expect(AllergenType.peanuts.displayLabel, 'Peanuts');
      expect(AllergenType.wheatGluten.displayLabel, 'Wheat/Gluten');
      expect(AllergenType.msg.displayLabel, 'MSG');
    });
  });
}
