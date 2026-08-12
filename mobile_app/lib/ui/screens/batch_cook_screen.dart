// lib/ui/screens/batch_cook_screen.dart
//
// Pick a few recipes to cook at the same time, hand them to the backend
// scheduler, see the actual timeline instead of just cooking one recipe
// fully before starting the next.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../services/batch_scheduler_service.dart';
import '../../services/spoonacular_service.dart';
import '../../state/recipe_provider.dart';
import '../widgets/batch_schedule_timeline.dart';

class BatchCookScreen extends StatefulWidget {
  const BatchCookScreen({super.key});

  @override
  State<BatchCookScreen> createState() => _BatchCookScreenState();
}

class _BatchCookScreenState extends State<BatchCookScreen> {
  static const _maxPicks = 4;

  final Set<int> _selectedIds = {};
  bool _loading = false;
  String? _error;
  BatchSchedule? _result;

  Future<void> _run(List<SpoonacularRecipe> allRecipes) async {
    final picked = allRecipes.where((r) => _selectedIds.contains(r.id)).toList();
    if (picked.length < 2) {
      setState(() => _error = 'Pick at least 2 recipes, batching one recipe with itself has nothing to schedule around.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    final result = await BatchSchedulerService.instance.scheduleBatchCook(recipes: picked);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      if (result == null) _error = BatchSchedulerService.instance.lastError ?? 'Something went wrong, try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recipes = context.watch<RecipeProvider>().rankedRecipes.map((r) => r.recipe).toList();

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
                    Text(
                      'Pick 2-$_maxPicks recipes to cook at once',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryLight),
                    ),
                    const SizedBox(height: 12),
                    if (recipes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('No recipes loaded yet, go pull up recommendations first.'),
                      )
                    else
                      _buildRecipePicker(recipes, isDark),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _run(recipes),
                        child: const Text('Schedule'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) _buildError(),
                    if (_loading) _buildLoading(),
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
          Text('Batch Cook', style: Theme.of(context).textTheme.displaySmall),
        ],
      ),
    );
  }

  Widget _buildRecipePicker(List<SpoonacularRecipe> recipes, bool isDark) {
    return Column(
      children: recipes.take(20).map((r) {
        final selected = _selectedIds.contains(r.id);
        final atLimit = _selectedIds.length >= _maxPicks && !selected;
        final hasSteps = r.steps.isNotEmpty;

        return Opacity(
          opacity: (atLimit || !hasSteps) ? 0.4 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryPurple
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: selected,
              onChanged: (!hasSteps || atLimit) && !selected
                  ? null
                  : (v) => setState(() {
                        if (v == true) {
                          _selectedIds.add(r.id);
                        } else {
                          _selectedIds.remove(r.id);
                        }
                      }),
              title: Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                hasSteps ? '${r.steps.length} steps · ${r.readyInMinutes} min' : 'No step-by-step instructions available',
                style: const TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.primaryPurple,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 20),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppTheme.primaryPurple),
          SizedBox(height: 12),
          Text(
            'Scheduling... first request can take a bit if the server was asleep.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
    );
  }

  Widget _buildResult(bool isDark) {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _statBlock('Cooking one at a time', '${r.naiveSequentialMinutes.round()} min')),
              Expanded(child: _statBlock('Batched together', '${r.makespanMinutes.round()} min')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'That saves about ${r.minutesSaved.round()} minutes. Best possible with an unlimited kitchen would be ${r.criticalPathMinutes.round()} min.',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryLight, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          BatchScheduleTimeline(schedule: r),
        ],
      ),
    );
  }

  Widget _statBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
