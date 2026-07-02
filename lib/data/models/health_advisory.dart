// lib/data/models/health_advisory.dart
//
// Phase 2/3 output. Display-ready -- Phase 5 widgets bind directly to
// this, regardless of whether it came from Gemini or the rule-based
// fallback, and whether or not it includes comparison context.

import '../../core/constants/who_fda_thresholds.dart';

enum AdvisorySource { aiGenerated, fallbackRuleBased }

class HealthAdvisory {
  final AdvisoryLevel overallLevel;
  final String warningText;
  final String explanation;
  final String? safeServingSize;
  final String? comparisonExplanation; // null unless generated with comparison context
  final AdvisorySource source;
  final DateTime generatedAt;

  const HealthAdvisory({
    required this.overallLevel,
    required this.warningText,
    required this.explanation,
    required this.safeServingSize,
    this.comparisonExplanation,
    required this.source,
    required this.generatedAt,
  });

  bool get isFallback => source == AdvisorySource.fallbackRuleBased;
}