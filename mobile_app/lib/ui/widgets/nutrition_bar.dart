import 'package:flutter/material.dart';
import '../../models/nutrition.dart';
import '../../core/constants/theme/app_theme.dart';

class NutritionBar extends StatelessWidget {
  final Nutrition nutrition;

  const NutritionBar({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nutrition Facts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${nutrition.calories} cal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNutrientRow(
            'Protein',
            nutrition.protein,
            Colors.red.shade400,
          ),
          const SizedBox(height: 8),
          _buildNutrientRow(
            'Carbs',
            nutrition.carbs,
            Colors.blue.shade400,
          ),
          const SizedBox(height: 8),
          _buildNutrientRow(
            'Fat',
            nutrition.fat,
            Colors.orange.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}g',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}