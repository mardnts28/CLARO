// lib/data/services/gemini_advisory_service.dart
//
// Calls Gemini through the claro-gemini-proxy Cloudflare Worker instead of
// calling Google's API directly. The real Gemini API key lives only as a
// Cloudflare Worker secret -- it never ships inside the APK. The app
// authenticates to the Worker with APP_SHARED_SECRET (see backend_locator.dart
// and claro-gemini-proxy/src/index.ts).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_advisory.dart';
import '../models/health_profile.dart';
import '../models/product_evaluation.dart';
import '../models/ranked_product_result.dart';
import '../../core/constants/who_fda_thresholds.dart';
import '../../core/utils/advisory_prompt_builder.dart';
import '../../core/utils/comparison_calculator.dart';
import '../../core/utils/fallback_advisory_generator.dart';

class GeminiAdvisoryService {
  GeminiAdvisoryService({
    required String proxyUrl,
    required String appSecret,
    String model = 'gemini-3.5-flash',
  })  : _proxyUrl = proxyUrl,
        _appSecret = appSecret,
        _model = model;

  final String _proxyUrl;
  final String _appSecret;
  final String _model;
  static const _timeout = Duration(seconds: 10);

  final Map<String, HealthAdvisory> _cache = {};

  /// Posts [prompt] to the Cloudflare Worker and returns Gemini's raw text
  /// response (same shape the old GenerativeModel.generateContent().text
  /// used to give us), so the rest of this file's parsing logic is
  /// unchanged.
  Future<String?> _callGemini(
    String prompt, {
    required Duration timeout,
  }) async {
    final response = await http
        .post(
          Uri.parse(_proxyUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-App-Secret': _appSecret,
          },
          body: jsonEncode({
            'model': _model,
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.4,
              'maxOutputTokens': 2048,
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini proxy returned ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;

    return parts.first['text'] as String?;
  }

  String _persistentCacheKey({
    required String fingerprint,
    required String productId,
    required String languageCode,
    required bool isComparison,
  }) =>
      'advisory_cache_${fingerprint}_${productId}_${languageCode}${isComparison ? '_cmp' : ''}';

  Future<HealthAdvisory> generateAdvisory({
    required String scanEventId,
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
    ComparisonFact? comparisonFact,
    SuitabilityRankLabel? rankLabel,
    String languageCode = 'en',
  }) async {
    final isComparison = comparisonFact != null;
    final pKey = _persistentCacheKey(
      fingerprint: user.profileFingerprint,
      productId: evaluation.product.id,
      languageCode: languageCode,
      isComparison: isComparison,
    );

    // 1. Check in-memory RAM cache for instantaneous response
    final cachedInMemory = _cache[pKey];
    if (cachedInMemory != null) return cachedInMemory;

    // 2. Check persistent disk cache (survives app restarts and rescans across weeks)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJsonStr = prefs.getString(pKey);
      if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
        final decoded = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
        final advisory = HealthAdvisory.fromJson(decoded);
        _cache[pKey] = advisory;
        return advisory;
      }
    } catch (e) {
      // Non-fatal: continue to generate or fallback if cache read fails
      print('Persistent advisory cache read warning: $e');
    }

    // Skip the API entirely when nothing is flagged and this isn't a
    // comparison call -- the fallback template covers "suitable" just as
    // well, at zero token cost.
    if (evaluation.overallLevel == AdvisoryLevel.suitable &&
        !evaluation.allergenAssessment.hasDirectAllergen &&
        !isComparison) {
      // Use combined nutrient calculation for users without health conditions
      final useCombinedNutrients = user.conditions.isEmpty;
      final hasNoConditionsAndNoAllergens = user.conditions.isEmpty;
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: languageCode,
        useCombinedNutrients: useCombinedNutrients,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
      );
      _cache[pKey] = advisory;
      _persistAdvisory(pKey, advisory);
      return advisory;
    }

    final prompt = AdvisoryPromptBuilder.build(
      evaluation: evaluation,
      user: user,
      comparisonFact: comparisonFact,
      rankLabel: rankLabel,
      languageCode: languageCode,
    );

    HealthAdvisory advisory;
    // Use combined nutrient calculation for users without health conditions
    final useCombinedNutrients = user.conditions.isEmpty;
    final hasNoConditionsAndNoAllergens = user.conditions.isEmpty && !evaluation.allergenAssessment.hasDirectAllergen;
    try {
      final text = await _callGemini(prompt, timeout: _timeout);

      advisory = _parseResponse(text, evaluation, languageCode, useCombinedNutrients, hasNoConditionsAndNoAllergens);
    } on TimeoutException catch (e) {
      print('GEMINI TIMEOUT: $e');
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.timeout,
        languageCode: languageCode,
        useCombinedNutrients: useCombinedNutrients,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
      );
    } catch (e, stack) {
      print('GEMINI ERROR: $e');
      print('STACK: $stack');
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.apiError,
        languageCode: languageCode,
        useCombinedNutrients: useCombinedNutrients,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
      );
    }

    _cache[pKey] = advisory;
    _persistAdvisory(pKey, advisory);
    return advisory;
  }

  void _persistAdvisory(String key, HealthAdvisory advisory) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(key, jsonEncode(advisory.toJson()));
    }).catchError((e) {
      print('Failed to persist advisory to cache: $e');
    });
  }

  HealthAdvisory _parseResponse(String? text, ProductEvaluation evaluation, String languageCode, bool useCombinedNutrients, bool hasNoConditionsAndNoAllergens) {
    if (text == null || text.trim().isEmpty) {
      print('EMPTY RESPONSE from Gemini');
      return FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.emptyResponse,
        languageCode: languageCode,
        useCombinedNutrients: useCombinedNutrients,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
      );
    }
    try {
      String cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final warningText = json['warningText'] as String?;
      final explanation = json['explanation'] as String?;
      final safeServingSize = json['safeServingSize'] as String?;
      final comparisonExplanation = json['comparisonExplanation'] as String?;

      if (warningText == null || explanation == null) {
        throw const FormatException('Missing required fields');
      }

      return HealthAdvisory(
        overallLevel: evaluation.overallLevel,
        warningText: warningText,
        explanation: explanation,
        safeServingSize: safeServingSize,
        comparisonExplanation: comparisonExplanation,
        source: AdvisorySource.aiGenerated,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      print('PARSE ERROR: $e');
      print('RAW RESPONSE: $text');
      return FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.parseError,
        languageCode: languageCode,
        useCombinedNutrients: useCombinedNutrients,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
      );
    }
  }

  void clearScanEvent(String scanEventId) {
    _cache.removeWhere((k, _) => k.startsWith('$scanEventId::'));
  }

  /// Generates the per-nutrient ranking explanation shown on the
  /// comparison card. [healthCondition] is the user's condition name
  /// (e.g. "hypertension", or a comma-joined list for multiple
  /// conditions) so the explanation can tie the nutrient back to *why*
  /// it matters for this user, not just report the raw numbers.
  Future<Map<String, String>> generateRankingExplanation({
    required String nutrientName,
    required String nutrientUnit,
    required double thisValue,
    required double bestValue,
    required double worstValue,
    required int rank,
    required int totalProducts,
    String healthCondition = '',
    String languageCode = 'en',
  }) async {
    final prompt = AdvisoryPromptBuilder.buildRankingExplanation(
      nutrientName: nutrientName,
      nutrientUnit: nutrientUnit,
      thisValue: thisValue,
      bestValue: bestValue,
      worstValue: worstValue,
      rank: rank,
      totalProducts: totalProducts,
      healthCondition: healthCondition,
      languageCode: languageCode,
    );

    try {
      final text = await _callGemini(prompt, timeout: _timeout);

      final explanation = _parseRankingExplanation(text);
      return {'explanation': explanation, 'source': 'Gemini'};
    } on TimeoutException catch (_) {
      final explanation = FallbackAdvisoryGenerator.generateRankingExplanation(
        nutrientName: nutrientName,
        nutrientUnit: nutrientUnit,
        thisValue: thisValue,
        bestValue: bestValue,
        worstValue: worstValue,
        rank: rank,
        totalProducts: totalProducts,
        healthCondition: healthCondition,
        languageCode: languageCode,
      );
      return {'explanation': explanation, 'source': 'Fallback'};
    } catch (_) {
      final explanation = FallbackAdvisoryGenerator.generateRankingExplanation(
        nutrientName: nutrientName,
        nutrientUnit: nutrientUnit,
        thisValue: thisValue,
        bestValue: bestValue,
        worstValue: worstValue,
        rank: rank,
        totalProducts: totalProducts,
        healthCondition: healthCondition,
        languageCode: languageCode,
      );
      return {'explanation': explanation, 'source': 'Fallback'};
    }
  }

  String _parseRankingExplanation(String? text) {
    if (text == null || text.trim().isEmpty) {
      print('EMPTY RESPONSE from Gemini for ranking explanation');
      throw const FormatException('Empty response');
    }
    try {
      String cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final explanation = json['explanation'] as String?;

      if (explanation == null) {
        throw const FormatException('Missing explanation field');
      }

      return explanation;
    } catch (e) {
      print('PARSE ERROR for ranking explanation: $e');
      print('RAW RESPONSE: $text');
      rethrow;
    }
  }
}