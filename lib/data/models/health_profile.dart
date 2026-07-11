// lib/data/models/health_profile.dart
//
// Represents a user's health profile as it will eventually be stored in
// Firestore under: users/{userId}/healthProfile

enum HealthCondition {
  hypertension,
  diabetes,
  heartCondition,
}

// Common allergens relevant to Filipino canned food & instant noodles.
// Extend this list as your dataset coverage grows.
enum AllergenType {
  shellfish,
  fish,
  peanuts,
  treeNuts,
  soy,
  dairy,
  eggs,
  wheatGluten,
  msg, // not a true allergen, but frequently flagged as a sensitivity
}

// Human-readable labels for AllergenType, for UI display (e.g. warning
// banners). Kept alongside the enum so any screen can reuse it instead of
// re-deriving its own copy.
extension AllergenTypeDisplay on AllergenType {
  String get displayLabel {
    switch (this) {
      case AllergenType.shellfish:
        return 'Shellfish';
      case AllergenType.fish:
        return 'Fish';
      case AllergenType.peanuts:
        return 'Peanuts';
      case AllergenType.treeNuts:
        return 'Tree Nuts';
      case AllergenType.soy:
        return 'Soy';
      case AllergenType.dairy:
        return 'Dairy/Milk';
      case AllergenType.eggs:
        return 'Eggs';
      case AllergenType.wheatGluten:
        return 'Wheat/Gluten';
      case AllergenType.msg:
        return 'MSG';
    }
  }
}

class UserHealthProfile {
  final String userId;
  final String displayName;
  final List<HealthCondition> conditions;
  final List<AllergenType> allergies;
  // Hands-free voice navigation toggle. The feature itself belongs to a
  // teammate's module, but the on/off state lives on the user doc, so it's
  // represented here.
  final bool voiceAssistant;

  const UserHealthProfile({
    required this.userId,
    required this.displayName,
    required this.conditions,
    required this.allergies,
    this.voiceAssistant = false,
  });

  bool get hasHypertension => conditions.contains(HealthCondition.hypertension);
  bool get hasDiabetes => conditions.contains(HealthCondition.diabetes);
  bool get hasHeartCondition => conditions.contains(HealthCondition.heartCondition);
  bool get hasAnyAllergy => allergies.isNotEmpty;

  factory UserHealthProfile.fromJson(Map<String, dynamic> json) {
    return UserHealthProfile(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      conditions: (json['conditions'] as List<dynamic>)
          .map((c) => HealthCondition.values.firstWhere((e) => e.name == c))
          .toList(),
      allergies: (json['allergies'] as List<dynamic>)
          .map((a) => AllergenType.values.firstWhere((e) => e.name == a))
          .toList(),
      voiceAssistant: json['voiceAssistant'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'conditions': conditions.map((c) => c.name).toList(),
        'allergies': allergies.map((a) => a.name).toList(),
        'voiceAssistant': voiceAssistant,
      };
}