// lib/data/services/gemini_advisory_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/health_advisory.dart';
import '../models/health_profile.dart';
import '../models/product_evaluation.dart';
import '../../core/utils/advisory_prompt_builder.dart';
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
  static const _timeout = Duration(seconds: 10); // TEMP: widened from 3s while debugging

  final Map<String, HealthAdvisory> _cache = {};

  String _cacheKey(String scanEventId, String productId) =>
      '$scanEventId::$productId';

  Future<HealthAdvisory> generateAdvisory({
    required String scanEventId,
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
    String languageCode = 'en',
  }) async {
    final key = _cacheKey(scanEventId, evaluation.product.id);
    final cached = _cache[key];
    if (cached != null) return cached;

    final prompt = AdvisoryPromptBuilder.build(
      evaluation: evaluation,
      user: user,
      languageCode: languageCode,
    );

    HealthAdvisory advisory;
    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(_timeout);

      advisory = _parseResponse(response.text, evaluation);
    } on TimeoutException catch (e) {
      print('GEMINI TIMEOUT: $e'); // TEMP DEBUG — remove after fixing
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.timeout,
      );
    } catch (e, stack) {
      print('GEMINI ERROR: $e'); // TEMP DEBUG — remove after fixing
      print('STACK: $stack'); // TEMP DEBUG — remove after fixing
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
      print('EMPTY RESPONSE from Gemini'); // TEMP DEBUG — remove after fixing
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

      if (warningText == null || explanation == null) {
        throw const FormatException('Missing required fields');
      }

      return HealthAdvisory(
        overallLevel: evaluation.overallLevel,
        warningText: warningText,
        explanation: explanation,
        safeServingSize: safeServingSize,
        source: AdvisorySource.aiGenerated,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      print('PARSE ERROR: $e'); // TEMP DEBUG — remove after fixing
      print('RAW RESPONSE: $text'); // TEMP DEBUG — remove after fixing
      return FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.parseError,
      );
    }
  }

  void clearScanEvent(String scanEventId) {
    _cache.removeWhere((k, _) => k.startsWith('$scanEventId::'));
  }
}