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

  static final ProductRepository productRepository = ProductDbRepository();

  static final UserRepository userRepository = FirebaseUserRepository();

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