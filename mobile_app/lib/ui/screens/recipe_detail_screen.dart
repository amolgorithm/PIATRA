import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../widgets/nutrition_bar.dart';
import '../widgets/step_card.dart';
import '../../core/constants/theme/app_theme.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe? recipe;

  const RecipeDetailScreen({super.key, this.recipe});

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe')),
        body: const Center(child: Text('Recipe not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe!.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildNutritionSection(context),
            _buildIngredientsSection(context),
            _buildStepsSection(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 200,
      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.restaurant,
              size: 80,
              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recipe!.difficulty,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe!.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildInfoChip(Icons.access_time, '${recipe!.totalTime} min'),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.local_fire_department, '${recipe!.nutrition.calories} cal'),
            ],
          ),
          const SizedBox(height: 16),
          NutritionBar(nutrition: recipe!.nutrition),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingredients',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          ...recipe!.ingredients.map((ingredient) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    ingredient.available ? Icons.check_circle : Icons.cancel,
                    color: ingredient.available
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ingredient.amount}${ingredient.unit != null ? " ${ingredient.unit}" : ""} ${ingredient.name}',
                      style: TextStyle(
                        fontSize: 16,
                        decoration: ingredient.available
                            ? null
                            : TextDecoration.lineThrough,
                        color: ingredient.available
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStepsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instructions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          ...List.generate(recipe!.steps.length, (index) {
            return StepCard(
              stepNumber: index + 1,
              instruction: recipe!.steps[index],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Starting cooking mode...'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Start Cooking'),
        ),
      ),
    );
  }
}