// lib/services/batch_scheduler_service.dart
//
// Bridges spoonacular_service (recipe steps) and the backend's
// /api/schedule/batch-cook endpoint. Duration and resource per step are
// estimated client-side from spoonacular's data (see estimateDuration and
// estimateResource on SpoonacularStep), the backend just does the actual
// scheduling math on top of whatever numbers we hand it.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'spoonacular_service.dart';

class ScheduledStep {
  final String recipeId;
  final String recipeName;
  final int stepIndex;
  final String text;
  final String resource;
  final double startMinute;
  final double endMinute;

  ScheduledStep({
    required this.recipeId,
    required this.recipeName,
    required this.stepIndex,
    required this.text,
    required this.resource,
    required this.startMinute,
    required this.endMinute,
  });

  factory ScheduledStep.fromJson(Map<String, dynamic> j) => ScheduledStep(
        recipeId: j['recipe_id'] as String,
        recipeName: j['recipe_name'] as String,
        stepIndex: (j['step_index'] as num).toInt(),
        text: j['text'] as String,
        resource: j['resource'] as String,
        startMinute: (j['start_minute'] as num).toDouble(),
        endMinute: (j['end_minute'] as num).toDouble(),
      );
}

class BatchSchedule {
  final List<ScheduledStep> timeline;
  final double makespanMinutes;
  final double naiveSequentialMinutes;
  final double criticalPathMinutes;
  final double minutesSaved;

  BatchSchedule({
    required this.timeline,
    required this.makespanMinutes,
    required this.naiveSequentialMinutes,
    required this.criticalPathMinutes,
    required this.minutesSaved,
  });

  factory BatchSchedule.fromJson(Map<String, dynamic> j) => BatchSchedule(
        timeline: (j['timeline'] as List<dynamic>)
            .map((s) => ScheduledStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        makespanMinutes: (j['makespan_minutes'] as num).toDouble(),
        naiveSequentialMinutes: (j['naive_sequential_minutes'] as num).toDouble(),
        criticalPathMinutes: (j['critical_path_minutes'] as num).toDouble(),
        minutesSaved: (j['minutes_saved'] as num).toDouble(),
      );
}

class BatchSchedulerService {
  BatchSchedulerService._();
  static final BatchSchedulerService instance = BatchSchedulerService._();

  String? lastError;

  static Map<String, dynamic> _toRecipeInput(SpoonacularRecipe r) {
    return {
      'id': r.id.toString(),
      'name': r.title,
      'steps': r.steps
          .map((s) => {
                'text': s.step,
                'duration_minutes': s.estimateDuration(),
                'resource': s.estimateResource(),
              })
          .toList(),
    };
  }

  Future<BatchSchedule?> scheduleBatchCook({
    required List<SpoonacularRecipe> recipes,
    Map<String, int> resourceCounts = const {'stove': 1, 'oven': 1, 'hands': 1},
  }) async {
    lastError = null;

    final withSteps = recipes.where((r) => r.steps.isNotEmpty).toList();
    if (withSteps.isEmpty) {
      lastError = 'None of the selected recipes have step-by-step instructions to schedule.';
      return null;
    }

    final body = jsonEncode({
      'recipes': withSteps.map(_toRecipeInput).toList(),
      'resource_counts': resourceCounts,
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.batchScheduleUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60)); // same render cold-start story as the optimizer

      if (response.statusCode == 200) {
        return BatchSchedule.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }

      lastError = 'Backend returned ${response.statusCode}.';
      debugPrint('[BatchScheduler] error ${response.statusCode}: ${response.body}');
      return null;
    } on TimeoutException {
      lastError = 'Server took too long to respond. If it was asleep, try again in a moment.';
      return null;
    } catch (e) {
      lastError = 'Could not reach the backend: $e';
      debugPrint('[BatchScheduler] exception: $e');
      return null;
    }
  }
}
