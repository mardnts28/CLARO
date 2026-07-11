// lib/data/services/gemini_advisory_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/health_advisory.dart';
import '../models/health_profile.dart';
import '../models/product_evaluation.dart';
import '../models/ranked_product_result.dart';
import '../../core/constants/who_fda_thresholds.dart';
import '../../core/utils/advisory_prompt_builder.dart';
import '../../core/utils/comparison_calculator.dart';
import '../../core/utils/fallback_advisory_generator.dart';

class GeminiAdvisoryService {
  GeminiAdvisoryService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.4,
            maxOutputTokens: 2048,
          ),
        );

  final GenerativeModel _model;
  static const _timeout = Duration(seconds: 10);

  final Map<String, HealthAdvisory> _cache = {};

  String _cacheKey(String scanEventId, String productId, bool isComparison) =>
      '$scanEventId::$productId${isComparison ? '::cmp' : ''}';

  Future<HealthAdvisory> generateAdvisory({
    required String scanEventId,
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
    ComparisonFact? comparisonFact,
    SuitabilityRankLabel? rankLabel,
    String languageCode = 'en',
  }) async {
    final isComparison = comparisonFact != null;
    final key = _cacheKey(scanEventId, evaluation.product.id, isComparison);
    final cached = _cache[key];
    if (cached != null) return cached;

    // Skip the API entirely when nothing is flagged and this isn't a
    // comparison call -- the fallback template covers "suitable" just as
    // well, at zero token cost.
    if (evaluation.overallLevel == AdvisoryLevel.suitable &&
        !evaluation.allergenAssessment.hasDirectAllergen &&
        !isComparison) {
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
      );
      _cache[key] = advisory;
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
    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(_timeout);

      advisory = _parseResponse(response.text, evaluation);
    } on TimeoutException catch (e) {
      print('GEMINI TIMEOUT: $e');
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.timeout,
      );
    } catch (e, stack) {
      print('GEMINI ERROR: $e');
      print('STACK: $stack');
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.apiError,
      );
    }

    _cache[key] = advisory;
    return advisory;
  }

  HealthAdvisory _parseResponse(String? text, ProductEvaluation evaluation) {
    if (text == null || text.trim().isEmpty) {
      print('EMPTY RESPONSE from Gemini');
      return FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.emptyResponse,
      );
    }
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
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
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(_timeout);

      final explanation = _parseRankingExplanation(response.text);
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
      final json = jsonDecode(text) as Map<String, dynamic>;
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