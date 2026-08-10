// lib/ui/screens/optimize_plan_screen.dart
//
// Lets the user set a budget/time/nutrient target and hands it to the
// backend LP/QP solver, then shows what it picked, why, and lets them
// drop it straight into this week's meal plan.

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
  final _fiberCtrl = TextEditingController();
  final _satFatCtrl = TextEditingController();
  final _calorieCapCtrl = TextEditingController();
  bool _showMoreConstraints = false;
  String _mode = 'lp';

  bool _loading = false;
  String? _error;
  OptimizedMealPlan? _result;
  int _candidateCount = 0; // recipes actually sent to the solver, for the "how this ran" panel

  // keep the recipes we sent up so "apply" doesn't need to refetch them
  Map<String, SpoonacularRecipe> _recipesById = {};

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _timeCtrl.dispose();
    _proteinCtrl.dispose();
    _sodiumCtrl.dispose();
    _fiberCtrl.dispose();
    _satFatCtrl.dispose();
    _calorieCapCtrl.dispose();
    super.dispose();
  }

  // only include a constraint if the person actually typed something, an
  // empty optional field shouldn't silently turn into a target of 0
  Map<String, double> _minimums() {
    final m = <String, double>{'protein_g': double.tryParse(_proteinCtrl.text) ?? 0};
    final fiber = double.tryParse(_fiberCtrl.text);
    if (fiber != null && fiber > 0) m['fiber_g'] = fiber;
    return m;
  }

  Map<String, double> _maximums() {
    final m = <String, double>{'sodium_mg': double.tryParse(_sodiumCtrl.text) ?? 0};
    final satFat = double.tryParse(_satFatCtrl.text);
    if (satFat != null && satFat > 0) m['saturated_fat_g'] = satFat;
    final calCap = double.tryParse(_calorieCapCtrl.text);
    if (calCap != null && calCap > 0) m['calories'] = calCap;
    return m;
  }

  Future<void> _generate() async {
    final allCandidates = context.read<RecipeProvider>().rankedRecipes.map((r) => r.recipe).toList();
    final priced = allCandidates.where((r) => r.pricePerServing != null).toList();

    if (priced.isEmpty) {
      setState(() => _error = 'None of your loaded recipes have price data yet, try refreshing recommendations first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _candidateCount = priced.length;
    });

    _recipesById = {for (final r in priced) r.id.toString(): r};

    final result = await OptimizerService.instance.optimizeWeeklyPlan(
      candidates: priced,
      nutrientMinimums: _minimums(),
      nutrientMaximums: _maximums(),
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
                    const SizedBox(height: 16),
                    if (_error != null) _buildError(),
                    if (_loading) _buildLoading(),
                    if (_result != null && !_loading) ...[
                      _buildHowThisRan(isDark),
                      const SizedBox(height: 16),
                      _buildResult(isDark),
                    ],
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
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
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _showMoreConstraints = !_showMoreConstraints),
            child: Row(
              children: [
                Icon(
                  _showMoreConstraints ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: AppTheme.primaryPurple,
                ),
                const SizedBox(width: 4),
                const Text(
                  'More constraints (fiber, saturated fat, calories)',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_showMoreConstraints) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField('Fiber floor (g, optional)', _fiberCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _numberField('Sat. fat cap (g, optional)', _satFatCtrl)),
              ],
            ),
            const SizedBox(height: 12),
            _numberField('Calorie cap (kcal, optional)', _calorieCapCtrl),
          ],
          const SizedBox(height: 14),
          _modeSwitch(isDark),
          const SizedBox(height: 18),
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

  // flat two-way segmented control, apple settings style, instead of chips
  Widget _modeSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _segment('lp', 'Hard targets')),
          Expanded(child: _segment('qp', 'Best effort')),
        ],
      ),
    );
  }

  Widget _segment(String value, String label) {
    final selected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 32),
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
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
    );
  }

  // this is the part that actually answers "what is even going on" —
  // spells out what the solver was given and what it did with it, in plain
  // language, instead of just dropping a result on screen
  Widget _buildHowThisRan(bool isDark) {
    final r = _result!;
    final modeLabel = _mode == 'qp' ? 'best-effort (soft targets)' : 'hard-target';
    final distinctRecipes = r.plan.length;

    final activeConstraints = [
      'protein floor',
      if (_fiberCtrl.text.isNotEmpty) 'fiber floor',
      'sodium cap',
      if (_satFatCtrl.text.isNotEmpty) 'saturated fat cap',
      if (_calorieCapCtrl.text.isNotEmpty) 'calorie cap',
    ].join(', ');

    final steps = [
      'Looked at $_candidateCount recipes with pricing available.',
      'Applied your $activeConstraints, plus budget and time limit.',
      'Solved a $modeLabel linear program over all $_candidateCount options.',
      r.isInfeasible
          ? 'No combination satisfied every constraint at once.'
          : 'Landed on $distinctRecipes distinct recipe${distinctRecipes == 1 ? '' : 's'}, capped at 3 servings each so one cheap recipe can\'t eat the whole week.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.route_rounded, size: 16, color: AppTheme.primaryPurple),
              SizedBox(width: 6),
              Text('How this ran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(steps[i], style: const TextStyle(fontSize: 12.5, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
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

    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    final timeBudget = double.tryParse(_timeCtrl.text) ?? 0;
    final budgetUsedPct = budget == 0 ? 0.0 : (r.totalCost / budget * 100).clamp(0, 999);
    final timeUsedPct = timeBudget == 0 ? 0.0 : (r.totalTimeMinutes / timeBudget * 100).clamp(0, 999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This week\'s plan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '\$${r.totalCost.toStringAsFixed(2)} of \$${budget.toStringAsFixed(0)} budget (${budgetUsedPct.toStringAsFixed(0)}%) · '
          '${r.totalTimeMinutes.round()} of ${timeBudget.toStringAsFixed(0)} min (${timeUsedPct.toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryLight),
        ),
        const SizedBox(height: 14),
        ...r.plan.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                ),
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
          minimums: _minimums(),
          maximums: _maximums(),
        ),
        const SizedBox(height: 12),
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