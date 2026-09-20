// lib/core/utils/group_advisory_builder.dart
//
// Everything needed to turn N members' product evaluations into ONE group
// verdict: the per-member facts, the Gemini prompt, the response name
// restoration, and the rule-based fallback used when Gemini is unavailable,
// not needed (everyone suitable), or the pack size was changed on screen.
//
// PRIVACY: the prompt never contains member names. Each member is sent as
// an opaque tag ([M1], [M2] ...; the signed-in user is [YOU]) and the tags
// are swapped back to display names locally after Gemini answers. Health
// conditions are therefore never sent to Gemini alongside a person's name.

import '../../data/models/group_evaluation.dart';
import '../../data/models/health_advisory.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../constants/who_fda_thresholds.dart';
import 'who_calculator.dart';

class GroupMemberFacts {
  final String alias; // '[M1]' ... or '[YOU]' -- what Gemini sees
  final String name; // display name -- NEVER sent to Gemini
  final bool isSelf;
  final AdvisoryLevel level;
  final List<String> conditions; // english names
  final List<String> allergens; // e.g. 'Dairy/Milk (ingredient "Whey", derived)'
  final String? nutrientKey; // main nutrient of concern, null if none
  final double? amountPerServing;
  final double? percentOfDaily;

  const GroupMemberFacts({
    required this.alias,
    required this.name,
    required this.isSelf,
    required this.level,
    required this.conditions,
    required this.allergens,
    this.nutrientKey,
    this.amountPerServing,
    this.percentOfDaily,
  });

  bool get isFlagged => level != AdvisoryLevel.suitable;
}

class GroupAdvisoryBuilder {
  GroupAdvisoryBuilder._();

  // ── Levels ──────────────────────────────────────────────────────────

  /// A member's verdict for [servingSizeG]. Same rules as the single-user
  /// screen: an allergen match is always Caution; otherwise the worst
  /// nutrient level recomputed for the chosen size.
  static AdvisoryLevel levelAt(ProductEvaluation ev, double servingSizeG) {
    if (ev.allergenAssessment.hasDirectAllergen) return AdvisoryLevel.caution;
    if (ev.nutrientEvaluations.isEmpty) return ev.overallLevel;

    var worst = AdvisoryLevel.suitable;
    for (final n in ev.nutrientEvaluations) {
      final level = _nutrientLevelAt(n, servingSizeG);
      if (level == AdvisoryLevel.caution) return AdvisoryLevel.caution;
      if (level == AdvisoryLevel.moderate) worst = AdvisoryLevel.moderate;
    }
    return worst;
  }

  static AdvisoryLevel groupLevel(Iterable<AdvisoryLevel> levels) {
    var worst = AdvisoryLevel.suitable;
    for (final l in levels) {
      if (l == AdvisoryLevel.caution) return AdvisoryLevel.caution;
      if (l == AdvisoryLevel.moderate) worst = AdvisoryLevel.moderate;
    }
    return worst;
  }

  static int severity(AdvisoryLevel l) => switch (l) {
        AdvisoryLevel.suitable => 0,
        AdvisoryLevel.moderate => 1,
        AdvisoryLevel.caution => 2,
      };

  static double _percentAt(NutrientEvaluation n, double servingSizeG) {
    final value = (n.valuePer100g / 100) * servingSizeG;
    return (value / WhoCalculator.getWhoDailyLimit(n.nutrientKey)) * 100;
  }

  static AdvisoryLevel _nutrientLevelAt(NutrientEvaluation n, double servingSizeG) =>
      WhoCalculator.classifyByWhoPercentage(_percentAt(n, servingSizeG));

  // ── Facts ───────────────────────────────────────────────────────────

  /// Facts for every member, in the order given, at [servingSizeG].
  static List<GroupMemberFacts> buildFacts(
    List<MemberEvaluation> members,
    double servingSizeG,
  ) {
    var n = 0;
    return members.map((m) {
      final alias = m.isSelf ? '[YOU]' : '[M${++n}]';
      return _factsFor(m, alias, servingSizeG);
    }).toList();
  }

