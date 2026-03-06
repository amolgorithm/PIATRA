// lib/ui/screens/spoonacular_recipe_detail_screen.dart

import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';
import 'cooking_mode_screen.dart';
import '../../services/recipe_ranking_engine.dart';
import '../../services/spoonacular_service.dart';

class SpoonacularRecipeDetailScreen extends StatefulWidget {
  final RankedRecipe ranked;
  const SpoonacularRecipeDetailScreen({super.key, required this.ranked});

  @override
  State<SpoonacularRecipeDetailScreen> createState() =>
      _SpoonacularRecipeDetailScreenState();
}

class _SpoonacularRecipeDetailScreenState
    extends State<SpoonacularRecipeDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _instructionsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToInstructions() {
    final ctx = _instructionsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.05);
    }
  }

  void _startCooking() {
    if (widget.ranked.recipe.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No step-by-step instructions available for this recipe.'),
          backgroundColor: AppTheme.warningYellow,
        ),
      );
      return;
    }
    // First scroll to instructions so user sees them briefly, then navigate
    _scrollToInstructions();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CookingModeScreen(ranked: widget.ranked),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ranked.recipe;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ranked = widget.ranked;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Hero image / app bar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                r.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: r.image != null
                  ? Image.network(r.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(r))
                  : _placeholder(r),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Quick stats ─────────────────────────────────────────────
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _StatChip(
                          icon: Icons.access_time_rounded,
                          label: '${r.readyInMinutes} min',
                          color: AppTheme.infoBlue),
                      _StatChip(
                          icon: Icons.local_fire_department_rounded,
                          label:
                              '${r.nutrition.calories.round()} cal',
                          color: AppTheme.accentOrange),
                      _StatChip(
                          icon: Icons.people_rounded,
                          label: '${r.servings} servings',
                          color: AppTheme.successGreen),
                      if (r.cuisines.isNotEmpty)
                        _StatChip(
                            icon: Icons.public_rounded,
                            label: r.cuisines.first,
                            color: AppTheme.primaryPurple),
                      if (r.veryHealthy)
                        _StatChip(
                            icon: Icons.favorite_rounded,
                            label: 'Very healthy',
                            color: AppTheme.successGreen),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Match reasons ───────────────────────────────────────────
                  if (ranked.matchReasons.isNotEmpty) ...[
                    const Text('Why this recipe?',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ranked.matchReasons
                          .map((r) => Chip(
                                label: Text(r,
                                    style:
                                        const TextStyle(fontSize: 12)),
                                backgroundColor: AppTheme.primaryPurple
                                    .withOpacity(0.08),
                                labelStyle: const TextStyle(
                                    color: AppTheme.primaryPurple),
                                side: BorderSide(
                                    color: AppTheme.primaryPurple
                                        .withOpacity(0.2)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Nutrition ───────────────────────────────────────────────
                  const Text('Nutrition',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _NutritionCard(nutrition: r.nutrition),
                  const SizedBox(height: 20),

                  // ── Ingredients ─────────────────────────────────────────────
                  const Text('Ingredients',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...r.ingredients.map((ing) => _IngredientRow(
                        ingredient: ing,
                        inPantry: ranked.pantryIngredients
                            .map((s) => s.toLowerCase())
                            .any((p) =>
                                p.contains(ing.name.toLowerCase()) ||
                                ing.name
                                    .toLowerCase()
                                    .contains(p)),
                      )),
                  const SizedBox(height: 20),

                  // ── Steps ───────────────────────────────────────────────────
                  if (r.steps.isNotEmpty) ...[
                    const Text('Instructions',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...r.steps.map((step) => _StepCard(step: step)),
                  ] else
                    const Text(
                        'Full instructions available at the source link.',
                        style: TextStyle(fontStyle: FontStyle.italic)),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _startCooking,
            icon: const Icon(Icons.outdoor_grill_rounded),
            label: const Text('Start Cooking'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(SpoonacularRecipe r) {
    final colors = [
      [const Color(0xFF6C63FF), const Color(0xFF5B54E8)],
      [const Color(0xFF00D4AA), const Color(0xFF00B894)],
    ];
    final pair = colors[r.id % colors.length];
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: pair)),
      child: Center(
          child: Text(r.title.isNotEmpty ? r.title[0] : '🍽',
              style:
                  const TextStyle(fontSize: 80, color: Colors.white))),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final SpoonacularNutrition nutrition;
  const _NutritionCard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.successGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MacroTile('Calories',
              nutrition.calories.round().toString(), 'kcal',
              AppTheme.accentOrange),
          _MacroTile('Protein',
              nutrition.protein.toStringAsFixed(1), 'g',
              Colors.red.shade400),
          _MacroTile('Carbs',
              nutrition.carbs.toStringAsFixed(1), 'g',
              Colors.blue.shade400),
          _MacroTile('Fat',
              nutrition.fat.toStringAsFixed(1), 'g',
              Colors.orange.shade400),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _MacroTile(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value$unit',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryLight)),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final SpoonacularIngredient ingredient;
  final bool inPantry;
  const _IngredientRow(
      {required this.ingredient, required this.inPantry});

  @override
  Widget build(BuildContext context) {
    final color =
        inPantry ? AppTheme.successGreen : AppTheme.accentOrange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            inPantry ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${ingredient.amount} ${ingredient.unit} ${ingredient.originalName}',
              style: TextStyle(
                  fontSize: 14,
                  color: inPantry ? null : AppTheme.textSecondaryLight),
            ),
          ),
          if (!inPantry)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Buy',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final SpoonacularStep step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.primaryPurple.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle),
            child: Center(
              child: Text('${step.number}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(step.step,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}