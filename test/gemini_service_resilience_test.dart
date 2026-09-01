import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:claro/data/services/product_extraction_service.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';

void main() {
  group('Gemini JSON parsing resilience tests', () {
    test('ProductExtractionService handles markdown fenced JSON', () {
      final service = ProductExtractionService(apiKey: 'dummy_key');

      // Markdown-wrapped JSON typical of Gemini 3.5/3.7 responses
      const rawMarkdownResponse = '''
```json
{
  "brand": "Century",
  "product_name": "Tuna Flakes in Oil",
  "size": "180g",
  "serving_size": "56g",
  "ingredients": ["Tuna Flakes", "Water", "Soybean Oil", "Salt"],
  "nutrition_per_100g": {
    "energy_kcal": 140,
    "protein_g": 18.0,
    "carbs_g": 0.0,
    "fat_total_g": 7.0,
    "fat_saturated_g": 1.5,
    "fat_trans_g": 0.0,
    "sodium_mg": 380,
    "potassium_mg": 120,
    "calcium_mg": 10,
    "iron_mg": 1.2,
    "fiber_g": 0.0,
    "sugars_g": 0.0,
    "added_sugars_g": 0.0
  },
  "allergens": ["Fish", "Soy"],
  "confidence_notes": "- Label is clear"
}
```
''';

      String cleaned = rawMarkdownResponse.trim();
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
      expect(json['brand'], equals('Century'));
      expect(json['product_name'], equals('Tuna Flakes in Oil'));
      expect(json['allergens'], contains('Fish'));
      expect(json['nutrition_per_100g']['sodium_mg'], equals(380));
    });

    test('GeminiAdvisoryService parses markdown-wrapped advisory JSON', () {
      final service = GeminiAdvisoryService(apiKey: 'dummy_key');

      const rawAdvisoryMarkdown = '''
```json
{
  "warningText": "High in sodium",
  "explanation": "This product contains 850mg of sodium per serving.",
  "safeServingSize": "Half can (90g)",
  "comparisonExplanation": "Has lower sodium than brand X"
}
```
''';

      String cleaned = rawAdvisoryMarkdown.trim();
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
      expect(json['warningText'], equals('High in sodium'));
      expect(json['safeServingSize'], equals('Half can (90g)'));
    });
  });
}
