// lib/core/utils/avatar_assets.dart
//
// Lists the member avatar images in assets/images/avatars/ straight from
// the app's asset manifest, so no filenames are hard-coded here. Sorted
// by filename and capped at 8 (4 female + 4 male expected -- name the
// files so female ones sort first, e.g. female_1..4 then male_1..4, to
// get females on row 1 and males on row 2). The folder must be declared
// in pubspec.yaml: `- assets/images/avatars/`.

import 'package:flutter/services.dart';

class AvatarAssets {
  AvatarAssets._();

  static const String folder = 'assets/images/avatars/';
  static const int maxAvatars = 8;

  static List<String>? _cache;

  static Future<List<String>> load() async {
    if (_cache != null) return _cache!;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final all = manifest
          .listAssets()
          .where((a) => a.startsWith(folder) && _isImage(a))
          .toList()
        ..sort();
      _cache = all.take(maxAvatars).toList();
    } catch (_) {
      _cache = const [];
    }
    return _cache!;
  }

  static bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.webp');
  }
}
