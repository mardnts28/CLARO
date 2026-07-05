// lib/data/repositories/firestore_label_mappings.dart
//
// Your groupmate's Firestore stores health conditions and allergens as
// display labels rather than the enum names UserHealthProfile.fromJson()
// expects internally (e.g. "hypertension"). The app supports English and
// Tagalog (user-selectable, translates every module), so the same
// underlying selection can be written as either language's label -- this
// file maps both onto one canonical enum value. If the labels in Firestore
// ever change, only this file needs updating -- not the model or the
// repository.
//
// CONFIRMED fixed allergen options (English/Tagalog), per app spec -- these
// are the only allergen values the picker can produce:
//   fish/isda, milk/gatas, egg/itlog, soy bean/soya, wheat/trigo,
//   shellfish/lamang-dagat, peanut/mani, none
//
// "none"/"wala" means "no allergens selected" -- treated as a deliberate
// no-op (skipped silently, not logged as unrecognized).
//
// NOTE: AllergenType also has treeNuts and msg values (used elsewhere in
// your scoring logic for products), but neither is a selectable allergen
// option in this app's picker, so nothing in Firestore will ever map to
// them via this file.
//
// Unrecognized labels (typos, future picker options not yet mapped here)
// are skipped rather than thrown, so one bad value in a Firestore doc
// doesn't crash the whole profile load -- they're logged via debugPrint so
// real data issues still surface during testing.

import 'package:flutter/foundation.dart';
import '../models/health_profile.dart';

String _normalize(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

const _noValueLabels = {'none', 'wala', 'nil'};

final Map<String, HealthCondition> _conditionLabelMap = {
  _normalize('Diabetes'): HealthCondition.diabetes,
  _normalize('Alta-presyon'): HealthCondition.hypertension,
  _normalize('Hypertension'): HealthCondition.hypertension,
};

final Map<String, AllergenType> _allergenLabelMap = {
  _normalize('Fish'): AllergenType.fish,
  _normalize('Isda'): AllergenType.fish,
  _normalize('Milk'): AllergenType.dairy,
  _normalize('Gatas'): AllergenType.dairy,
  _normalize('Egg'): AllergenType.eggs,
  _normalize('Itlog'): AllergenType.eggs,
  _normalize('Soy Bean'): AllergenType.soy,
  _normalize('Soya'): AllergenType.soy,
  _normalize('Wheat'): AllergenType.wheatGluten,
  _normalize('Trigo'): AllergenType.wheatGluten,
  _normalize('Shellfish'): AllergenType.shellfish,
  _normalize('Lamang-Dagat'): AllergenType.shellfish,
  _normalize('Peanut'): AllergenType.peanuts,
  _normalize('Mani'): AllergenType.peanuts,
};

List<HealthCondition> mapConditionLabels(List<dynamic> raw) {
  final result = <HealthCondition>[];
  for (final label in raw) {
    final normalized = _normalize(label.toString());
    if (_noValueLabels.contains(normalized)) continue;
    final match = _conditionLabelMap[normalized];
    if (match != null) {
      result.add(match);
    } else {
      debugPrint(
        '[FirebaseUserRepository] Unrecognized condition label: '
        '"$label" -- skipped. Add it to firestore_label_mappings.dart if '
        'this is a real value your groupmate uses.',
      );
    }
  }
  return result;
}

List<AllergenType> mapAllergenLabels(List<dynamic> raw) {
  final result = <AllergenType>[];
  for (final label in raw) {
    final normalized = _normalize(label.toString());
    if (_noValueLabels.contains(normalized)) continue;
    final match = _allergenLabelMap[normalized];
    if (match != null) {
      result.add(match);
    } else {
      debugPrint(
        '[FirebaseUserRepository] Unrecognized allergen label: '
        '"$label" -- skipped. Add it to firestore_label_mappings.dart if '
        'this is a real value your groupmate uses.',
      );
    }
  }
  return result;
}
