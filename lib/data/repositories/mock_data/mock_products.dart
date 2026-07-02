// lib/data/repositories/mock_data/mock_products.dart
//
// Placeholder product dataset standing in for Open Food Facts API / your
// team's trained recognition model, until the real dataset is ready.
// Nutrition values are realistic approximations based on typical Philippine
// grocery products in these categories -- NOT verified exact figures.
// Only MockProductRepository should import this file directly.

final List<Map<String, dynamic>> mockProductsJson = [
  {
    'id': 'p001',
    'name': 'Corned Beef',
    'brand': 'Argentina',
    'category': 'cannedFood',
    'servingSizeG': 100,
    'nutritionPer100g': {
      'caloriesKcal': 220, 'sodiumMg': 780, 'sugarsG': 1.0,
    },
    'containsAllergens': [],
    'mayContainAllergens': ['soy'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p002',
    'name': 'Sardines in Tomato Sauce',
    'brand': 'Ligo',
    'category': 'cannedFood',
    'servingSizeG': 155,
    'nutritionPer100g': {
      'caloriesKcal': 180, 'sodiumMg': 490, 'sugarsG': 2.5,
    },
    'containsAllergens': ['fish'],
    'mayContainAllergens': [],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p003',
    'name': 'Sardines in Tomato Sauce',
    'brand': '555',
    'category': 'cannedFood',
    'servingSizeG': 155,
    'nutritionPer100g': {
      'caloriesKcal': 175, 'sodiumMg': 520, 'sugarsG': 3.0,
    },
    'containsAllergens': ['fish'],
    'mayContainAllergens': ['soy'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p004',
    'name': 'Corned Beef',
    'brand': 'CDO',
    'category': 'cannedFood',
    'servingSizeG': 100,
    'nutritionPer100g': {
      'caloriesKcal': 200, 'sodiumMg': 650, 'sugarsG': 1.5,
    },
    'containsAllergens': [],
    'mayContainAllergens': ['soy'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p005',
    'name': 'Tuna Flakes in Oil',
    'brand': 'Century Tuna',
    'category': 'cannedFood',
    'servingSizeG': 90,
    'nutritionPer100g': {
      'caloriesKcal': 190, 'sodiumMg': 380, 'sugarsG': 0.5,
    },
    'containsAllergens': ['fish'],
    'mayContainAllergens': [],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p006',
    'name': 'Meat Loaf',
    'brand': 'Purefoods',
    'category': 'cannedFood',
    'servingSizeG': 100,
    'nutritionPer100g': {
      'caloriesKcal': 260, 'sodiumMg': 820, 'sugarsG': 4.0,
    },
    'containsAllergens': ['soy'],
    'mayContainAllergens': ['dairy'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p007',
    'name': 'Beef Loaf',
    'brand': 'Swift',
    'category': 'cannedFood',
    'servingSizeG': 100,
    'nutritionPer100g': {
      'caloriesKcal': 240, 'sodiumMg': 700, 'sugarsG': 3.0,
    },
    'containsAllergens': ['soy'],
    'mayContainAllergens': [],
    'fdaStatus': 'pending',
  },
  {
    'id': 'p008',
    'name': 'Pancit Canton Original',
    'brand': 'Lucky Me!',
    'category': 'instantNoodles',
    'servingSizeG': 60,
    'nutritionPer100g': {
      'caloriesKcal': 460, 'sodiumMg': 1450, 'sugarsG': 5.0,
    },
    'containsAllergens': ['wheatGluten', 'soy'],
    'mayContainAllergens': ['eggs'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p009',
    'name': 'Chicken Cup Noodles',
    'brand': 'Nissin',
    'category': 'instantNoodles',
    'servingSizeG': 40,
    'nutritionPer100g': {
      'caloriesKcal': 440, 'sodiumMg': 1600, 'sugarsG': 4.0,
    },
    'containsAllergens': ['wheatGluten', 'soy'],
    'mayContainAllergens': ['shellfish'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p010',
    'name': 'Instant Mami Beef',
    'brand': 'Payless',
    'category': 'instantNoodles',
    'servingSizeG': 55,
    'nutritionPer100g': {
      'caloriesKcal': 410, 'sodiumMg': 1700, 'sugarsG': 3.5,
    },
    'containsAllergens': ['wheatGluten', 'soy'],
    'mayContainAllergens': [],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p011',
    'name': 'Sweet Style Spaghetti Sauce (Canned)',
    'brand': 'Purefoods',
    'category': 'cannedFood',
    'servingSizeG': 100,
    'nutritionPer100g': {
      'caloriesKcal': 130, 'sodiumMg': 420, 'sugarsG': 12.0,
    },
    'containsAllergens': [],
    'mayContainAllergens': ['dairy'],
    'fdaStatus': 'verified',
  },
  {
    'id': 'p012',
    'name': 'Low Sodium Corned Beef',
    'brand': 'Healthy Choice (fictional/placeholder)',
    'category': 'cannedFood',
    'servingSizeG': 100,
    'nutritionPer100g': {
      'caloriesKcal': 190, 'sodiumMg': 320, 'sugarsG': 1.0,
    },
    'containsAllergens': [],
    'mayContainAllergens': [],
    'fdaStatus': 'notFound',
  },
];
