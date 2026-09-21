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
  /// Returns the display label for a given [rank] (1-based) among
  /// [totalProducts] compared products, and [suitabilityRankLabel].
  ///
  /// - An allergen match ([SuitabilityRankLabel.forcedLast]) always shows
  ///   "Allergen Warning", regardless of numeric rank.
  /// - Rank 1 always shows "Best" -- top of the list, any size.
  /// - The LAST rank in the list (`rank == totalProducts`, no allergen
  ///   involved) always shows "Least Recommended" -- this used to be
  ///   hardcoded to `rank == 5`, which was wrong for every list that
  ///   wasn't exactly 5 items long: shorter lists (3-4 items) never
  ///   flagged their actual worst product in red at all, and longer
  ///   lists (6+, e.g. the "Compare" screen's full same-category list)
  ///   mislabeled the item at position 5 as "Least Recommended" even
  ///   though it wasn't actually last, while the item that WAS last just
  ///   showed a flat, neutral "Ranked" tag with no warning.
  /// - Everything strictly between 1 and [totalProducts] is a "middle"
  ///   position, split into three even bands -- "Better" (closer to
  ///   best), "Good" (middle), "Fair" (closer to worst) -- based on
  ///   where [rank] falls relative to [totalProducts], not on its
  ///   absolute value. For a 5-item list this reduces to exactly ranks
  ///   2/3/4 -> Better/Good/Fair, i.e. today's existing behavior, so
  ///   nothing changes for the common case.
  /// - [includeChoiceSuffix] controls whether the middle bands read
  ///   "Better" / "Good" / "Fair" (compare/ranking list tags) or "Better
  ///   Choice" / "Good Choice" / "Fair Choice" (product detail screen's
  ///   card title). "Best" and "Least Recommended" are never suffixed
  ///   with "Choice" either way, matching prior behavior.
  static String label({
    required int rank,
    required int totalProducts,
    required SuitabilityRankLabel suitabilityRankLabel,
    bool includeChoiceSuffix = false,
  }) {
    if (suitabilityRankLabel == SuitabilityRankLabel.forcedLast) {
      return 'Allergen Warning';
    }
    if (totalProducts <= 1 || rank <= 1) {
      return includeChoiceSuffix ? 'Best Choice' : 'Best';
    }
    if (rank >= totalProducts) {
      return 'Least Recommended';
    }

    switch (_middleBand(rank: rank, totalProducts: totalProducts)) {
      case _MiddleBand.better:
        return includeChoiceSuffix ? 'Better Choice' : 'Better';
      case _MiddleBand.good:
        return includeChoiceSuffix ? 'Good Choice' : 'Good';
      case _MiddleBand.fair:
        return includeChoiceSuffix ? 'Fair Choice' : 'Fair';
    }
  }

  /// Returns the color paired with [label] for the same [rank] /
  /// [totalProducts] / [suitabilityRankLabel] inputs. Always call this
  /// alongside [label] with the same arguments so the tag/title color
  /// and text never disagree.
  ///
  /// Three-color scheme: green for rank 1, red for the last rank in the
  /// list (or an allergen match), dark gray/orange for everything in
  /// between -- same scheme as before, just with the "last rank" check
  /// now scaling to [totalProducts] instead of being hardcoded to 5.
  static Color color({
    required int rank,
    required int totalProducts,
    required SuitabilityRankLabel suitabilityRankLabel,
  }) {
    if (suitabilityRankLabel == SuitabilityRankLabel.forcedLast) {
      return Colors.red;
    }
    if (totalProducts <= 1 || rank <= 1) {
      return Colors.green;
    }
    if (rank >= totalProducts) {
      return Colors.red;
    }
    return const Color.fromARGB(255, 228, 129, 30);
  }

  /// Buckets a "middle" [rank] (strictly between 1 and [totalProducts])
  /// into one of three even bands by relative position, NOT by absolute
  /// rank number. E.g. for totalProducts=9, middle ranks are 2-8 (7
  /// slots): 2-4 -> better, 5-6 -> good, 7-8 -> fair. For totalProducts=5
  /// (today's original list size), this always yields exactly
  /// 2->better, 3->good, 4->fair -- unchanged from before.
  static _MiddleBand _middleBand({
    required int rank,
    required int totalProducts,
  }) {
    final middleCount = totalProducts - 2; // slots strictly between 1 and N
    final positionInMiddle = rank - 2; // 0-based index within that band
    final bandIndex = middleCount <= 0
        ? 0
        : (positionInMiddle * 3) ~/ middleCount;
    switch (bandIndex.clamp(0, 2)) {
      case 0:
        return _MiddleBand.better;
      case 1:
        return _MiddleBand.good;
      default:
        return _MiddleBand.fair;
    }
  }
}

enum _MiddleBand { better, good, fair }