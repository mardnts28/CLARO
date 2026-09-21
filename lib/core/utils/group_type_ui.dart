// lib/core/utils/group_type_ui.dart
//
// Labels + icon widget for GroupType (Family / Friends / Partners / Work / Others).
// Kept out of the generated l10n files (they're regenerated from .arb) --
// move these into your .arb files later if you prefer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/health_group.dart';

class GroupTypeUi {
  GroupTypeUi._();

  static const String _folder = 'assets/images/relations/';

  // Keyword each group type's image filename is expected to contain
  // (family.png, friends.png, lover.png, work.png).
  static const Map<GroupType, String> _keywords = {
    GroupType.family: 'family',
    GroupType.friends: 'friend',
    GroupType.partners: 'lover',
    GroupType.work: 'work',
  };

  static Map<GroupType, String>? _resolved;
  static Future<Map<GroupType, String>>? _resolving;

  /// Finds each type's image in the app's asset manifest instead of
  /// trusting a hard-coded path, so a slightly different filename or
  /// folder still resolves. Prefers assets/images/relations/, then falls
  /// back to any assets/images/** file whose name contains the keyword.
  /// Call once at startup (optional) to avoid a first-frame fallback icon.
  static Future<Map<GroupType, String>> ensureLoaded() {
    if (_resolved != null) return Future.value(_resolved!);
    return _resolving ??= _resolve();
  }

  static Future<Map<GroupType, String>> _resolve() async {
    final out = <GroupType, String>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final all = manifest.listAssets().where((a) => a.startsWith('assets/images/')).toList()..sort();
      for (final entry in _keywords.entries) {
        final matches = all.where((a) => a.split('/').last.toLowerCase().contains(entry.value)).toList();
        matches.sort((a, b) {
          final ai = a.startsWith(_folder) ? 0 : 1;
          final bi = b.startsWith(_folder) ? 0 : 1;
          return ai.compareTo(bi);
        });
        if (matches.isNotEmpty) {
          out[entry.key] = matches.first;
        } else {
          debugPrint('[GroupTypeUi] No image found for ${entry.key.name} under assets/images/ '
              '-- is assets/images/relations/ declared in pubspec.yaml?');
        }
      }
    } catch (e) {
      debugPrint('[GroupTypeUi] Could not read asset manifest: $e');
    }
    _resolved = out;
    return out;
  }

  /// Image asset for a group type, or null for "Others" (which uses the
  /// Group bottom-nav icon, Icons.group_outlined, instead) or if the image
  /// couldn't be found.
  static String? assetFor(GroupType t) => _resolved?[t];

  static bool _isTagalog(BuildContext c) => Localizations.localeOf(c).languageCode == 'tl';

  static String label(GroupType t, BuildContext context) {
    final tl = _isTagalog(context);
    switch (t) {
      case GroupType.family:
        return tl ? 'Pamilya' : 'Family';
      case GroupType.friends:
        return tl ? 'Kaibigan' : 'Friends';
      case GroupType.partners:
        return tl ? 'Magkasintahan' : 'Partners';
      case GroupType.work:
        return tl ? 'Trabaho' : 'Work';
      case GroupType.others:
        return tl ? 'Iba pa' : 'Others';
    }
  }

  static String sectionTitle(BuildContext context) => _isTagalog(context) ? 'Uri ng Grupo' : 'Group Type';

  /// The group type's icon at [size]. In dark mode it sits on a light-gray
  /// rounded backing so the dark-line artwork stays visible ("Others"
  /// gets the same backing for consistency).
  static Widget icon(
    BuildContext context,
    GroupType t, {
    required double size,
    Color? color,
  }) {
    if (t == GroupType.others || _resolved != null) {
      return _buildIcon(context, t, size: size, color: color);
    }
    return FutureBuilder<Map<GroupType, String>>(
      future: ensureLoaded(),
      builder: (context, _) => _buildIcon(context, t, size: size, color: color),
    );
  }

  static Widget _buildIcon(
    BuildContext context,
    GroupType t, {
    required double size,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = assetFor(t);

    if (!isDark) {
      if (asset == null) return Icon(Icons.group_outlined, size: size, color: color);
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(Icons.group_outlined, size: size, color: color),
      );
    }

    final pad = size * 0.14;
    final inner = size - pad * 2;
    final Widget content = asset == null
        ? Icon(Icons.group_outlined, size: inner, color: Colors.grey.shade800)
        : Image.asset(
            asset,
            width: inner,
            height: inner,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(Icons.group_outlined, size: inner, color: Colors.grey.shade800),
          );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: content,
    );
  }
}