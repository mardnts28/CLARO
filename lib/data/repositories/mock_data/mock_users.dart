// lib/data/repositories/mock_data/mock_users.dart
//
// Placeholder user health profiles for testing the scoring/advisory engine
// against every condition combination your app supports. Only
// MockUserRepository should import this file directly.

final List<Map<String, dynamic>> mockUsersJson = [
  {
    'userId': 'u001',
    'displayName': 'Test User - Hypertension Only',
    'conditions': ['hypertension'],
    'allergies': [],
    'dietaryRestrictions': [],
    'lowVisionMode': false,
  },
  {
    'userId': 'u002',
    'displayName': 'Test User - Diabetes Only',
    'conditions': ['diabetes'],
    'allergies': [],
    'dietaryRestrictions': [],
    'lowVisionMode': false,
  },
  {
    'userId': 'u003',
    'displayName': 'Test User - Fish Allergy Only',
    'conditions': [],
    'allergies': ['fish'],
    'dietaryRestrictions': [],
    'lowVisionMode': false,
  },
  {
    'userId': 'u004',
    'displayName': 'Test User - Hypertension + Diabetes',
    'conditions': ['hypertension', 'diabetes'],
    'allergies': [],
    'dietaryRestrictions': [],
    'lowVisionMode': false,
  },
  {
    'userId': 'u005',
    'displayName': 'Test User - Diabetes + Wheat/Gluten Allergy',
    'conditions': ['diabetes'],
    'allergies': ['wheatGluten'],
    'dietaryRestrictions': [],
    'lowVisionMode': false,
  },
  {
    'userId': 'u006',
    'displayName': 'Test User - Hypertension + Low Vision',
    'conditions': ['hypertension'],
    'allergies': [],
    'dietaryRestrictions': [],
    'lowVisionMode': true,
  },
  {
    'userId': 'u007',
    'displayName': 'Test User - No Conditions (Control/Baseline)',
    'conditions': [],
    'allergies': [],
    'dietaryRestrictions': [],
    'lowVisionMode': false,
  },
];
