// lib/core/utils/relationship_labels.dart
//
// Display labels + icon assets for MemberRelationship. Kept out of the
// generated l10n files (they're regenerated from the .arb files) -- add
// these keys to the .arb files later if you'd rather manage them there.

import 'package:flutter/material.dart';

import '../../data/models/health_group.dart';

class RelationshipLabels {
  RelationshipLabels._();

  /// Image asset for a relation, or null for "Others" (which uses the
  /// Group bottom-nav icon, Icons.group_outlined, instead).
  static String? assetFor(MemberRelationship r) {
    switch (r) {
      case MemberRelationship.family:
        return 'assets/images/family.png';
      case MemberRelationship.friend:
        return 'assets/images/friends.png';
      case MemberRelationship.lover:
        return 'assets/images/lover.png';
      case MemberRelationship.other:
        return null;
    }
  }

  static String label(MemberRelationship r, BuildContext context) {
    final tl = Localizations.localeOf(context).languageCode == 'tl';
    switch (r) {
      case MemberRelationship.family:
        return tl ? 'Pamilya' : 'Family';
      case MemberRelationship.friend:
        return tl ? 'Kaibigan' : 'Friends';
      case MemberRelationship.lover:
        return tl ? 'Kasintahan' : 'Lover';
      case MemberRelationship.other:
        return tl ? 'Iba pa' : 'Others';
    }
  }

  static String sectionTitle(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'tl' ? 'Relasyon' : 'Relation';

  /// Small widget showing the relation's icon at [size]. In dark mode the
  /// icon sits on a light-gray rounded backing so the (dark-line) PNG
  /// artwork stays visible; "Others" gets the same backing for consistency.
  static Widget icon(
    BuildContext context,
    MemberRelationship r, {
    required double size,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = assetFor(r);

    if (!isDark) {
      if (asset == null) return Icon(Icons.group_outlined, size: size, color: color);
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.group_outlined, size: size, color: color),
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
            errorBuilder: (_, __, ___) =>
                Icon(Icons.group_outlined, size: inner, color: Colors.grey.shade800),
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