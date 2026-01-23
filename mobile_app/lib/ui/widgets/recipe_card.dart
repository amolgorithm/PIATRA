import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../core/constants/theme/app_theme.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _buildMatchBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                recipe.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.restaurant,
                    'Uses: ${recipe.availableIngredientsCount}/${recipe.ingredients.length} items',
                  ),
                  const Spacer(),
                  _buildInfoChip(
                    Icons.local_fire_department,
                    '${recipe.nutrition.calories} cal',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.access_time,
                    '${recipe.totalTime} min',
                  ),
                ],
              ),
              if (recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: recipe.tags.take(3).map((tag) {
                    return Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchBadge() {
    final percentage = recipe.ingredientMatchPercentage;
    Color color;
    if (percentage >= 80) {
      color = AppTheme.successGreen;
    } else if (percentage >= 50) {
      color = AppTheme.warningYellow;
    } else {
      color = AppTheme.errorRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${percentage.toStringAsFixed(0)}% match',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}