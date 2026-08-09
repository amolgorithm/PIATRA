// lib/core/config/app_config.dart
//
// Single source of truth for backend URL.
// Change _productionUrl once → all screens update automatically.

class AppConfig {
  AppConfig._();

  // ── Set this to your Render service URL ──────────────────────────────────
  // Format: https://piatra-backend.onrender.com  (no trailing slash)
  static const String _productionUrl = 'https://piatra-backend.onrender.com';

  // For local development, swap the comment:
  // Android emulator  → 'http://10.0.2.2:8000'
  // iOS simulator     → 'http://127.0.0.1:8000'
  // Real device (LAN) → 'http://192.168.x.x:8000'
  static const String _devUrl = 'http://10.0.2.2:8000';

  // Toggle this to false during local dev, true for production builds
  static const bool _useProduction = true;

  static String get baseUrl =>
      _useProduction ? _productionUrl : _devUrl;

  // Pre-built endpoint paths
  static String get assistantChatUrl     => '$baseUrl/api/assistant/chat';
  static String get assistantBaseUrl     => '$baseUrl/api/assistant';
  static String get nutritionAdviceUrl   => '$baseUrl/api/assistant/nutrition-advice';
  static String get recipeSuggestionsUrl => '$baseUrl/api/assistant/recipe-suggestions';

  // Trailing slash required — FastAPI redirects /api/feedback → /api/feedback/
  // without it, causing a 307 that drops the POST body.
  static String get feedbackUrl          => '$baseUrl/api/feedback/';

  static String get optimizeMealPlanUrl  => '$baseUrl/api/optimize/meal-plan';
}