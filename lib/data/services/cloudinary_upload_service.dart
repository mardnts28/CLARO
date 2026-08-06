// lib/data/services/cloudinary_upload_service.dart
//
// Unsigned Cloudinary upload -- no backend needed, consistent with the rest
// of this app's architecture (Flutter talks to Firestore/Gemini/Cloudinary
// directly, no server layer). Used by the unknown-product report flow to
// upload front/back label photos so admin can actually see them during
// review (the old flow stored a local device file path, which meant
// nothing off-device -- see report_model.dart's migration notes).
//
// Setup required (one-time, in your Cloudinary console):
//   1. Settings > Upload > Add upload preset
//   2. Signing Mode: Unsigned
//   3. Folder: product_reports (or update _uploadFolder below to match)
//   4. Save, then put the preset name + your cloud name into .env as
//      CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET.
//
// Unsigned presets are safe for this use case (anyone with the preset name
// can upload, but can't read/delete/modify other assets), but consider
// adding Cloudinary's upload moderation/rate-limiting if abuse becomes a
// concern once this is public.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryUploadService {
  CloudinaryUploadService({
    required String cloudName,
    required String uploadPreset,
  })  : _cloudName = cloudName,
        _uploadPreset = uploadPreset;

  final String _cloudName;
  final String _uploadPreset;
  static const String _uploadFolder = 'product_reports';
  static const Duration _timeout = Duration(seconds: 30);

  /// Uploads [bytes] and returns the resulting secure_url, or null if the
  /// upload fails (caller decides how to handle -- e.g. still let the
  /// report submit with a missing photo URL rather than blocking entirely).
  Future<String?> upload(Uint8List bytes, {required String filename}) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      print('CLOUDINARY UPLOAD SKIPPED: missing cloud name or upload preset');
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = _uploadFolder
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        print('CLOUDINARY UPLOAD FAILED (${response.statusCode}): ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String?;
    } catch (e) {
      print('CLOUDINARY UPLOAD ERROR: $e');
      return null;
    }
  }
}