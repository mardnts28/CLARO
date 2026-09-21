// lib/data/models/group_evaluation.dart
//
// One group member's evaluation of the product currently being viewed on
// ProductDetailScreen. Built by running the same WhoCalculator pipeline the
// signed-in user's own evaluation uses, but against THAT member's health
// profile (fetched by their own uid / member id -- see
// GroupRepository.getGroupMemberProfiles).

import '../../core/constants/who_fda_thresholds.dart';
import 'health_profile.dart';
import 'product_evaluation.dart';

class MemberEvaluation {
  /// Unique within the group: the member's uid for linked members (owner
  /// included), the member doc id for managed members. Same value as
  /// [profile].userId.
  final String key;
  final String name;
  final String? avatar; // asset path, e.g. 'assets/images/avatars/female_1.png'
  final bool isSelf; // the signed-in user's own card
  final UserHealthProfile profile;
  final ProductEvaluation evaluation;

  const MemberEvaluation({
    required this.key,
    required this.name,
    required this.avatar,
    required this.isSelf,
    required this.profile,
    required this.evaluation,
  });

  /// Level at the product's labeled serving size. Screens that let the user
  /// change the pack size should use GroupAdvisoryBuilder.levelAt() instead.
  AdvisoryLevel get labelLevel => evaluation.allergenAssessment.hasDirectAllergen
      ? AdvisoryLevel.caution
      : evaluation.overallLevel;
}