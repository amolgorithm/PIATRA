// lib/ui/screens/optimize_plan_screen.dart
//
// Lets the user set a budget/time/nutrient target and hands it to the
// backend LP/QP solver, then shows what it picked and lets them drop it
// straight into this week's meal plan.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../services/optimizer_service.dart';
import '../../services/spoonacular_service.dart';
import '../../services/meal_plan_service.dart';
import '../../state/recipe_provider.dart';
import '../widgets/nutrient_target_chart.dart';

class OptimizePlanScreen extends StatefulWidget {
  const OptimizePlanScreen({super.key});

  @override
  State<OptimizePlanScreen> createState() => _OptimizePlanScreenState();
}

class _OptimizePlanScreenState extends State<OptimizePlanScreen> {
  final _budgetCtrl = TextEditingController(text: '75');
  final _timeCtrl = TextEditingController(text: '300');
  final _proteinCtrl = TextEditingController(text: '350');
  final _sodiumCtrl = TextEditingController(text: '14000');
  String _mode = 'lp';

  bool _loading = false;
  String? _error;
  OptimizedMealPlan? _result;

  // keep the recipes we sent up so "apply" doesn't need to refetch them
  Map<String, SpoonacularRecipe> _recipesById = {};

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _timeCtrl.dispose();
    _proteinCtrl.dispose();
    _sodiumCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final candidates = context.read<RecipeProvider>().rankedRecipes.map((r) => r.recipe).toList();

    if (candidates.isEmpty) {
      setState(() => _error = 'No recipes loaded yet, go pull up recommendations first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    _recipesById = {for (final r in candidates) r.id.toString(): r};

    final result = await OptimizerService.instance.optimizeWeeklyPlan(
      candidates: candidates,
      nutrientMinimums: {'protein_g': double.tryParse(_proteinCtrl.text) ?? 0},
      nutrientMaximums: {'sodium_mg': double.tryParse(_sodiumCtrl.text) ?? 0},
      budget: double.tryParse(_budgetCtrl.text) ?? 0,
      timeBudgetMinutes: double.tryParse(_timeCtrl.text) ?? 0,
      mode: _mode,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      if (result == null) _error = OptimizerService.instance.lastError ?? 'Something went wrong, try again.';
    });
  }

  Future<void> _apply() async {
    if (_result == null || _result!.plan.isEmpty) return;

    setState(() => _loading = true);
    await MealPlanService.instance.applyOptimizedPlan(
      items: _result!.plan,
      recipesById: _recipesById,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildForm(isDark),
                    const SizedBox(height: 20),
                    if (_error != null) _buildError(),
                    if (_loading) const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryPurple),
                          SizedBox(height: 12),
                          Text(
                            'Solving... first request can take a bit if the server was asleep.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    if (_result != null && !_loading) _buildResult(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Text('Auto-Plan My Week', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _numberField('Weekly budget (\$)', _budgetCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numberField('Time budget (min)', _timeCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField('Protein floor (g)', _proteinCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _numberField('Sodium cap (mg)', _sodiumCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _modeChip('lp', 'Hard targets'),
              const SizedBox(width: 8),
              _modeChip('qp', 'Best effort'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Generate plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  Widget _modeChip(String value, String label) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primaryPurple.withOpacity(0.2),
      onSelected: (_) => setState(() => _mode = value),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
    );
  }

  Widget _buildResult(bool isDark) {
    final r = _result!;

    if (r.isInfeasible) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          r.message ?? 'Nothing fit under this budget and time limit. Try "Best effort" mode or loosen a number.',
          style: const TextStyle(fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This week\'s plan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '\$${r.totalCost.toStringAsFixed(2)} · ${r.totalTimeMinutes.round()} min total',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryLight),
        ),
        const SizedBox(height: 12),
        ...r.plan.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Text('${item.servings.toStringAsFixed(1)}x · \$${item.cost.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                ],
              ),
            )),
        const SizedBox(height: 16),
        Text('Nutrients', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        NutrientTargetChart(
          achieved: r.nutrientsAchieved,
          minimums: {'protein_g': double.tryParse(_proteinCtrl.text) ?? 0},
          maximums: {'sodium_mg': double.tryParse(_sodiumCtrl.text) ?? 0},
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Apply to this week', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}