// lib/services/optimizer_service.dart
//
// Bridges spoonacular_service (recipe data) and the backend's
// /api/optimize/meal-plan endpoint. Recipe data stays client-side like
// everywhere else in the app, this just packages it up and sends it over.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'spoonacular_service.dart';
import 'nutrient_mapper.dart';

class PlanItem {
  final String id;
  final String name;
  final double servings;
  final double cost;

  PlanItem({required this.id, required this.name, required this.servings, required this.cost});

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
        id: j['id'] as String,
        name: j['name'] as String,
        servings: (j['servings'] as num).toDouble(),
        cost: (j['cost'] as num).toDouble(),
      );
}

class OptimizedMealPlan {
  final String status; // "optimal", "penalized", "infeasible"
  final List<PlanItem> plan;
  final double totalCost;
  final double totalTimeMinutes;
  final Map<String, double> nutrientsAchieved;
  final String? message;

  OptimizedMealPlan({
    required this.status,
    required this.plan,
    required this.totalCost,
    required this.totalTimeMinutes,
    required this.nutrientsAchieved,
    this.message,
  });

  bool get isInfeasible => status == 'infeasible';

  factory OptimizedMealPlan.fromJson(Map<String, dynamic> j) => OptimizedMealPlan(
        status: j['status'] as String,
        plan: (j['plan'] as List<dynamic>)
            .map((p) => PlanItem.fromJson(p as Map<String, dynamic>))
            .toList(),
        totalCost: (j['total_cost'] as num).toDouble(),
        totalTimeMinutes: (j['total_time_minutes'] as num).toDouble(),
        nutrientsAchieved: (j['nutrients_achieved'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        message: j['message'] as String?,
      );
}

class OptimizerService {
  OptimizerService._();
  static final OptimizerService instance = OptimizerService._();

  // whatever went wrong on the last call, so the UI can say something
  // more useful than "it failed." null means the last call worked.
  String? lastError;

  /// Turns a spoonacular recipe into the candidate shape the backend wants.
  /// Skips recipes with no price data, the LP can't do anything with a
  /// candidate that has no cost, and Spoonacular doesn't always have it.
  static Map<String, dynamic>? _toCandidate(SpoonacularRecipe r) {
    if (r.pricePerServing == null) return null;

    return {
      'id': r.id.toString(),
      'name': r.title,
      'cost': r.pricePerServing,
      'prep_minutes': r.readyInMinutes.toDouble(),
      'nutrients': NutrientMapper.toOptimizerNutrients(r.nutrition),
      'max_servings': 3, // cap per recipe so the solver has to combine
                         // several different recipes instead of covering
                         // the whole week with just the cheapest one. an LP
                         // optimum sits at a vertex of the feasible region,
                         // vertices are sparse by nature, so a loose cap
                         // (was 7, a full week) let one recipe dominate
    };
  }

  Future<OptimizedMealPlan?> optimizeWeeklyPlan({
    required List<SpoonacularRecipe> candidates,
    required Map<String, double> nutrientMinimums,
    required Map<String, double> nutrientMaximums,
    required double budget,
    required double timeBudgetMinutes,
    String mode = 'lp',
  }) async {
    lastError = null;
    final mapped = candidates.map(_toCandidate).whereType<Map<String, dynamic>>().toList();

    if (mapped.isEmpty) {
      lastError = 'None of your loaded recipes have price data yet, try refreshing recommendations first.';
      debugPrint('[Optimizer] no candidates had price data, nothing to send');
      return null;
    }

    final body = jsonEncode({
      'candidates': mapped,
      'nutrient_targets': {
        'minimums': nutrientMinimums,
        'maximums': nutrientMaximums,
      },
      'budget': budget,
      'time_budget_minutes': timeBudgetMinutes,
      'mode': mode,
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.optimizeMealPlanUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          // free-tier render sleeps after inactivity, first hit can take
          // 30-50s to cold start. 20s was killing every "first request of
          // the day" call before it even had a chance to spin up.
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return OptimizedMealPlan.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }

      lastError = 'Backend returned ${response.statusCode}. ${_shorten(response.body)}';
      debugPrint('[Optimizer] error ${response.statusCode}: ${response.body}');
      return null;
    } on TimeoutException {
      lastError = 'Server took too long to respond. If this is the first request in a while the backend may still be waking up, try again in a moment.';
      debugPrint('[Optimizer] timeout waiting for solver');
      return null;
    } catch (e) {
      lastError = 'Could not reach the backend: $e';
      debugPrint('[Optimizer] exception: $e');
      return null;
    }
  }

  String _shorten(String s) => s.length > 160 ? '${s.substring(0, 160)}...' : s;
}