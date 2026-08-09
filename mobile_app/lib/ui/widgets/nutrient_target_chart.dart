// lib/ui/widgets/nutrient_target_chart.dart
//
// Bar chart for the optimizer results: one row per nutrient target, bar
// length is achieved/target. Not pulling in a whole charting package for a
// handful of progress bars, LinearProgressIndicator already does this.

import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';

class NutrientTargetChart extends StatelessWidget {
  final Map<String, double> achieved;
  final Map<String, double> minimums;
  final Map<String, double> maximums;

  const NutrientTargetChart({
    super.key,
    required this.achieved,
    required this.minimums,
    required this.maximums,
  });

  @override
  Widget build(BuildContext context) {
    final keys = {...minimums.keys, ...maximums.keys}.toList()..sort();
    if (keys.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map(_row).toList(),
    );
  }

  Widget _row(String key) {
    final value = achieved[key] ?? 0;
    final min = minimums[key];
    final max = maximums[key];

    // bar against the floor if there is one, the ceiling otherwise
    final target = min ?? max ?? value;
    final fraction = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final overCeiling = max != null && value > max;
    final underFloor = min != null && value < min;

    final barColor = overCeiling
        ? AppTheme.errorRed
        : (underFloor ? AppTheme.warningYellow : AppTheme.successGreen);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_label(key),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                min != null
                    ? '${value.toStringAsFixed(0)} / ${min.toStringAsFixed(0)}'
                    : '${value.toStringAsFixed(0)} (cap ${max!.toStringAsFixed(0)})',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // "protein_g" -> "Protein (g)". not worth a whole lookup table for this
  String _label(String key) {
    final parts = key.split('_');
    if (parts.length < 2) return key;
    final unit = parts.last;
    final name = parts.sublist(0, parts.length - 1).join(' ');
    final capitalized = name[0].toUpperCase() + name.substring(1);
    return '$capitalized ($unit)';
  }
}