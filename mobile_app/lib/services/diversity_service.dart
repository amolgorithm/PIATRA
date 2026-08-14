// lib/services/diversity_service.dart
//
// Bridges the recipe ranking engine's quality scores (and each recipe's
// nutrient profile, same shape the optimizer/substitution features use)
// with the backend's greedy diversity selector. The actual math (cosine
// similarity + greedy correlation-minimizing selection) lives server side.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'nutrient_mapper.dart';
import 'recipe_ranking_engine.dart';

class DiversifiedItem {
  final String id;
  final String name;
  final double quality;
  final double avgSimilarityAtPick;

  DiversifiedItem({
    required this.id,
    required this.name,
    required this.quality,
    required this.avgSimilarityAtPick,
  });

  factory DiversifiedItem.fromJson(Map<String, dynamic> j) => DiversifiedItem(
        id: j['id'] as String,
        name: j['name'] as String,
        quality: (j['quality'] as num).toDouble(),
        avgSimilarityAtPick: (j['avg_similarity_at_pick'] as num).toDouble(),
      );
}

class DiversityService {
  DiversityService._();
  static final DiversityService instance = DiversityService._();

  String? lastError;

  Future<List<DiversifiedItem>?> diversify({
    required List<RankedRecipe> candidates,
    int k = 8,
    double alpha = 6.0,
  }) async {
    lastError = null;

    if (candidates.isEmpty) {
      lastError = 'Nothing to diversify yet, load some recommendations first.';
      return null;
    }

    final body = jsonEncode({
      'candidates': candidates
          .map((r) => {
                'id': r.recipe.id.toString(),
                'name': r.recipe.title,
                'quality': r.score.total,
                'nutrients': NutrientMapper.toOptimizerNutrients(r.recipe.nutrition),
              })
          .toList(),
      'k': k,
      'alpha': alpha,
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.diversitySelectUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return (decoded['selected'] as List<dynamic>)
            .map((s) => DiversifiedItem.fromJson(s as Map<String, dynamic>))
            .toList();
      }

      lastError = 'Backend returned ${response.statusCode}.';
      return null;
    } on TimeoutException {
      lastError = 'Server took too long to respond. If it was asleep, try again in a moment.';
      return null;
    } catch (e) {
      lastError = 'Could not reach the backend: $e';
      debugPrint('[Diversity] exception: $e');
      return null;
    }
  }
}
