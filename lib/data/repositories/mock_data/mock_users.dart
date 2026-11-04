// lib/data/repositories/mock_data/mock_users.dart
//
// Placeholder user health profiles for testing the scoring/advisory engine
// against every condition combination your app supports. Only
// MockUserRepository should import this file directly.

final List<Map<String, dynamic>> mockUsersJson = [
  {
    'userId': 'u001',
    'displayName': 'Test User - Cardiovascular Disease Only',
    'conditions': ['cardiovascularDisease'],
    'allergies': [],
    'voiceAssistant': false,
  },
  {
    'userId': 'u002',
    'displayName': 'Test User - Diabetes Only',
    'conditions': ['diabetes'],
    'allergies': [],
    'voiceAssistant': false,
  },
  {
    'userId': 'u003',
    'displayName': 'Test User - Fish Allergy Only',
    'conditions': [],
    'allergies': ['fish'],
    'voiceAssistant': false,
  },
  {
    'userId': 'u004',
    'displayName': 'Test User - Cardiovascular Disease + Diabetes',
    'conditions': ['cardiovascularDisease', 'diabetes'],
    'allergies': [],
    'voiceAssistant': false,
  },
  {
    'userId': 'u005',
    'displayName': 'Test User - Diabetes + Wheat/Gluten Allergy',
    'conditions': ['diabetes'],
    'allergies': ['wheatGluten'],
    'voiceAssistant': false,
  },
  {
    'userId': 'u006',
    'displayName': 'Test User - Cardiovascular Disease + Voice Assistant',
    'conditions': ['cardiovascularDisease'],
    'allergies': [],
    'voiceAssistant': true,
  },
  {
    'userId': 'u007',
    'displayName': 'Test User - No Conditions (Control/Baseline)',
    'conditions': [],
    'allergies': [],
    'voiceAssistant': false,
  },
  {
    'userId': 'u008',
    'displayName': 'Test User - All',
    'conditions': ['cardiovascularDisease', 'diabetes'],
    'allergies': ['fish'],
    'voiceAssistant': false,
  }
];
