// lib/data/services/backend_locator.dart
//
// Single place where the health-advisory / ranking / comparison backend
// (lib/core + lib/data) is wired together, so screens don't each construct
// their own ProductRepository/UserRepository/GeminiAdvisoryService.
// Follows the same singleton-via-static-instance pattern ProductDbService
// already uses elsewhere in this app -- no new DI framework introduced.

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../repositories/product_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/history_repository.dart';
import 'favorites_service.dart';
import 'gemini_advisory_service.dart';
import 'product_comparison_service.dart';
import 'product_ranking_service.dart';

class BackendLocator {
  BackendLocator._();

  // Read from .env (loaded once in main.dart via dotenv.load()) --
  // pubspec.yaml already lists .env as an asset and flutter_dotenv as a
  // dependency. Update the key name below if your .env uses a different
  // variable name than GEMINI_API_KEY.
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static final ProductRepository productRepository = FirestoreProductRepository();

  static final UserRepository userRepository = FirebaseUserRepository();

  // Backed by Firestore (`users/{userId}/favorites`) -- favorites now
  // persist across app restarts and sync across a user's devices. The
  // heart button (product detail) and the History screen's Favorites tab
  // both read/write through this one instance so they always agree on
  // what's favorited.
  static final FavoritesRepository favoritesRepository = FirebaseFavoritesRepository();

  // The orchestration layer screens should actually call -- wraps
  // favoritesRepository + productRepository together (e.g. for turning
  // favorited productIds into full Product objects). Both the product
  // detail heart button and the History screen's Favorites tab read/write
  // through this one instance so they always agree on what's favorited.
  static final FavoritesService favoritesService = FavoritesService(
    favoritesRepository: favoritesRepository,
    productRepository: productRepository,
  );

  // Backed by Firestore (`users/{userId}/history`) -- scan and comparison
  // records persist across app restarts and sync across a user's devices.
  // HistoryService (services/history_service.dart) wraps this with the
  // in-memory cache + broadcast stream the History screen listens to for
  // UI reactivity, so this instance itself stays a thin Firestore adapter.
  static final HistoryRepository historyRepository = FirebaseHistoryRepository();

  static final GeminiAdvisoryService geminiAdvisoryService =
      GeminiAdvisoryService(apiKey: _geminiApiKey);

  static final ProductRankingService productRankingService =
      ProductRankingService(geminiService: geminiAdvisoryService);

  static final ProductComparisonService productComparisonService =
      ProductComparisonService(
    productRepository: productRepository,
    productRankingService: productRankingService,
  );
}