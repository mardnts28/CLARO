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

  Map<String, dynamic> toJson() => {
        'overallLevel': overallLevel.name,
        'warningText': warningText,
        'explanation': explanation,
        'safeServingSize': safeServingSize,
        'comparisonExplanation': comparisonExplanation,
        'source': source.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory HealthAdvisory.fromJson(Map<String, dynamic> json) {
    return HealthAdvisory(
      overallLevel: AdvisoryLevel.values.firstWhere(
        (e) => e.name == json['overallLevel'],
        orElse: () => AdvisoryLevel.caution,
      ),
      warningText: json['warningText'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      safeServingSize: json['safeServingSize'] as String?,
      comparisonExplanation: json['comparisonExplanation'] as String?,
      source: AdvisorySource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => AdvisorySource.aiGenerated,
      ),
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}