// lib/ui/screens/meal_plan_screen.dart
//
// Weekly meal planner screen.
// Shows a 7-day grid with breakfast/lunch/dinner/snack slots.
// Supports adding meals from Spoonacular, removing, and generating
// a shopping list from the plan.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../services/meal_plan_service.dart';
import '../../services/spoonacular_service.dart';
import '../../services/pantry_service.dart';
import '../../state/recipe_provider.dart';
import '../../state/user_provider.dart';
import '../../models/user_profile_model.dart';
import 'shopping_list_screen.dart';
import 'optimize_plan_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  MealPlan? _plan;
  bool _loading = true;
  int _selectedDay = 0; // 0=Monday ... 6=Sunday

  @override
  void initState() {
    super.initState();
    // Default selected day to today
    _selectedDay = DateTime.now().weekday - 1; // Monday=0
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final plan = await MealPlanService.instance.getOrCreateCurrentWeekPlan();
    if (mounted) setState(() { _plan = plan; _loading = false; });
  }

  Future<void> _addMeal(int dayIndex, MealSlot slot) async {
    // Load recipe provider's recommendations or let user search
    final recipe = await showModalBottomSheet<SpoonacularRecipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipePickerSheet(),
    );

    if (recipe == null || _plan == null) return;

    final meal = PlannedMeal.fromSpoonacular(recipe, slot);
    await MealPlanService.instance.addMealToDay(
      planId:   _plan!.id,
      dayIndex: dayIndex,
      meal:     meal,
    );
    await _load();
  }

  Future<void> _removeMeal(int dayIndex, MealSlot slot) async {
    if (_plan == null) return;
    await MealPlanService.instance.removeMealFromDay(
      planId:   _plan!.id,
      dayIndex: dayIndex,
      slot:     slot,
    );
    await _load();
  }

  Future<void> _generateShoppingList() async {
    if (_plan == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final pantryItems = await PantryService.instance.getAllItems();
    final pantryNames  = pantryItems.map((i) => i.name).toList();

    final shoppingList = await MealPlanService.instance.generateShoppingList(
      plan:            _plan!,
      pantryItemNames: pantryNames,
    );

    if (!mounted) return;
    Navigator.pop(context); // loader

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(shoppingList: shoppingList),
      ),
    );
  }

  Future<void> _openAutoPlan() async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const OptimizePlanScreen()),
    );
    if (applied == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildDaySelector(isDark),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryPurple))
                  : _buildDayContent(isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _plan != null && _plan!.totalMeals > 0
          ? _buildBottomBar(isDark)
          : null,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meal Planner',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  _plan == null
                      ? 'This week'
                      : 'Week of ${_fmtDate(_plan!.weekStart)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_plan != null && _plan!.totalMeals > 0)
            TextButton.icon(
              onPressed: _generateShoppingList,
              icon: const Icon(Icons.shopping_cart_rounded, size: 18),
              label: const Text('Shop'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryPurple,
              ),
            ),
          TextButton.icon(
            onPressed: _openAutoPlan,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Auto-plan'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1;

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: 7,
        itemBuilder: (_, i) {
          final isSelected = _selectedDay == i;
          final isToday = i == today;

          // Count meals on this day
          final dayData = _plan?.days.where((d) => d.dayIndex == i).firstOrNull;
          final mealCount = dayData?.meals.length ?? 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.primaryGradient : null,
                color: isSelected
                    ? null
                    : (isDark ? AppTheme.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: isToday && !isSelected
                    ? Border.all(
                        color: AppTheme.primaryPurple, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(days[i],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                  ? AppTheme.primaryPurple
                                  : null))),
                  if (mealCount > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                          mealCount.clamp(0, 4),
                          (_) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primaryPurple,
                                ),
                              )),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayContent(bool isDark) {
    final dayData = _plan?.days.where((d) => d.dayIndex == _selectedDay).firstOrNull;
    final meals   = dayData?.meals ?? {};

    // Day totals
    final totalCal = meals.values.fold(0.0, (s, m) => s + m.calories);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Day total banner
        if (totalCal > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: AppTheme.primaryPurple, size: 18),
                const SizedBox(width: 8),
                Text('${totalCal.round()} kcal planned',
                    style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                    '${meals.length} meal${meals.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.primaryPurple, fontSize: 12)),
              ],
            ),
          ),

        // Meal slots
        ...MealSlot.values.map((slot) {
          final meal = meals[slot];
          return _MealSlotCard(
            slot:      slot,
            meal:      meal,
            isDark:    isDark,
            onAdd:     () => _addMeal(_selectedDay, slot),
            onRemove:  meal != null
                ? () => _removeMeal(_selectedDay, slot)
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final totalMeals = _plan!.totalMeals;
    final avgCal     = _plan!.avgDailyCalories;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$totalMeals meals planned',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('~${avgCal.round()} kcal/day avg',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _generateShoppingList,
              icon: const Icon(Icons.shopping_cart_rounded, size: 18),
              label: const Text('Generate Shopping List'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }
}

// ─── Meal slot card ───────────────────────────────────────────────────────────

class _MealSlotCard extends StatelessWidget {
  final MealSlot slot;
  final PlannedMeal? meal;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const _MealSlotCard({
    required this.slot,
    required this.meal,
    required this.isDark,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          // Slot header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Icon(slot.slotIcon, size: 18, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                Text(slot.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                if (meal != null && onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppTheme.errorRed.withOpacity(0.7),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),

          if (meal != null)
            _PlannedMealContent(meal: meal!, isDark: isDark)
          else
            _EmptySlot(onAdd: onAdd, isDark: isDark),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PlannedMealContent extends StatelessWidget {
  final PlannedMeal meal;
  final bool isDark;
  const _PlannedMealContent({required this.meal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: meal.image != null
                ? Image.network(meal.image!,
                    width: 60, height: 60, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(meal))
                : _placeholder(meal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Chip('${meal.calories.round()} cal',
                        AppTheme.accentOrange),
                    const SizedBox(width: 6),
                    _Chip('${meal.readyInMinutes}m', AppTheme.infoBlue),
                    const SizedBox(width: 6),
                    _Chip('${meal.protein.round()}g P',
                        Colors.red.shade400),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(PlannedMeal m) => Container(
        width: 60, height: 60,
        decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient),
        child: Center(
          child: Text(
            m.title.isNotEmpty ? m.title[0] : '🍽',
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
      );
}

class _EmptySlot extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isDark;
  const _EmptySlot({required this.onAdd, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primaryPurple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryPurple.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                color: AppTheme.primaryPurple, size: 18),
            SizedBox(width: 6),
            Text('Add meal',
                style: TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold)),
      );
}

// ─── Recipe picker bottom sheet ───────────────────────────────────────────────

class _RecipePickerSheet extends StatefulWidget {
  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  List<SpoonacularRecipe> _recipes = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);
    try {
      final results = await SpoonacularService.instance.complexSearch(
        query: _search.isEmpty ? null : _search,
        number: 20,
      );
      if (mounted) setState(() { _recipes = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  Text('Add a Recipe',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search recipes…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: _loadRecipes,
                      ),
                    ),
                    onSubmitted: (_) => _loadRecipes(),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryPurple))
                  : _recipes.isEmpty
                      ? const Center(child: Text('No recipes found'))
                      : ListView.builder(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recipes.length,
                          itemBuilder: (_, i) {
                            final r = _recipes[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: r.image != null
                                    ? Image.network(r.image!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 56, height: 56,
                                        color: AppTheme.primaryPurple
                                            .withOpacity(0.2),
                                        child: const Icon(
                                            Icons.restaurant_rounded,
                                            color: AppTheme.primaryPurple)),
                              ),
                              title: Text(r.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  maxLines: 2),
                              subtitle: Text(
                                '${r.readyInMinutes}m · ${r.nutrition.calories.round()} cal',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => Navigator.pop(context, r),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}