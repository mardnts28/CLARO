import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'voice_assistant_service.dart';
import 'scan_history_service.dart';
import '../data/services/backend_locator.dart';
import '../models/product_model.dart';

enum VoiceIntentType {
  navigate,
  summarizeScan,

  // A real, grounded answer to an in-scope question --
  // e.g. "why is this flagged?" while a product is open.
  answerQuestion,

  outOfScope,
  unclear,

  // Indicates that speech was successfully transcribed,
  // but the backend/AI could not process the request.
  processingError,
}

class VoiceIntent {
  final VoiceIntentType type;
  final String? targetPage;
  final String spokenReply;

  VoiceIntent({
    required this.type,
    this.targetPage,
    required this.spokenReply,
  });

  factory VoiceIntent.fromMap(
    Map<String, dynamic> map,
  ) {
    final typeString =
        (map['type'] as String?)?.toLowerCase();

    final type = switch (typeString) {
      'navigate' =>
        VoiceIntentType.navigate,

      'summarize_scan' =>
        VoiceIntentType.summarizeScan,

      'answer_question' =>
        VoiceIntentType.answerQuestion,

      'out_of_scope' =>
        VoiceIntentType.outOfScope,

      'unclear' =>
        VoiceIntentType.unclear,

      'processing_error' =>
        VoiceIntentType.processingError,

      _ =>
        VoiceIntentType.unclear,
    };

    return VoiceIntent(
      type: type,
      targetPage:
          map['target_page'] as String?,
      spokenReply:
          (map['spoken_reply'] as String?) ?? '',
    );
  }
}

class GeminiService {
  GeminiService._();

  static final GeminiService _instance =
      GeminiService._();

  static GeminiService get instance =>
      _instance;

  static const _unclearReplyEn =
      'I heard what you said, but I could not determine what action you want me to perform. Please try saying your command in a simpler way.';

  static const _unclearReplyFil =
      'Narinig ko ang sinabi mo, pero hindi ko matukoy kung anong aksyon ang gusto mong gawin. Pakisubukan gamit ang mas simpleng utos.';

  static const _processingErrorReplyEn =
      'I heard your command, but I could not process it right now. Please try again.';

  static const _processingErrorReplyFil =
      'Narinig ko ang iyong utos, pero hindi ko ito maiproseso ngayon. Pakisubukan muli.';

  static const _timeout = Duration(seconds: 10);

  // Every navigable target the app actually supports, kept in sync with
  // the branches handled in VoiceCommandRouter (_handleNavigationIntent
  // and _navigateToScreen). Gemini is only allowed to pick from this list
  // for `navigate` -- anything else is rejected rather than silently
  // failing later inside the app.
  static const Set<String> _validTargets = {
    'home', 'scan', 'history', 'profile',
    'clear_favorites', 'clear_history', 'compare_products', 'dark_mode',
    'delete_account', 'favorite_product', 'history_compare',
    'history_favorites', 'history_reports', 'language', 'language_english',
    'language_tagalog', 'light_mode', 'logout', 'mfa', 'mfa_off', 'mfa_on',
    'more_details', 'report_product', 'unfavorite_product',
    'voice_assistant_off', 'voice_assistant_on', 'about_claro',
    'change_password', 'personal_info', 'preference', 'privacy_policy',
    'review_history', 'suggestion', 'terms_conditions', 'theme',
    'user_guide',
  };

