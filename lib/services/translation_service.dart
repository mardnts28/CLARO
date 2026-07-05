import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static const String _apiKey = 'YOUR_GOOGLE_TRANSLATE_API_KEY';
  static const String _baseUrl =
      'https://translation.googleapis.com/language/translate/v2';
  static final Map<String, String> _memoryCache = {};

  static Future<String> translate(String text, String targetLang) async {
    if (targetLang == 'en' || text.isEmpty) {
      return text;
    }

    final cacheKey = '\$targetLang:\$text';

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getString(cacheKey);
      if (savedValue != null && savedValue.isNotEmpty) {
        _memoryCache[cacheKey] = savedValue;
        return savedValue;
      }

      final uri = Uri.parse('$_baseUrl?key=_apiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'q': [text],
          'target': targetLang,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = data['data']?['translations'];
        if (translations is List && translations.isNotEmpty) {
          final translated = translations.first['translatedText'];
          if (translated is String && translated.isNotEmpty) {
            _memoryCache[cacheKey] = translated;
            await prefs.setString(cacheKey, translated);
            return translated;
          }
        }
      }
    } catch (_) {
      // Fall through and return original text.
    }

    return text;
  }
}
