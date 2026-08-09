// lib/ui/widgets/weekly_nutrition_card.dart
//
// Sits at the top of the meal plan screen, always visible, not tucked behind
// a menu. Shows how this week's actually planned meals stack up against a
// protein target, and the auto-plan CTA lives right here instead of a small
// text button off to the side, this is meant to feel like a core part of
// planning the week, not a bonus feature nobody notices. Flat solid tint,
// no gradient, matches the rest of the app's plainer look.

import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';

class WeeklyNutritionCard extends StatelessWidget {
  final double proteinAchieved;
  final double proteinTarget;
  final int mealsPlanned;
  final int mealsTotal; // 7 days x 4 slots = 28, matches meal_plan_screen
  final int distinctRecipes;
  final VoidCallback onAutoPlan;

  const WeeklyNutritionCard({
    super.key,
    required this.proteinAchieved,
    required this.proteinTarget,
    required this.mealsPlanned,
    required this.mealsTotal,
    required this.distinctRecipes,
    required this.onAutoPlan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fraction = proteinTarget == 0 ? 0.0 : (proteinAchieved / proteinTarget).clamp(0.0, 1.0);
    final weekIsThin = mealsPlanned < mealsTotal; // there's room the solver could fill

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.primaryPurple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text('This week', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('$mealsPlanned / $mealsTotal meals',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
            ],
          ),
          if (mealsPlanned > 0) ...[
            const SizedBox(height: 2),
            Text(
              'from $distinctRecipes distinct recipe${distinctRecipes == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryLight),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Protein', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${proteinAchieved.toStringAsFixed(0)}g / ${proteinTarget.toStringAsFixed(0)}g',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                fraction >= 1 ? AppTheme.successGreen : AppTheme.primaryPurple,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAutoPlan,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(weekIsThin ? 'Auto-plan the rest of this week' : 'Re-optimize this week'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}