  /// Classifies a voice command, optionally grounded in [screenContext] --
  /// a short description of whatever is currently on screen (e.g. the
  /// product/advisory summary already shown on ProductDetailScreen). Pass
  /// null when there's nothing relevant on screen (home, history list,
  /// settings, etc.) rather than sending empty/misleading context.
  Future<VoiceIntent> classifyIntent({
    required String transcript,
    required VoiceLang language,
    String? screenContext,
  }) async {
    final langValue =
        language == VoiceLang.tagalog
            ? 'fil'
            : 'en';

    try {
      final contextBlock = (screenContext != null && screenContext.trim().isNotEmpty)
          ? '''

The user is currently looking at this screen. Use ONLY the facts below if you
need to answer a question about it -- never use outside knowledge, and never
invent or assume any health, safety, or nutrition fact that isn't stated here:
<screen_context>
${screenContext.trim()}
</screen_context>
'''
          : '''

There is no product or screen data currently available to the user. If their
question depends on seeing a specific product's data, use type "unclear" and
say you don't have that information yet -- do not guess.
''';

      final prompt = '''
Classify this voice command for the CLARO app (a food-label scanning and
health-advisory app).
Language: $langValue
Transcript: <transcript>$transcript</transcript>
$contextBlock
Return only valid JSON with exactly this shape:
{
  "type": "navigate" | "summarize_scan" | "answer_question" | "out_of_scope" | "unclear" | "processing_error",
  "target_page": string | null,
  "spoken_reply": string
}

Rules:
- Use "navigate" only if the user wants to go to a specific screen, and
  target_page must be EXACTLY one of: ${_validTargets.join(', ')}.
  Never invent a target_page value outside this list.
- Use "summarize_scan" if the user wants the current scan/product summarized.
- Use "answer_question" only if you can answer using solely the
  <screen_context> given above (if any). Put the full answer in spoken_reply.
  Never state a health/safety/nutrition fact that is not present in
  screen_context.
- Use "unclear" if the request depends on context you were not given, and
  say so in spoken_reply (e.g. "I don't have that information right now").
- Use "out_of_scope" if the request has nothing to do with this app.
- Use null for target_page unless type is navigate.
- Do not wrap the JSON in markdown.
''';

      final response = await http
          .post(
            Uri.parse(BackendLocator.geminiProxyUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Secret': BackendLocator.appSharedSecret,
            },
            body: jsonEncode({
              'model': BackendLocator.geminiModel,
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
                'temperature': 0.2,
                'maxOutputTokens': 256,
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Gemini proxy returned ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      final content = candidates?.firstOrNull as Map<String, dynamic>?;
      final parts = content?['content'] is Map<String, dynamic>
          ? (content!['content'] as Map<String, dynamic>)['parts'] as List?
          : null;
      final text = parts?.firstOrNull is Map<String, dynamic>
          ? (parts!.first as Map<String, dynamic>)['text'] as String?
          : null;

      if (text == null || text.trim().isEmpty) {
        throw const FormatException('Gemini returned no intent JSON');
      }

      final data = jsonDecode(text) as Map<String, dynamic>;
      final intent = _parseStrictIntent(data);

        // If the backend returned an unclear
        // intent without a useful response,
        // provide a better explanation.
        if (intent.type ==
                VoiceIntentType.unclear &&
            intent.spokenReply.trim().isEmpty) {
          return VoiceIntent(
            type: VoiceIntentType.unclear,
            targetPage:
                intent.targetPage,
            spokenReply:
                language ==
                        VoiceLang.tagalog
                    ? _unclearReplyFil
                    : _unclearReplyEn,
          );
        }

        // Safety net: never let an "answer_question" through without any
        // screen context to ground it in, and never with an empty answer.
        // Guessing at health/safety facts is worse than saying nothing.
        if (intent.type == VoiceIntentType.answerQuestion &&
            (screenContext == null ||
                screenContext.trim().isEmpty ||
                intent.spokenReply.trim().isEmpty)) {
          return VoiceIntent(
            type: VoiceIntentType.unclear,
            targetPage: null,
            spokenReply:
                language == VoiceLang.tagalog
                    ? _unclearReplyFil
                    : _unclearReplyEn,
          );
        }

        return intent;
    } catch (error, stackTrace) {
      debugPrint(
        'Voice intent proxy failed: $error',
      );
      debugPrint('$stackTrace');

      // IMPORTANT:
      // The speech recognition already produced
      // a transcript. Therefore we explicitly tell
      // the user that we HEARD the command but
      // could not process it.
      return VoiceIntent(
        type:
            VoiceIntentType.processingError,
        targetPage: null,
        spokenReply:
            language ==
                    VoiceLang.tagalog
                ? _processingErrorReplyFil
                : _processingErrorReplyEn,
      );
    }
  }

  static VoiceIntent _parseStrictIntent(Map<String, dynamic> data) {
    const allowedTypes = {
      'navigate',
      'summarize_scan',
      'answer_question',
      'out_of_scope',
      'unclear',
      'processing_error',
    };

    final type = data['type'];
    final targetPage = data['target_page'];
    final spokenReply = data['spoken_reply'];

    if (data.length != 3 ||
      !data.containsKey('type') ||
      !data.containsKey('target_page') ||
      !data.containsKey('spoken_reply') ||
      type is! String ||
        !allowedTypes.contains(type) ||
        (targetPage != null && targetPage is! String) ||
        spokenReply is! String) {
      throw const FormatException('Invalid voice intent schema');
    }

    // Reject hallucinated screens instead of letting navigation silently
    // fail later with "I couldn't find that page".
    if (type == 'navigate' &&
        (targetPage == null || !_validTargets.contains(targetPage))) {
      throw FormatException(
        'Gemini returned an unrecognized target_page: $targetPage',
      );
    }

    return VoiceIntent.fromMap(data);
  }

  Future<String> summarizeScan({
    required VoiceLang language,
  }) async {
    final activeSummary =
        VoiceAssistantService
            .latestScanSummaryNotifier
            .value;

    if (activeSummary != null &&
        activeSummary.trim().isNotEmpty) {
      return activeSummary;
    }

    final activeProduct =
        VoiceAssistantService
                .activeResultProductNotifier
                .value ??
            VoiceAssistantService
                .latestScanProductNotifier
                .value;

    if (activeProduct != null) {
      return _formatProductSummary(
        activeProduct,
        language,
      );
    }

    final localSummary =
        await _buildLocalReportSummary(
      language,
    );

    if (localSummary != null &&
        localSummary.isNotEmpty) {
      return localSummary;
    }

    final productSummary =
        await _buildLocalProductSummary(
      language,
    );

    if (productSummary != null &&
        productSummary.isNotEmpty) {
      return productSummary;
    }

    final recordSummary =
        await _buildLocalScanRecordSummary(
      language,
    );

    if (recordSummary != null &&
        recordSummary.isNotEmpty) {
      return recordSummary;
    }

    return _noScanSummary(language);
  }

  Future<String?> _buildLocalReportSummary(
    VoiceLang language,
  ) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) return null;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('reports')
              .where(
                'reportedBy',
                isEqualTo: user.uid,
              )
              .limit(10)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final documents = [
        ...snapshot.docs,
      ]..sort((left, right) {
          final leftDate =
              _reportDate(left.data());

          final rightDate =
              _reportDate(right.data());

          return rightDate.compareTo(
            leftDate,
          );
        });

      final data =
          documents.first.data();

      final productName =
          (data['productName'] as String?)
              ?.trim();

      final extracted =
          Map<String, dynamic>.from(
        data['extractedData']
                as Map? ??
            {},
      );

      final nutrition =
          Map<String, dynamic>.from(
        extracted['nutrition']
                as Map? ??
            {},
      );

      final brand = _displayValue(
        extracted['brand'] ??
            data['brand'],
        'unknown brand',
      );

      final size = _displayValue(
        extracted['size'] ??
            extracted['servingSize'],
        'unknown size',
      );

      final fdaStatus =
          _displayValue(
        extracted['fdaStatus'] ??
            data['fdaStatus'] ??
            data['status'],
        'unknown',
      );

      final advisory =
          _displayValue(
        extracted['healthAdvisory'] ??
            extracted['advisory'] ??
            data['healthAdvisory'],
        'not available',
      );

      final nutritionScores =
          _nutritionSummary(
        nutrition,
        extracted,
      );

      if (language ==
          VoiceLang.tagalog) {
        return 'Brand $brand, laki $size, FDA status $fdaStatus. Health advisory: $advisory. Nutritional scores: $nutritionScores.';
      }

      return 'Product ${productName?.isEmpty ?? true ? 'unknown' : productName}, brand $brand, size $size, FDA status $fdaStatus. Health advisory: $advisory. Nutritional scores: $nutritionScores.';
    } catch (error, stackTrace) {
      debugPrint(
        'Local scan summary failed: $error',
      );
      debugPrint('$stackTrace');

      return null;
    }
  }