  static GroupMemberFacts _factsFor(MemberEvaluation m, String alias, double size) {
    final ev = m.evaluation;
    final level = levelAt(ev, size);

    // Nutrient of concern: highest severity, then highest % of daily limit.
    NutrientEvaluation? worst;
    var worstSeverity = 0;
    var worstPct = -1.0;
    for (final ne in ev.nutrientEvaluations) {
      final pct = _percentAt(ne, size);
      final sev = severity(WhoCalculator.classifyByWhoPercentage(pct));
      if (sev == 0) continue;
      if (sev > worstSeverity || (sev == worstSeverity && pct > worstPct)) {
        worst = ne;
        worstSeverity = sev;
        worstPct = pct;
      }
    }

    final allergens = <String>[];
    for (final src in ev.allergenAssessment.ingredientSources) {
      final how = src.matchType == AllergenMatchType.direct ? 'direct' : 'derived';
      allergens.add(src.ingredient == null
          ? src.allergen.displayLabel
          : '${src.allergen.displayLabel} (ingredient "${src.ingredient}", $how)');
    }
    if (allergens.isEmpty) {
      allergens.addAll(ev.allergenAssessment.matchedContains.map((a) => a.displayLabel));
    }

    return GroupMemberFacts(
      alias: alias,
      name: m.name,
      isSelf: m.isSelf,
      level: level,
      conditions: m.profile.conditions.map(_conditionName).toList(),
      allergens: allergens,
      nutrientKey: worst?.nutrientKey,
      amountPerServing: worst == null ? null : (worst.valuePer100g / 100) * size,
      percentOfDaily: worst == null ? null : worstPct,
    );
  }

  // ── Gemini prompt ───────────────────────────────────────────────────

  static String buildPrompt({
    required String productName,
    required double servingSizeG,
    required List<GroupMemberFacts> facts,
    String languageCode = 'en',
  }) {
    final level = groupLevel(facts.map((f) => f.level));
    final flagged = facts.where((f) => f.isFlagged).length;

    final memberLines = facts.map((f) {
      final b = StringBuffer('${f.alias}${f.isSelf ? " (the person using the app)" : ""} - Level: ${_levelLabel(f.level)}.');
      b.write(' Health conditions: ${f.conditions.isEmpty ? "none" : f.conditions.join(", ")}.');
      if (f.allergens.isNotEmpty) {
        b.write(' Contains an allergen this member is allergic to: ${f.allergens.join("; ")}.');
      }
      if (f.nutrientKey != null) {
        b.write(' Main nutrient of concern: ${_nutrientLabel(f.nutrientKey!)}, '
            '${f.amountPerServing!.toStringAsFixed(1)}${_nutrientUnit(f.nutrientKey!)} per serving '
            '(${f.percentOfDaily!.toStringAsFixed(1)}% of the WHO daily reference amount).');
      }
      return '- ${b.toString()}';
    }).join('\n');

    final language = languageCode == 'tl'
        ? 'Respond in simple, conversational Tagalog.'
        : 'Respond in simple, conversational English.';

    return '''
You are a wording assistant for the Group Health Advisory card in a Filipino grocery app called CLARO. Several people share one health group. Write ONE short advisory about the scanned product for the whole group, using ONLY the facts below.

Product: $productName
Serving size: ${servingSizeG.toStringAsFixed(0)}g
Overall group level: ${_levelLabel(level)} ($flagged of ${facts.length} members flagged).

Members:
$memberLines

$language

IMPORTANT:
- Refer to each member ONLY by the exact tag shown (for example [M1]), copied character for character. Never invent, guess, or write a real name.
- [YOU] is the person using the app: address them as "you" and do not write the tag itself.
- The application already calculated every amount, percentage and level. You must NOT calculate, derive, estimate, or invent any number. Use only the numbers supplied above.
- Never describe anything as "safe" or medically recommended. Use non-medical, non-diagnostic, cautious language.
- Do not mention calculations, algorithms, risk scores, or WHO by name.

WARNINGTEXT field:
- Maximum 8 words.
- Do NOT repeat the level words ("Caution", "Moderate", "Suitable") -- the UI shows them separately.
- Example: "High sodium for some members".

EXPLANATION field -- at most 2 short sentences, about 30-45 words in total:
- Sentence 1: say who is flagged (by tag) and the main reason for each, using only the supplied nutrient or allergen facts.
- Sentence 2: one short line for everyone else (for example that the others are not flagged), or a general cautious suggestion. Do not invent serving amounts.
- If nobody is flagged, write one short sentence saying the product looks suitable for the whole group.

Return ONLY valid JSON, no markdown, matching exactly this shape:
{
  "warningText": "short headline, max 8 words",
  "explanation": "the advisory text following the instructions above"
}
''';
  }

  /// Swaps the privacy tags back to display names. Returns null if any tag
  /// (or a tag-like leftover such as "M2") survives, so the caller can fall
  /// back to the deterministic text instead of showing a broken sentence.
  static String? restoreNames(String text, List<GroupMemberFacts> facts, String languageCode) {
    var out = text;
    for (final f in facts) {
      if (f.isSelf) continue;
      out = out.replaceAll(f.alias, f.name);
    }
    out = out.replaceAll('[YOU]', languageCode == 'tl' ? 'ikaw' : 'you');
    if (RegExp(r'\[?\bM\d+\b\]?').hasMatch(out)) return null;
    return out;
  }

