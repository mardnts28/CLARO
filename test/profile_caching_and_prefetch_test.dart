import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/repositories/user_repository.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/services/product_ranking_service.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserRepository Caching & Invalidation Tests', () {
    test('MockUserRepository caches profile in memory on first read', () async {
      final repo = MockUserRepository();
      final profile1 = await repo.getHealthProfile('u001');
      expect(profile1.userId, equals('u001'));

      // Subsequent call should retrieve from cache without error
      final profile2 = await repo.getHealthProfile('u001');
      expect(identical(profile1, profile2), isTrue);
    });

    test('MockUserRepository cache invalidation removes cached item', () async {
      final repo = MockUserRepository();
      final profile1 = await repo.getHealthProfile('u001');
      expect(profile1.userId, equals('u001'));

      repo.invalidateCache('u001');
      final profile2 = await repo.getHealthProfile('u001');
      // After invalidation, a fresh object is returned
      expect(identical(profile1, profile2), isFalse);
    });

    test('UserHealthProfile SharedPreferences persistence roundtrip', () async {
      final profile = const UserHealthProfile(
        userId: 'test_uid_999',
        displayName: 'Maria Santos',
        conditions: [HealthCondition.hypertension],
        allergies: [AllergenType.dairy, AllergenType.peanuts],
        voiceAssistant: true,
      );

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'user_health_profile_cache_${profile.userId}';
      await prefs.setString(cacheKey, jsonEncode(profile.toJson()));

      final storedJson = prefs.getString(cacheKey);
      expect(storedJson, isNotNull);

      final decoded = jsonDecode(storedJson!) as Map<String, dynamic>;
      final restored = UserHealthProfile.fromJson(decoded);

      expect(restored.userId, equals('test_uid_999'));
      expect(restored.displayName, equals('Maria Santos'));
      expect(restored.conditions, contains(HealthCondition.hypertension));
      expect(restored.allergies, contains(AllergenType.dairy));
      expect(restored.voiceAssistant, isTrue);
    });
  });

  group('ProductRankingService Advisory Prefetch Tests', () {
    test('prefetchAdvisory executes and warms local cache for suitable products', () async {
      final geminiService = GeminiAdvisoryService(apiKey: 'dummy_key');
      final rankingService = ProductRankingService(geminiService: geminiService);

      final product = Product(
        id: 'century_tuna_1',
        name: 'Century Tuna Flakes in Oil',
        brand: 'Century',
        category: 'Canned Seafood',
        ingredients: ['Tuna', 'Water', 'Vegetable Oil', 'Salt'],
        allergens: ['Fish'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '56g',
          caloriesKcal: 100,
          sodiumMg: 180,
          totalFatG: 6.0,
          saturatedFatG: 1.0,
          transFatG: 0.0,
          sugarsG: 0.0,
          carbsG: 0.0,
          proteinG: 12.0,
        ),
      );

      final user = const UserHealthProfile(
        userId: 'user_norm',
        displayName: 'Normal User',
        conditions: [],
        allergies: [],
      );

      // Trigger prefetch
      await rankingService.prefetchAdvisory(
        product: product,
        user: user,
      );

      // Now request advisory via getProductDetail -- should complete instantly
      final ranked = rankingService.rankProducts(products: [product], user: user);
      final detail = await rankingService.getProductDetail(
        target: ranked.first,
        user: user,
        scanEventId: 'test_scan',
      );

      expect(detail.advisory, isNotNull);
      expect(detail.advisory.overallLevel, equals(AdvisoryLevel.suitable));
    });
  });
}
