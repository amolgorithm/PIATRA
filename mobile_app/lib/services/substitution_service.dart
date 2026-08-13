// lib/services/substitution_service.dart
//
// Calls the backend's ingredient substitution endpoint. The actual vector
// math (cosine similarity over a nutrient-vector cache) all lives server
// side, this is just the client-side plumbing.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class SubstituteResult {
  final String name;
  final double similarity;

  SubstituteResult({required this.name, required this.similarity});

  factory SubstituteResult.fromJson(Map<String, dynamic> j) => SubstituteResult(
        name: j['name'] as String,
        similarity: (j['similarity'] as num).toDouble(),
      );
}

class SubstitutionService {
  SubstitutionService._();
  static final SubstitutionService instance = SubstitutionService._();

  String? lastError;

  /// Returns null on failure, an empty list if the ingredient just isn't in
  /// the nutrient cache (not really an "error," just nothing to show).
  Future<List<SubstituteResult>?> getSubstitutes(String ingredientName, {int limit = 5}) async {
    lastError = null;
    final uri = Uri.parse(
      '${AppConfig.ingredientsBaseUrl}/${Uri.encodeComponent(ingredientName)}/substitutes?limit=$limit',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return (decoded['substitutes'] as List<dynamic>)
            .map((s) => SubstituteResult.fromJson(s as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 404) {
        // not an error the user needs alarmed about, just nothing on file
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        lastError = decoded['detail'] as String? ?? 'Not in the ingredient database yet.';
        return [];
      }

      lastError = 'Backend returned ${response.statusCode}.';
      return null;
    } on TimeoutException {
      lastError = 'Server took too long to respond. If it was asleep, try again in a moment.';
      return null;
    } catch (e) {
      lastError = 'Could not reach the backend: $e';
      debugPrint('[Substitution] exception: $e');
      return null;
    }
  }
}