  Future<String?> _buildLocalProductSummary(
    VoiceLang language,
  ) async {
    try {
      final currentProduct =
          VoiceAssistantService
                  .activeResultProductNotifier
                  .value ??
              VoiceAssistantService
                  .latestScanProductNotifier
                  .value;

      if (currentProduct != null) {
        return _formatProductSummary(
          currentProduct,
          language,
        );
      }

      final historyService =
          ScanHistoryService();

      final products =
          historyService.localHistory.isNotEmpty
              ? historyService.localHistory
              : await historyService
                  .getScanHistory();

      if (products.isEmpty) return null;

      return _formatProductSummary(
        products.first,
        language,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Local product summary failed: $error',
      );
      debugPrint('$stackTrace');

      return null;
    }
  }

  String _formatProductSummary(
    Product product,
    VoiceLang language,
  ) {
    final facts =
        product.nutritionalFacts;

    final size = _displayValue(
      facts.servingSize.isNotEmpty
          ? facts.servingSize
          : product.servingInstructions,
      language ==
              VoiceLang.tagalog
          ? 'hindi tinukoy'
          : 'unknown size',
    );

    final nutrition =
        facts.hasNutritionData
            ? language ==
                    VoiceLang.tagalog
                ? '${facts.caloriesKcal} calories, ${facts.proteinG}g protein, ${facts.carbsG}g carbs, ${facts.totalFatG}g taba, ${facts.sugarsG}g asukal, ${facts.sodiumMg}mg sodium'
                : '${facts.caloriesKcal} calories, ${facts.proteinG}g protein, ${facts.carbsG}g carbs, ${facts.totalFatG}g fat, ${facts.sugarsG}g sugars, ${facts.sodiumMg}mg sodium'
            : language ==
                    VoiceLang.tagalog
                ? 'hindi available'
                : 'not available';

    if (language ==
        VoiceLang.tagalog) {
      return 'Produkto: ${_displayValue(product.name, 'Hindi alam')}, brand: ${_displayValue(product.brand, 'Hindi alam')}, laki: $size, FDA status: ${product.fdaStatus}. Mga sustansya: $nutrition.';
    }

    return 'Product: ${_displayValue(product.name, 'Unknown')}, brand: ${_displayValue(product.brand, 'Unknown')}, size: $size, FDA status: ${product.fdaStatus}. Nutrition: $nutrition.';
  }

