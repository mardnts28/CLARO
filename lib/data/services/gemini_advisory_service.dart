// lib/data/services/gemini_advisory_service.dart
//
// Calls Gemini through the claro-gemini-proxy Cloudflare Worker instead of
// calling Google's API directly. The real Gemini API key lives only as a
// Cloudflare Worker secret -- it never ships inside the APK. The app
// authenticates to the Worker with APP_SHARED_SECRET (see backend_locator.dart
// and claro-gemini-proxy/src/index.ts).

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show debugPrint;
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
import '../../core/utils/gerd_trigger_detector.dart';
import '../../core/utils/group_advisory_builder.dart';
import '../../core/utils/kidney_advisory_facts.dart';

class GeminiAdvisoryService {
  GeminiAdvisoryService({
    required this._proxyUrl,
    required this._appSecret,
    this._model = 'gemini-3.5-flash',
  });

  final String _proxyUrl;
  final String _appSecret;
  final String _model;
  static const _timeout = Duration(seconds: 30);

  final Map<String, HealthAdvisory> _cache = {};

  /// Logs to both developer.log (DevTools) and debugPrint (the normal
  /// `flutter run` console / adb logcat). dev.log alone does not appear in
  /// logcat, which hid every Gemini error before.
  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(
      message,
      name: 'GeminiAdvisory',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('GeminiAdvisory: $message${error != null ? ' | $error' : ''}');
  }

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
              // Thinking-capable models count thinking tokens against this
              // limit; 4096 could truncate the JSON mid-string and cause a
              // parse error.
              'maxOutputTokens': 8192,
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
      // Kidney Disease advisories were rewritten (sodium + protein WHO %s and
      // phosphate additives, replacing the old Kidney Disease Warning card),
      // so their cache keys carry a '_kd2' suffix. The trailing '_v5' marks
      // the latest GERD/Diabetes advisory structure and serving rules,
      // so stale text and amounts aren't reused.
      'advisory_cache_${fingerprint}_${productId}_$languageCode${isComparison ? '_cmp' : ''}${fingerprint.contains(HealthCondition.kidneyDisease.name) ? '_kd2' : ''}_v6';

  HealthAdvisory _withoutExcludedServing(
    HealthAdvisory advisory,
    ProductEvaluation evaluation,
    UserHealthProfile user,
  ) {
    if (!user.conditions.contains(HealthCondition.gerd) &&
        !evaluation.allergenAssessment.hasDirectAllergen) {
      return advisory;
    }

    return HealthAdvisory(
      overallLevel: advisory.overallLevel,
      warningText: advisory.warningText,
      explanation: advisory.explanation,
      safeServingSize: null,
      comparisonExplanation: advisory.comparisonExplanation,
      source: advisory.source,
      generatedAt: advisory.generatedAt,
    );
  }

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

