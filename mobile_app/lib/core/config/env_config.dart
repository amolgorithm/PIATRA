// lib/core/config/env_config.dart
//
// Reads environment variables loaded by flutter_dotenv.
// Call EnvConfig.load() once in main() before runApp().

import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  /// Call this in main() before runApp():
  ///   await EnvConfig.load();
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get spoonacularApiKey {
    final key = dotenv.env['SPOONACULAR_API_KEY'];
    assert(key != null && key.isNotEmpty,
        'SPOONACULAR_API_KEY is missing from your .env file');
    return key ?? '';
  }
}