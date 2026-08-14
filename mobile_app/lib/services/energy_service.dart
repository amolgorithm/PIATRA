// lib/services/energy_service.dart
//
// Calls the backend's post-meal energy model. The ODE simulation lives
// entirely server side, this just packages a recipe's nutrients and sends
// them over, same pattern as the optimizer/scheduler/substitution services.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class EnergyCurve {
  final List<double> timesMinutes;
  final List<double> glucose;
  final List<double> insulin;
  final double glycemicLoadEstimate;
  final double peakGlucose;
  final double peakTimeMinutes;
  final double steepestDropPerMinute;
  final bool possibleEnergyDip;
  final String note;

  EnergyCurve({
    required this.timesMinutes,
    required this.glucose,
    required this.insulin,
    required this.glycemicLoadEstimate,
    required this.peakGlucose,
    required this.peakTimeMinutes,
    required this.steepestDropPerMinute,
    required this.possibleEnergyDip,
    required this.note,
  });

  factory EnergyCurve.fromJson(Map<String, dynamic> j) => EnergyCurve(
        timesMinutes: (j['times_minutes'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        glucose: (j['glucose'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        insulin: (j['insulin'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        glycemicLoadEstimate: (j['glycemic_load_estimate'] as num).toDouble(),
        peakGlucose: (j['peak_glucose'] as num).toDouble(),
        peakTimeMinutes: (j['peak_time_minutes'] as num).toDouble(),
        steepestDropPerMinute: (j['steepest_drop_per_minute'] as num).toDouble(),
        possibleEnergyDip: j['possible_energy_dip'] as bool,
        note: j['note'] as String,
      );
}

class EnergyService {
  EnergyService._();
  static final EnergyService instance = EnergyService._();

  String? lastError;

  Future<EnergyCurve?> getEnergyCurve(Map<String, double> nutrients, {int durationMinutes = 180}) async {
    lastError = null;

    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.energyCurveUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'nutrients': nutrients, 'duration_minutes': durationMinutes}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return EnergyCurve.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }

      lastError = 'Backend returned ${response.statusCode}.';
      return null;
    } on TimeoutException {
      lastError = 'Server took too long to respond. If it was asleep, try again in a moment.';
      return null;
    } catch (e) {
      lastError = 'Could not reach the backend: $e';
      debugPrint('[Energy] exception: $e');
      return null;
    }
  }
}
