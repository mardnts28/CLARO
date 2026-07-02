// lib/data/models/health_profile.dart
//
// Represents a user's health profile as it will eventually be stored in
// Firestore under: users/{userId}/healthProfile

enum HealthCondition {
  hypertension,
  diabetes,
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

class UserHealthProfile {
  final String userId;
  final String displayName;
  final List<HealthCondition> conditions;
  final List<AllergenType> allergies;
  final List<String> dietaryRestrictions; // free-text, e.g. "low-fat", "halal"
  final bool lowVisionMode; // toggles large text / high contrast / TTS

  const UserHealthProfile({
    required this.userId,
    required this.displayName,
    required this.conditions,
    required this.allergies,
    required this.dietaryRestrictions,
    this.lowVisionMode = false,
  });

  bool get hasHypertension => conditions.contains(HealthCondition.hypertension);
  bool get hasDiabetes => conditions.contains(HealthCondition.diabetes);
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
      dietaryRestrictions: (json['dietaryRestrictions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lowVisionMode: json['lowVisionMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'conditions': conditions.map((c) => c.name).toList(),
        'allergies': allergies.map((a) => a.name).toList(),
        'dietaryRestrictions': dietaryRestrictions,
        'lowVisionMode': lowVisionMode,
      };
}
