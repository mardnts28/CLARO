// lib/data/services/product_extraction_service.dart
//
// Gemini's 3rd role in this system (alongside GeminiAdvisoryService's
// health-advisory generation and ranking-explanation generation): reading a
// product's front + back label photos directly (multimodal -- no separate
// OCR engine) and returning structured product data.
//
// This service is deliberately narrow -- image(s) in, ProductExtractionResult
// out. It does NOT touch Firestore, does NOT know about the `reports`
// collection or the admin approval flow. Callers decide what to do with the
// result:
//   - screens/unknown_product_submission_screen.dart (Phase 3) attaches it
//     to a user's report for admin review
//   - tools/bulk-import (Phase 2b, Node.js) re-implements this same
//     prompt/schema for offline batch population -- see that folder's
//     README for why this isn't literal shared code across Dart/Node.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/constants/canonical_allergens.dart';
import '../models/product_extraction_result.dart';

class ProductExtractionService {
  ProductExtractionService({
    required String apiKey,
    String model = 'gemini-3.5-flash',
  }) : _model = GenerativeModel(
          model: model,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            // Low temperature -- this call wants faithful transcription of
            // what's on the label, not creative variation. Contrast with
            // GeminiAdvisoryService's 0.4, which is generating explanatory
            // text rather than extracting fixed facts.
            temperature: 0.1,
            // 8192 allows long ingredient lists and full nutrition objects
            // without risk of truncation while only charging for actual tokens.
            maxOutputTokens: 8192,
          ),
        );

  final GenerativeModel _model;
  static const _timeout = Duration(seconds: 45);

  /// Reads [frontImageBytes] + [backImageBytes] (JPEG/PNG bytes -- the
  /// caller handles picking/compressing the photos) and returns structured
  /// product data. Never throws: on timeout, API error, or a response that
  /// doesn't parse, returns ProductExtractionResult.empty(reason: ...) so a
  /// failed extraction shows up as "needs manual entry" in the admin review
  /// UI rather than crashing the submission flow.
  Future<ProductExtractionResult> extract({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    List<Uint8List> additionalBackImageBytes = const [],
    String frontMimeType = 'image/jpeg',
    String backMimeType = 'image/jpeg',
  }) async {
    try {
      final parts = <Part>[
        TextPart(_buildPrompt()),
      ];
      if (frontImageBytes.isNotEmpty) {
        parts.add(DataPart(frontMimeType, frontImageBytes));
      }
      if (backImageBytes.isNotEmpty) {
        parts.add(DataPart(backMimeType, backImageBytes));
      }
      for (final extraBytes in additionalBackImageBytes) {
        if (extraBytes.isNotEmpty) {
          parts.add(DataPart(backMimeType, extraBytes));
        }
      }

      final response = await _model.generateContent([
        Content.multi(parts),
      ]).timeout(_timeout);

      return _parseResponse(response.text);
    } on TimeoutException catch (e) {
      print('GEMINI EXTRACTION TIMEOUT: $e');
      return ProductExtractionResult.empty(
        reason: 'Extraction timed out -- please review manually.',
      );
    } catch (e, stack) {
      print('GEMINI EXTRACTION ERROR: $e');
      print('STACK: $stack');
      return ProductExtractionResult.empty(
        reason: 'Extraction failed -- please review manually.',
      );
    }
  }

  String _buildPrompt() {
    final allergenList = CanonicalAllergens.values.join(', ');
    return '''
You are reading two photos of a packaged food product sold in the
Philippines: the FRONT of the package (first image) and the BACK/nutrition
label (second image). Extract the following as strict JSON -- no markdown
fences, no commentary, just the JSON object.

Return exactly this shape:
{
  "brand": "",
  "product_name": "",
  "size": "",
  "serving_size": "",
  "ingredients": [],
  "nutrition_per_100g": {
    "energy_kcal": null,
    "protein_g": null,
    "carbs_g": null,
    "fat_total_g": null,
    "fat_saturated_g": null,
    "fat_trans_g": null,
    "sodium_mg": null,
    "potassium_mg": null,
    "calcium_mg": null,
    "iron_mg": null,
    "fiber_g": null,
    "sugars_g": null,
    "added_sugars_g": null
  },
  "allergens": [],
  "confidence_notes": ""
}

Rules:
- "ingredients": split the ingredients list into individual items, in the
  order printed on the package. Keep each item as printed (don't translate).
- "nutrition_per_100g": read values as printed. If the label states values
  per serving rather than per 100g, convert using the stated serving size.
  If a field is genuinely not visible/printed, use null -- do NOT guess or
  estimate a plausible-looking number.
- "allergens": only choose from this fixed list based on TWO sources only:
  1) The actual ingredients list, and 2) "May contain" or "May contain traces of" 
  statements. DO NOT include allergens from facility warnings like 
  "manufactured in a facility that stores and uses" or similar cross-contamination 
  warnings. Only report allergens that are actual ingredients or explicitly stated 
  as possible traces: [$allergenList]. If the label mentions an allergen-relevant
  ingredient not on this list, note it in "confidence_notes" instead of
  inventing a new category.
- "confidence_notes": briefly flag anything unclear, blurry, or ambiguous in
  either photo that a human reviewer should double-check against the actual
  package. Leave empty if nothing stood out. IMPORTANT: Return simple, concise
  notes using bullet points. Maximum 1 sentence per bullet point. Keep each
  note under 15 words. Use everyday language.
- If the back label is missing, blurry, or unreadable, still fill in what
  the front photo gives you (brand, product_name, size), leave nutrition/
  ingredients/allergens empty, and say so in "confidence_notes".
''';
  }

  ProductExtractionResult _parseResponse(String? text) {
    if (text == null || text.trim().isEmpty) {
      print('EMPTY RESPONSE from Gemini extraction');
      return ProductExtractionResult.empty(
        reason: 'No response from extraction -- please review manually.',
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
      final nutritionJson =
          json['nutrition_per_100g'] as Map<String, dynamic>? ?? {};

      double num_(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0.0;
      }

      bool sawAnyNutritionValue = nutritionJson.values.any((v) => v != null);

      final ingredients = (json['ingredients'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final allergens = (json['allergens'] as List? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return ProductExtractionResult(
        brand: (json['brand'] as String? ?? '').trim(),
        productName: (json['product_name'] as String? ?? '').trim(),
        size: (json['size'] as String? ?? '').trim(),
        servingSize: (json['serving_size'] as String? ?? '').trim(),
        ingredients: ingredients,
        allergens: allergens,
        nutrition: ExtractedNutrition(
          caloriesKcal: num_(nutritionJson['energy_kcal']),
          proteinG: num_(nutritionJson['protein_g']),
          carbsG: num_(nutritionJson['carbs_g']),
          totalFatG: num_(nutritionJson['fat_total_g']),
          saturatedFatG: num_(nutritionJson['fat_saturated_g']),
          transFatG: num_(nutritionJson['fat_trans_g']),
          sodiumMg: num_(nutritionJson['sodium_mg']),
          potassiumMg: num_(nutritionJson['potassium_mg']),
          calciumMg: num_(nutritionJson['calcium_mg']),
          ironMg: num_(nutritionJson['iron_mg']),
          fiberG: num_(nutritionJson['fiber_g']),
          sugarsG: num_(nutritionJson['sugars_g']),
          addedSugarsG: num_(nutritionJson['added_sugars_g']),
        ),
        hasNutritionData: sawAnyNutritionValue,
        confidenceNotes: (json['confidence_notes'] as String? ?? '').trim(),
      );
    } catch (e) {
      print('EXTRACTION PARSE ERROR: $e');
      print('RAW RESPONSE: $text');
      return ProductExtractionResult.empty(
        reason: 'Could not parse extraction result -- please review manually.',
      );
    }
  }
}