    // Comparison advisories embed text that depends on WHICH products were
    // compared (rank wording, best/worst values), but the key above does not
    // include that. They are therefore never cached, so a later comparison
    // cannot be served an earlier comparison's text.
    if (!isComparison) {
      // 1. Check in-memory RAM cache for instantaneous response
      final cachedInMemory = _cache[pKey];
      if (cachedInMemory != null) {
        return _withoutExcludedServing(cachedInMemory, evaluation, user);
      }

      // 2. Check persistent disk cache (survives app restarts and rescans)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJsonStr = prefs.getString(pKey);
        if (cachedJsonStr != null && cachedJsonStr.isNotEmpty) {
          final decoded = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
          final advisory = _withoutExcludedServing(
            HealthAdvisory.fromJson(decoded),
            evaluation,
            user,
          );
          _cache[pKey] = advisory;
          return advisory;
        }
      } catch (e) {
        // Non-fatal: continue to generate or fallback if cache read fails
        _log('Persistent advisory cache read warning', error: e);
      }
    }

    // Skip the API entirely when nothing is flagged and this isn't a
    // comparison call -- the fallback template covers "suitable" just as
    // well, at zero token cost. This is intentional, not an error.
    if (evaluation.overallLevel == AdvisoryLevel.suitable &&
        !evaluation.allergenAssessment.hasDirectAllergen &&
        !isComparison) {
      _log(
        'Skipping Gemini (suitable, no allergen, not a comparison): '
        'overallLevel=${evaluation.overallLevel}',
      );
      final hasNoConditionsAndNoAllergens =
          user.conditions.isEmpty &&
          !evaluation.allergenAssessment.hasDirectAllergen;
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: languageCode,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
        userConditions: user.conditions,
      );
      final normalized = _withoutExcludedServing(advisory, evaluation, user);
      _cache[pKey] = normalized;
      _persistAdvisory(pKey, normalized);
      return normalized;
    }

    _log(
      'Calling Gemini: overallLevel=${evaluation.overallLevel}, '
      'hasAllergen=${evaluation.allergenAssessment.hasDirectAllergen}, '
      'isComparison=$isComparison, userConditions=${user.conditions.length}',
    );
    final prompt = AdvisoryPromptBuilder.build(
      evaluation: evaluation,
      user: user,
      comparisonFact: comparisonFact,
      rankLabel: rankLabel,
      languageCode: languageCode,
    );

    HealthAdvisory advisory;
    final hasNoConditionsAndNoAllergens =
        user.conditions.isEmpty &&
        !evaluation.allergenAssessment.hasDirectAllergen;
    // The suggested amount comes from the app, never from Gemini's reply.
    final suggestedServing = AdvisoryPromptBuilder.suggestedServing(
      evaluation: evaluation,
      user: user,
    );
    try {
      final text = await _callGemini(prompt, timeout: _timeout);

      advisory = _parseResponse(
        text,
        evaluation,
        languageCode,
        hasNoConditionsAndNoAllergens,
        suggestedServing,
        user.conditions,
      );
    } on TimeoutException catch (e) {
      _log('GEMINI TIMEOUT', error: e);
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.timeout,
        languageCode: languageCode,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
        userConditions: user.conditions,
      );
    } catch (e, stack) {
      _log('GEMINI ERROR', error: e, stackTrace: stack);
      advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.apiError,
        languageCode: languageCode,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
        userConditions: user.conditions,
      );
    }

    advisory = _withoutExcludedServing(advisory, evaluation, user);

    // Only cache real AI text. A fallback caused by a timeout, API error or
    // parse error must not stick (in memory OR on disk) just because Gemini
    // was briefly unreachable or returned something unusable -- the next
    // scan should try Gemini again. Comparison advisories are never cached
    // (see above).
    if (!advisory.isFallback && !isComparison) {
      _cache[pKey] = advisory;
      _persistAdvisory(pKey, advisory);
    }
    return advisory;
  }

  /// ONE Gemini call that writes the group verdict shown on the product
  /// detail banner when the user's health group has other members.
  ///
  /// [facts] come from GroupAdvisoryBuilder.buildFacts(). Member names are
  /// never sent -- Gemini only sees [M1]-style tags that are swapped back
  /// locally. Never throws: on timeout/API/parse errors, or when nothing
  /// needs explaining (everyone suitable), it returns the deterministic
  /// GroupAdvisoryBuilder.fallback() text instead, same as the single-user
  /// flow does.
  Future<HealthAdvisory> generateGroupAdvisory({
    required String productId,
    required String productName,
    required double servingSizeG,
    required List<GroupMemberFacts> facts,
    String languageCode = 'en',
  }) async {
    final key =
        // '_v4' marks the latest suggested-serving rules, so previously
        // cached group amounts aren't reused.
        'group_advisory_${GroupAdvisoryBuilder.fingerprint(productId, servingSizeG, facts)}_${languageCode}_v4';

    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final advisory = HealthAdvisory.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _cache[key] = advisory;
        return advisory;
      }
    } catch (e) {
      _log('Group advisory cache read warning', error: e);
    }

    final level = GroupAdvisoryBuilder.groupLevel(facts.map((f) => f.level));
    final needsAi =
        level != AdvisoryLevel.suitable ||
        facts.any((f) => f.allergens.isNotEmpty);

    HealthAdvisory advisory;
    // True only when the deterministic text was chosen on purpose (nobody
    // flagged), as opposed to after a Gemini failure.
    var fallbackIsIntentional = false;
    if (!needsAi) {
      fallbackIsIntentional = true;
      advisory = GroupAdvisoryBuilder.fallback(
        facts,
        servingSizeG: servingSizeG,
        languageCode: languageCode,
      );
    } else {
      try {
        final text = await _callGemini(
          GroupAdvisoryBuilder.buildPrompt(
            productName: productName,
            servingSizeG: servingSizeG,
            facts: facts,
            languageCode: languageCode,
          ),
          timeout: _timeout,
        );
        final parsed = _parseGroupResponse(
          text,
          facts,
          level,
          servingSizeG,
          languageCode,
        );
        if (parsed == null) {
          _log('Group advisory: Gemini reply rejected, using fallback');
        }
        advisory =
            parsed ??
            GroupAdvisoryBuilder.fallback(
              facts,
              servingSizeG: servingSizeG,
              languageCode: languageCode,
            );
      } catch (e, stack) {
        _log('GEMINI GROUP ADVISORY ERROR', error: e, stackTrace: stack);
        advisory = GroupAdvisoryBuilder.fallback(
          facts,
          servingSizeG: servingSizeG,
          languageCode: languageCode,
        );
      }
    }

    // Cache AI text, and the deliberate "nobody flagged" template. Do NOT
    // cache a fallback produced by a Gemini failure -- retry next time.
    if (!advisory.isFallback || fallbackIsIntentional) {
      _cache[key] = advisory;
      _persistAdvisory(key, advisory);
    }
    return advisory;
  }

  HealthAdvisory? _parseGroupResponse(
    String? text,
    List<GroupMemberFacts> facts,
    AdvisoryLevel level,
    double servingSizeG,
    String languageCode,
  ) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }

      final json = jsonDecode(cleaned.trim()) as Map<String, dynamic>;
      final warning = json['warningText'] as String?;
      final explanation = json['explanation'] as String?;
      if (warning == null || explanation == null) return null;

      // Same backstop as the single-product advisory: risky medical wording
      // means we use the deterministic group fallback text instead. Skipped
      // when any member is flagged for an allergen, where cautious warning
      // wording is acceptable.
      if (!facts.any((f) => f.allergens.isNotEmpty) &&
          (_containsProhibitedAdvisoryMedicalClaim(warning) ||
              _containsProhibitedAdvisoryMedicalClaim(explanation))) {
        _log('GROUP PARSE ERROR: advisory contains prohibited medical wording');
        return null;
      }

      final w = GroupAdvisoryBuilder.restoreNames(warning, facts, languageCode);
      final e = GroupAdvisoryBuilder.restoreNames(
        explanation,
        facts,
        languageCode,
      );
      if (w == null || e == null) return null;

      // The suggested amount is calculated by the app, never by Gemini. It
      // was supplied to the prompt to be copied verbatim; if the reply lost
      // or altered the figure, append the exact sentence so what's shown
      // always matches the app's number.
      final amount = GroupAdvisoryBuilder.groupAmount(
        facts,
        servingSizeG,
        tl: languageCode == 'tl',
      );
      var explanationText = e;
      if (amount != null && !explanationText.contains(amount.token)) {
        explanationText = '${explanationText.trim()} ${amount.sentence}';
      }

      return HealthAdvisory(
        overallLevel: level,
        warningText: w,
        explanation: explanationText,
        safeServingSize: amount?.sentence,
        source: AdvisorySource.aiGenerated,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      _log('GROUP PARSE ERROR', error: e);
      return null;
    }
  }

  void _persistAdvisory(String key, HealthAdvisory advisory) {
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setString(key, jsonEncode(advisory.toJson()));
        })
        .catchError((e) {
          _log('Failed to persist advisory to cache', error: e);
        });
  }

  HealthAdvisory _parseResponse(
    String? text,
    ProductEvaluation evaluation,
    String languageCode,
    bool hasNoConditionsAndNoAllergens,
    String? suggestedServing,
    Iterable<HealthCondition> userConditions,
  ) {
    if (text == null || text.trim().isEmpty) {
      _log('EMPTY RESPONSE from Gemini');
      return FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.emptyResponse,
        languageCode: languageCode,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
        userConditions: userConditions,
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
      final comparisonExplanation = json['comparisonExplanation'] as String?;

      if (warningText == null || explanation == null) {
        throw const FormatException('Missing required fields');
      }

      // Backstop for the prompt's "no medical claims" rule: a prompt can't
      // guarantee the model follows it, so reject risky wording and use the
      // rule-based fallback text instead. Allergen and GERD ingredient
      // warnings are exempt: cautious warning wording is acceptable there.
      final allowsWarningWording =
          evaluation.allergenAssessment.hasDirectAllergen ||
          evaluation.scoredFactors.any((f) => f.factorKey.startsWith('gerd'));
      if (!allowsWarningWording &&
          (_containsProhibitedAdvisoryMedicalClaim(warningText) ||
              _containsProhibitedAdvisoryMedicalClaim(explanation))) {
        throw const FormatException(
          'Advisory contains prohibited medical wording',
        );
      }

      // Kidney Disease advisories must state both supplied WHO percentages
      // (sodium and protein). If the model dropped or altered either one,
      // use the deterministic fallback text instead of showing a
      // half-correct advisory.
      final kidneyFacts = KidneyAdvisoryFacts.build(evaluation);
      if (kidneyFacts != null) {
        // The prompt supplies the DISPLAYED number (the percentage itself up
        // to 100, otherwise how far above 100 it is), so look for that.
        final sodiumToken =
            '${AdvisoryPromptBuilder.displayedPercentage(kidneyFacts.sodiumPercentage).toStringAsFixed(1)}%';
        final proteinToken =
            '${AdvisoryPromptBuilder.displayedPercentage(kidneyFacts.proteinPercentage).toStringAsFixed(1)}%';
        if (!explanation.contains(sodiumToken) ||
            !explanation.contains(proteinToken)) {
          throw const FormatException(
            'Kidney advisory is missing the supplied WHO percentages',
          );
        }
      }

      final conditions = userConditions.toList();
      if (conditions.length == 1 &&
          conditions.single == HealthCondition.gerd) {
        final detection = GerdTriggerDetector.detect(evaluation.product);
        final ingredientTriggers = detection.triggers
            .where((t) => t.type != GerdTriggerType.highFat)
            .map((t) => t.matchedIngredient)
            .whereType<String>()
            .toSet();
        final normalizedExplanation = explanation.toLowerCase();
        final fat = evaluation.scoredFactors.firstWhere(
          (f) => f.factorKey == 'gerdTotalFat',
        );
        final hasInsufficientInformation =
            normalizedExplanation.contains('not enough') ||
            normalizedExplanation.contains('insufficient') ||
            normalizedExplanation.contains('kulang') ||
            normalizedExplanation.contains('hindi sapat');
        final explainsTriggers = ingredientTriggers.isNotEmpty
            ? ingredientTriggers.every(
                (ingredient) => normalizedExplanation.contains(
                  ingredient.toLowerCase(),
                ),
              )
            : detection.hasIngredientData
            ? normalizedExplanation.contains('trigger') &&
                  (normalizedExplanation.contains('no ') ||
                      normalizedExplanation.contains('none') ||
                      normalizedExplanation.contains('walang'))
            : hasInsufficientInformation;
        final fatAmount = fat.valuePerServing?.toStringAsFixed(1);
        if (!normalizedExplanation.contains('total fat') &&
            !normalizedExplanation.contains('taba')) {
          throw const FormatException(
            'GERD advisory is missing the total-fat evaluation',
          );
        }
        if (fat.isUnknown
            ? !hasInsufficientInformation
            : (fatAmount == null || !explanation.contains('${fatAmount}g'))) {
          throw const FormatException(
            'GERD advisory is missing the evaluated total-fat amount',
          );
        }
        if (!explainsTriggers ||
            RegExp(r'[.!?](?=\s|$)').allMatches(explanation.trim()).length !=
                2) {
          throw const FormatException(
            'GERD advisory must reflect trigger detection in exactly two sentences',
          );
        }
      }

      if (conditions.length == 1 &&
          conditions.single == HealthCondition.diabetes) {
        final diabetesNutrients = evaluation.nutrientEvaluations
            .where((e) => e.condition == HealthCondition.diabetes);
        final sugars = diabetesNutrients.firstWhere(
          (e) => e.nutrientKey == 'sugarsG',
        );
        final carbohydrates = diabetesNutrients.firstWhere(
          (e) => e.nutrientKey == 'totalCarbohydratesG',
        );
        final sugarsPercentage =
            '${AdvisoryPromptBuilder.displayedPercentage(sugars.whoDailyLimitPercentage).toStringAsFixed(1)}%';
        final carbohydratesPercentage =
            '${AdvisoryPromptBuilder.displayedPercentage(carbohydrates.whoDailyLimitPercentage).toStringAsFixed(1)}%';
        final sentenceCount = RegExp(r'[.!?](?=\s|$)')
            .allMatches(explanation.trim())
            .length;
        final normalizedExplanation = explanation.toLowerCase();
        if (sentenceCount != 2 ||
            !normalizedExplanation.contains('total sugars') ||
            !normalizedExplanation.contains('total carbohydrates') ||
            !normalizedExplanation.contains('diabetes') ||
            !explanation.contains(sugarsPercentage) ||
            !explanation.contains(carbohydratesPercentage)) {
          throw const FormatException(
            'Diabetes advisory must identify both nutrients and their WHO percentages in exactly two sentences',
          );
        }
      }

      return HealthAdvisory(
        overallLevel: evaluation.overallLevel,
        warningText: warningText,
        explanation: explanation,
        safeServingSize: suggestedServing,
        comparisonExplanation: comparisonExplanation,
        source: AdvisorySource.aiGenerated,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      _log('PARSE ERROR – RAW RESPONSE: $text', error: e);
      return FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.parseError,
        languageCode: languageCode,
        hasNoConditionsAndNoAllergens: hasNoConditionsAndNoAllergens,
        userConditions: userConditions,
      );
    }
  }

  // Cache keys never start with '$scanEventId::', so this removes nothing.
  // Kept so existing callers still compile.
  void clearScanEvent(String scanEventId) {
    _cache.removeWhere((k, _) => k.startsWith('$scanEventId::'));
  }

  /// Clears all in-memory advisory cache. Called during logout to prevent
  /// user-specific advisories from persisting in memory.
  void clearAllCache() {
    _cache.clear();
  }

  /// Generates the per-nutrient ranking explanation shown on the
  /// comparison card. [healthCondition] is the user's condition name
  /// (e.g. "cardiovascular disease", or a comma-joined list for multiple
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
    required bool thisIsBestNutrient,
    String? supportingReason,
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
      thisIsBestNutrient: thisIsBestNutrient,
      supportingReason: supportingReason,
      healthCondition: healthCondition,
      languageCode: languageCode,
    );

    Map<String, String> fallback() => {
      'explanation': FallbackAdvisoryGenerator.generateRankingExplanation(
        nutrientName: nutrientName,
        nutrientUnit: nutrientUnit,
        thisValue: thisValue,
        bestValue: bestValue,
        worstValue: worstValue,
        rank: rank,
        totalProducts: totalProducts,
        thisIsBestNutrient: thisIsBestNutrient,
        supportingReason: supportingReason,
        healthCondition: healthCondition,
        languageCode: languageCode,
      ),
      'source': 'Fallback',
    };

    try {
      final text = await _callGemini(prompt, timeout: _timeout);

      final explanation = _parseRankingExplanation(text);
      if (_containsProhibitedRankingMedicalClaim(explanation)) {
        throw const FormatException(
          'Ranking explanation contains prohibited medical wording',
        );
      }
      return {'explanation': explanation, 'source': 'Gemini'};
    } on TimeoutException catch (e) {
      _log('GEMINI RANKING TIMEOUT', error: e);
      return fallback();
    } catch (e) {
      _log('GEMINI RANKING ERROR', error: e);
      return fallback();
    }
  }

  String _parseRankingExplanation(String? text) {
    if (text == null || text.trim().isEmpty) {
      _log('EMPTY RESPONSE from Gemini for ranking explanation');
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
      _log(
        'PARSE ERROR for ranking explanation – RAW RESPONSE: $text',
        error: e,
      );
      rethrow;
    }
  }

  /// Same idea as the ranking check below, minus "trigger". Callers skip this
  /// check for allergen and GERD ingredient warnings, where cautious warning
  /// wording is acceptable. English wording only; Tagalog output is not
  /// covered by this check.
  bool _containsProhibitedAdvisoryMedicalClaim(String text) {
    return RegExp(
      r'\b(?:dangerous|harmful|unsafe|toxic|contraindicated|worsen(?:s|ed|ing)?|aggravat(?:e|es|ed|ing)?|cause(?:s|d)?)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  bool _containsProhibitedRankingMedicalClaim(String explanation) {
    return RegExp(
      r'\b(?:dangerous|harmful|unsafe|toxic|contraindicated|worsen(?:s|ed|ing)?|aggravat(?:e|es|ed|ing)?|cause(?:s|d)?|trigger(?:s|ed|ing)?)\b',
      caseSensitive: false,
    ).hasMatch(explanation);
  }
}