  // ── Fallback (no Gemini) ────────────────────────────────────────────

  static HealthAdvisory fallback(List<GroupMemberFacts> facts, {String languageCode = 'en'}) {
    final tl = languageCode == 'tl';
    final level = groupLevel(facts.map((f) => f.level));
    final flagged = facts.where((f) => f.isFlagged).toList()
      ..sort((a, b) => severity(b.level).compareTo(severity(a.level)));

    if (flagged.isEmpty) {
      return _advisory(
        level,
        tl ? 'Angkop para sa buong grupo' : 'Suitable for the whole group',
        tl
            ? 'Mukhang angkop ang produktong ito para sa lahat ng miyembro ng grupo.'
            : 'This product looks suitable for everyone in the group.',
      );
    }

    final parts = flagged.map((f) {
      final who = f.isSelf ? (tl ? 'Ikaw' : 'You') : f.name;
      final String why;
      if (f.allergens.isNotEmpty) {
        why = tl
            ? 'may allergen (${f.allergens.map(_stripDetail).join(", ")})'
            : 'contains an allergen (${f.allergens.map(_stripDetail).join(", ")})';
      } else if (f.nutrientKey != null) {
        why = tl
            ? '${_nutrientLabelTl(f.nutrientKey!)} - ${f.percentOfDaily!.toStringAsFixed(0)}% ng daily reference'
            : '${_nutrientLabel(f.nutrientKey!)} - ${f.percentOfDaily!.toStringAsFixed(0)}% of the daily reference';
      } else {
        why = tl ? 'kailangang bantayan' : 'worth watching';
      }
      return '$who ($why)';
    }).join('; ');

    final others = facts.length - flagged.length;
    final tail = others > 0
        ? (tl ? ' Hindi naman naka-flag ang iba pa.' : ' The others are not flagged.')
        : '';
    final head = level == AdvisoryLevel.caution
        ? (tl ? 'Mag-ingat: ' : 'Be careful: ')
        : (tl ? 'Bantayan: ' : 'Keep an eye on: ');

    return _advisory(
      level,
      level == AdvisoryLevel.caution
          ? (tl ? 'May dapat mag-ingat sa grupo' : 'Some members need to be careful')
          : (tl ? 'May dapat magbantay sa grupo' : 'Some members should watch this'),
      '$head$parts.$tail',
    );
  }

  static HealthAdvisory _advisory(AdvisoryLevel level, String title, String text) => HealthAdvisory(
        overallLevel: level,
        warningText: title,
        explanation: text,
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );

  static String _stripDetail(String allergen) {
    final i = allergen.indexOf(' (');
    return i == -1 ? allergen : allergen.substring(0, i);
  }

  // ── Cache fingerprint ───────────────────────────────────────────────

  /// Stable across runs (unlike String.hashCode), changes whenever the
  /// product, serving size, member names, levels, conditions, or allergens
  /// change -- so a cached group advisory can never describe an old group.
  static String fingerprint(String productId, double servingSizeG, List<GroupMemberFacts> facts) {
    final b = StringBuffer('$productId|${servingSizeG.toStringAsFixed(1)}');
    final sorted = [...facts]..sort((x, y) => x.name.compareTo(y.name));
    for (final f in sorted) {
      b.write('|${f.name}:${f.level.name}:${f.conditions.join(",")}:${f.allergens.join(",")}'
          ':${f.nutrientKey}:${f.percentOfDaily?.toStringAsFixed(0)}');
    }
    var h = 0x811c9dc5;
    for (final c in b.toString().codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  // ── Labels ──────────────────────────────────────────────────────────

  static String _levelLabel(AdvisoryLevel l) => switch (l) {
        AdvisoryLevel.suitable => 'Suitable',
        AdvisoryLevel.moderate => 'Moderate',
        AdvisoryLevel.caution => 'Caution',
      };

  static String _conditionName(HealthCondition c) => switch (c) {
        HealthCondition.hypertension => 'hypertension',
        HealthCondition.diabetes => 'diabetes',
        HealthCondition.heartCondition => 'heart condition',
      };

  static String _nutrientLabel(String key) => switch (key) {
        'sodiumMg' => 'sodium',
        'sugarsG' => 'total sugars',
        'saturatedFatG' => 'saturated fat',
        _ => key,
      };

  static String _nutrientLabelTl(String key) => switch (key) {
        'sodiumMg' => 'sodium',
        'sugarsG' => 'kabuuang asukal',
        'saturatedFatG' => 'saturated fat',
        _ => key,
      };

  static String _nutrientUnit(String key) => key == 'sodiumMg' ? 'mg' : 'g';
}