  Future<String?> _buildLocalScanRecordSummary(
    VoiceLang language,
  ) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('scan_history')
              .orderBy(
                'timestamp',
                descending: true,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data =
          snapshot.docs.first.data();

      final productName =
          _displayValue(
        data['product_name'],
        'unknown product',
      );

      final brand =
          _displayValue(
        data['brand'],
        'unknown brand',
      );

      if (language ==
          VoiceLang.tagalog) {
        return 'Ang pinakabagong scan ay $productName, brand $brand. FDA status, health advisory, at nutritional scores ay hindi available.';
      }

      return 'Your latest scan is $productName, brand $brand. FDA status, health advisory, and nutritional scores are not available.';
    } catch (error, stackTrace) {
      debugPrint(
        'Scan history record summary failed: $error',
      );
      debugPrint('$stackTrace');

      return null;
    }
  }

  String _noScanSummary(
    VoiceLang language,
  ) {
    return language ==
            VoiceLang.tagalog
        ? 'Wala akong nakitang kamakailang scan na maibubuod.'
        : 'I could not find a recent scan to summarize.';
  }

  DateTime _reportDate(
    Map<String, dynamic> data,
  ) {
    final value =
        data['dateSubmitted'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      0,
    );
  }

  String _displayValue(
    dynamic value,
    String fallback,
  ) {
    final text =
        value?.toString().trim() ?? '';

    return text.isEmpty
        ? fallback
        : text;
  }

  String _nutritionSummary(
    Map<String, dynamic> nutrition,
    Map<String, dynamic> extracted,
  ) {
    final scores =
        extracted['nutritionalScores'] ??
            extracted['nutritionScores'];

    if (scores is Map) {
      return scores.entries
          .map(
            (entry) =>
                '${entry.key} ${entry.value}',
          )
          .join(', ');
    }

    final fields =
        <String, String>{
      'calories': 'calories_kcal',
      'protein': 'protein_g',
      'carbs': 'carbs_g',
      'fat': 'fat_total_g',
      'sugars': 'sugars_g',
      'sodium': 'sodium_mg',
    };

    final available =
        fields.entries
            .where(
              (entry) =>
                  nutrition[
                    entry.value] !=
                  null,
            )
            .map(
              (entry) =>
                  '${entry.key} ${nutrition[entry.value]}',
            )
            .join(', ');

    return available.isEmpty
        ? 'not available'
        : available;
  }
}
