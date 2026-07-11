// lib/core/utils/rank_label_helper.dart
//
// Single source of truth for the "Best / Better / Good / Fair / Least
// Recommended" rank labels and their colors. Used by BOTH:
//   - compare_products_screen.dart (the ranked list-card tags)
//   - product_detail_screen.dart (the "Product Ranking" card title)
// so the two always match. Do not duplicate this switch logic elsewhere --
// if the two screens each had their own copy, they could drift out of
// sync (which is exactly what happened before this helper existed: the
// detail screen's title was hardcoded green regardless of rank).

import 'package:flutter/material.dart';
import '../../data/models/ranked_product_result.dart';

class RankLabelHelper {
  /// Returns the display label for a given [rank] (1-5) and
  /// [suitabilityRankLabel].
  ///
  /// - An allergen match ([SuitabilityRankLabel.forcedLast]) always shows
  ///   "Allergen Warning", regardless of numeric rank.
  /// - Rank 5 (last place with no allergen involved) shows "Least
  ///   Recommended".
  /// - [includeChoiceSuffix] controls whether ranks 1-4 read "Best" /
  ///   "Better" / "Good" / "Fair" (compare/ranking list tags) or "Best
  ///   Choice" / "Better Choice" / "Good Choice" / "Fair Choice" (product
  ///   detail screen's card title). Ranks 5 and forcedLast are never
  ///   suffixed with "Choice" either way.
  static String label({
    required int rank,
    required SuitabilityRankLabel suitabilityRankLabel,
    bool includeChoiceSuffix = false,
  }) {
    if (suitabilityRankLabel == SuitabilityRankLabel.forcedLast) {
      return 'Allergen Warning';
    }
    switch (rank) {
      case 1:
        return includeChoiceSuffix ? 'Best Choice' : 'Best';
      case 2:
        return includeChoiceSuffix ? 'Better Choice' : 'Better';
      case 3:
        return includeChoiceSuffix ? 'Good Choice' : 'Good';
      case 4:
        return includeChoiceSuffix ? 'Fair Choice' : 'Fair';
      case 5:
        return 'Least Recommended';
      default:
        return includeChoiceSuffix ? 'Product Ranking' : 'Ranked';
    }
  }

  /// Returns the color paired with [label] for the same [rank] /
  /// [suitabilityRankLabel] inputs. Always call this alongside [label] with
  /// the same arguments so the tag/title color and text never disagree.
  ///
  /// Three-color scheme: green for the top rank, red for the bottom rank
  /// or an allergen match, dark gray for everything in between.
  static Color color({
    required int rank,
    required SuitabilityRankLabel suitabilityRankLabel,
  }) {
    if (suitabilityRankLabel == SuitabilityRankLabel.forcedLast) {
      return Colors.red;
    }
    switch (rank) {
      case 1:
        return Colors.green;
      case 5:
        return Colors.red;
      default:
        return const Color.fromARGB(255, 228, 129, 30);
    }
  }
}