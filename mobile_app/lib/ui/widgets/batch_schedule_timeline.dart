// lib/ui/widgets/batch_schedule_timeline.dart
//
// Gantt-style view of the batch-cook schedule. One row per kitchen
// resource (stove/oven/prep), bars show which recipe's step is running
// when. Horizontally scrollable since a real schedule can run longer than
// what fits on one screen.

import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../services/batch_scheduler_service.dart';

class BatchScheduleTimeline extends StatelessWidget {
  final BatchSchedule schedule;

  const BatchScheduleTimeline({super.key, required this.schedule});

  static const double _pxPerMinute = 6.0;
  static const double _rowHeight = 52.0;
  static const double _labelWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    if (schedule.timeline.isEmpty) return const SizedBox.shrink();

    final resources = schedule.timeline.map((s) => s.resource).toSet().toList()..sort();
    final recipeIds = schedule.timeline.map((s) => s.recipeId).toSet().toList();
    final recipeColors = _assignColors(recipeIds);
    final recipeNames = {for (final s in schedule.timeline) s.recipeId: s.recipeName};
    final totalWidth = schedule.makespanMinutes * _pxPerMinute + 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(recipeIds, recipeColors, recipeNames),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _labelWidth + totalWidth,
            child: Column(
              children: resources.map((r) => _buildRow(r, recipeColors)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String resource, Map<String, Color> recipeColors) {
    final steps = schedule.timeline.where((s) => s.resource == resource).toList();

    return Container(
      height: _rowHeight,
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _label(resource),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryLight),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: _rowHeight - 8,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                for (final s in steps)
                  Positioned(
                    left: s.startMinute * _pxPerMinute,
                    width: (s.endMinute - s.startMinute) * _pxPerMinute,
                    top: 0,
                    height: _rowHeight - 8,
                    child: Tooltip(
                      message:
                          '${s.recipeName}: ${s.text}\n${s.startMinute.toStringAsFixed(0)}-${s.endMinute.toStringAsFixed(0)} min',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: recipeColors[s.recipeId],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          s.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(List<String> recipeIds, Map<String, Color> colors, Map<String, String> names) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: recipeIds.map((id) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colors[id], shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(names[id] ?? id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
      }).toList(),
    );
  }

  Map<String, Color> _assignColors(List<String> recipeIds) {
    const palette = [
      AppTheme.categoryBlue,
      AppTheme.categoryGreen,
      AppTheme.categoryPink,
      AppTheme.categoryOrange,
      AppTheme.categoryTeal,
      AppTheme.categoryPurple,
    ];
    return {for (var i = 0; i < recipeIds.length; i++) recipeIds[i]: palette[i % palette.length]};
  }

  String _label(String resource) {
    switch (resource) {
      case 'stove':
        return 'Stove';
      case 'oven':
        return 'Oven';
      case 'hands':
        return 'Prep';
      default:
        return resource.isEmpty ? resource : resource[0].toUpperCase() + resource.substring(1);
    }
  }
}
