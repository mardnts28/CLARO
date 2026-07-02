// lib/data/models/health_advisory.dart
//
// Phase 2 output. Display-ready -- Phase 5 widgets bind directly to this,
// regardless of whether it came from Gemini or the rule-based fallback.

import '../../core/constants/who_fda_thresholds.dart';

enum AdvisorySource { aiGenerated, fallbackRuleBased }

class HealthAdvisory {
  final AdvisoryLevel overallLevel;
  final String warningText;      // short headline, e.g. "High in sodium"
  final String explanation;      // 1-3 sentence plain-language explanation
  final String? safeServingSize; // null if not applicable/determinable
  final AdvisorySource source;
  final DateTime generatedAt;

  const HealthAdvisory({
    required this.overallLevel,
    required this.warningText,
    required this.explanation,
    required this.safeServingSize,
    required this.source,
    required this.generatedAt,
  });

  bool get isFallback => source == AdvisorySource.fallbackRuleBased;
}