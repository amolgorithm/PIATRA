// lib/services/recipe_ranking_engine.dart
//
// ═══════════════════════════════════════════════════════════════════════════
//  RANKING ARCHITECTURE
// ═══════════════════════════════════════════════════════════════════════════
//
//  Stage 0 – HARD RESTRICTION GATE (discard, never score)
//    • Diet violations   (vegetarian → meat discarded, etc.)
//    • Allergy / intolerance violations (dairy-free → dairy discarded)
//    • Numeric hard filters (calories, macros, time, dish type, pantry-only)
//
//  Stage 1 – SCORE (0–100 pts)
//    • 35 pts  Pantry match
//    • 20 pts  Calorie fit
//    • 15 pts  Macro fit
//    • 15 pts  Cuisine score   (bumped: cuisine = explicit user intent)
//    • 10 pts  Cooking-mode fit
//    •  5 pts  Popularity tie-breaker
//
//  Stage 2 – PARTITION + SORT
//    If cuisine filter is active:
//      Group A  – cuisine-matching  → sorted by score DESC
//      Group B  – non-cuisine       → sorted by score DESC
//      A always precedes B in the final list.
//    Otherwise: flat sort by score.
//
//  Stage 3 – PANTRY-MISS FLAG
//    If all top results have >80% missing ingredients →
//    pantryMatchWarning = true  (UI shows "No great pantry matches" banner).
//
// ═══════════════════════════════════════════════════════════════════════════

import '../models/user_profile_model.dart';
import '../models/recipe_filter.dart';
import '../models/pantry_item.dart';
import 'spoonacular_service.dart';

// ─── Score breakdown ──────────────────────────────────────────────────────────

class ScoreBreakdown {
  final double pantryMatch;    // 0–35
  final double calorieFit;     // 0–20
  final double macroFit;       // 0–15
  final double cuisineScore;   // 0–15
  final double cookingModeFit; // 0–10
  final double popularity;     // 0–5

  const ScoreBreakdown({
    required this.pantryMatch,
    required this.calorieFit,
    required this.macroFit,
    required this.cuisineScore,
    required this.cookingModeFit,
    required this.popularity,
  });

  double get total =>
      pantryMatch + calorieFit + macroFit + cuisineScore + cookingModeFit +
      popularity;

  @override
  String toString() =>
      'Total=${total.toStringAsFixed(1)} '
      '[pantry=${pantryMatch.toStringAsFixed(1)}, '
      'cal=${calorieFit.toStringAsFixed(1)}, '
      'macro=${macroFit.toStringAsFixed(1)}, '
      'cuisine=${cuisineScore.toStringAsFixed(1)}, '
      'mode=${cookingModeFit.toStringAsFixed(1)}, '
      'pop=${popularity.toStringAsFixed(1)}]';
}

// ─── Result models ────────────────────────────────────────────────────────────

class RankedRecipe {
  final SpoonacularRecipe recipe;
  final ScoreBreakdown score;
  final List<String> pantryIngredients;
  final List<String> missingIngredients;
  final List<String> matchReasons;

  /// True when this recipe belongs to the cuisine-matching partition (Group A).
  final bool matchesCuisine;

  RankedRecipe({
    required this.recipe,
    required this.score,
    required this.pantryIngredients,
    required this.missingIngredients,
    required this.matchReasons,
    this.matchesCuisine = false,
  });

  double get totalScore => score.total;
  double get pantryMatchPercent => recipe.pantryMatchPercent;
}

class RankingResult {
  /// Final ordered list: cuisine-group first (if any), then others.
  final List<RankedRecipe> recipes;

  /// True when all top results are poor pantry matches (>80% missing).
  final bool pantryMatchWarning;

  /// True when a cuisine filter is active AND there are recipes outside it.
  final bool hasFallbackSection;

  /// Index in [recipes] where the fallback (non-cuisine) section begins.
  /// Only meaningful when [hasFallbackSection] is true.
  final int fallbackStartIndex;

  const RankingResult({
    required this.recipes,
    required this.pantryMatchWarning,
    required this.hasFallbackSection,
    required this.fallbackStartIndex,
  });
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class RecipeRankingEngine {
  RecipeRankingEngine._();
  static final RecipeRankingEngine instance = RecipeRankingEngine._();

  // ── Entry point ────────────────────────────────────────────────────────────

  RankingResult rankAndFilter({
    required List<SpoonacularRecipe> recipes,
    required UserProfileModel profile,
    required List<PantryItem> pantry,
    required RecipeFilter filter,
  }) {
    final pantryNames = _normPantry(pantry);
    final perMealCal = profile.calorieTarget / 3.0;

    // ── Stage 0: hard restriction gate ──────────────────────────────────────
    final allowed = recipes
        .where((r) => _passesRestrictions(r, profile, filter, pantryNames))
        .toList();

    // ── Stage 1: score ───────────────────────────────────────────────────────
    final ranked = <RankedRecipe>[];
    for (final recipe in allowed) {
      final match = _matchIngredients(recipe, pantryNames);
      final fraction = recipe.ingredients.isEmpty
          ? 1.0
          : match.haveCount / recipe.ingredients.length;
      final cuisineMatch = _matchesCuisine(recipe, filter.cuisines);

      ranked.add(RankedRecipe(
        recipe: recipe,
        score: _score(
          recipe: recipe,
          profile: profile,
          perMealCal: perMealCal,
          fraction: fraction,
          filter: filter,
          cuisineMatch: cuisineMatch,
        ),
        pantryIngredients: match.have,
        missingIngredients: match.missing,
        matchReasons: _reasons(
          recipe: recipe,
          profile: profile,
          fraction: fraction,
          cuisineMatch: cuisineMatch,
          filter: filter,
        ),
        matchesCuisine: cuisineMatch,
      ));
    }

    // ── Stage 2: partition + sort ────────────────────────────────────────────
    final hasCuisineFilter = filter.cuisines.isNotEmpty;

    List<RankedRecipe> groupA;
    List<RankedRecipe> groupB;

    if (hasCuisineFilter) {
      groupA = ranked.where((r) => r.matchesCuisine).toList();
      groupB = ranked.where((r) => !r.matchesCuisine).toList();
    } else {
      groupA = ranked;
      groupB = [];
    }

    _sort(groupA, filter.sortOrder);
    _sort(groupB, filter.sortOrder);

    // ── Stage 3: pantry-miss flag ────────────────────────────────────────────
    final topList = groupA.isEmpty ? groupB : groupA;
    final pantryWarning = topList.isNotEmpty &&
        topList.every((r) {
          final total = r.recipe.ingredients.length;
          if (total == 0) return false;
          return r.missingIngredients.length / total > 0.80;
        });

    final combined = [...groupA, ...groupB];

    return RankingResult(
      recipes: combined,
      pantryMatchWarning: pantryWarning,
      hasFallbackSection: hasCuisineFilter && groupB.isNotEmpty,
      fallbackStartIndex: groupA.length,
    );
  }

  // ── Stage 0: hard restrictions ────────────────────────────────────────────

  bool _passesRestrictions(
    SpoonacularRecipe r,
    UserProfileModel profile,
    RecipeFilter filter,
    Set<String> pantryNames,
  ) {
    // Merge profile + filter dietary preferences
    final allDiets = {
      ...profile.dietaryPreferences.map((d) => d.toLowerCase()),
      ...filter.diets.map((d) => d.toLowerCase()),
    };
    for (final d in allDiets) {
      if (!_dietCompliant(r, d)) return false;
    }

    // Merge profile + filter intolerances
    final allIntolerances = {
      ...profile.allergies.map((a) => a.toLowerCase()),
      ...filter.intolerances.map((i) => i.toLowerCase()),
    };
    for (final i in allIntolerances) {
      if (_hasIntolerance(r, i)) return false;
    }

    // Numeric hard filters
    if (filter.pantryOnlyMode) {
      final m = _matchIngredients(r, pantryNames);
      if (r.ingredients.isNotEmpty && m.haveCount < r.ingredients.length)
        return false;
    }

    if (filter.minPantryMatchPercent > 0 && r.ingredients.isNotEmpty) {
      final m = _matchIngredients(r, pantryNames);
      if (m.haveCount / r.ingredients.length * 100 <
          filter.minPantryMatchPercent) return false;
    }

    if (filter.maxReadyMinutes != null &&
        r.readyInMinutes > filter.maxReadyMinutes!) return false;

    final cal = r.nutrition.calories;
    if (filter.minCalories != null && cal < filter.minCalories!) return false;
    if (filter.maxCalories != null && cal > filter.maxCalories!) return false;

    if (filter.minProteinG != null && r.nutrition.protein < filter.minProteinG!)
      return false;
    if (filter.maxCarbsG != null && r.nutrition.carbs > filter.maxCarbsG!)
      return false;
    if (filter.maxFatG != null && r.nutrition.fat > filter.maxFatG!)
      return false;

    if (filter.dishTypes.isNotEmpty) {
      final have = r.dishTypes.map((d) => d.toLowerCase()).toSet();
      final want = filter.dishTypes.map((d) => d.toLowerCase()).toSet();
      if (have.intersection(want).isEmpty) return false;
    }

    return true;
  }

  bool _dietCompliant(SpoonacularRecipe r, String diet) {
    switch (diet) {
      case 'vegetarian':        return r.vegetarian;
      case 'vegan':             return r.vegan;
      case 'gluten free':
      case 'gluten-free':       return r.glutenFree;
      case 'dairy free':
      case 'dairy-free':        return r.dairyFree;
      case 'ketogenic':
      case 'keto':              return r.nutrition.carbs < 30;
      default:                  return true; // handled at API level
    }
  }

  bool _hasIntolerance(SpoonacularRecipe r, String intolerance) {
    switch (intolerance) {
      case 'dairy':
      case 'lactose':           return !r.dairyFree;
      case 'gluten':
      case 'wheat':             return !r.glutenFree;
      default:                  return false; // API-filtered
    }
  }

  // ── Stage 1: scoring ──────────────────────────────────────────────────────

  ScoreBreakdown _score({
    required SpoonacularRecipe recipe,
    required UserProfileModel profile,
    required double perMealCal,
    required double fraction,
    required RecipeFilter filter,
    required bool cuisineMatch,
  }) {
    return ScoreBreakdown(
      pantryMatch: (fraction * 35).clamp(0, 35),
      calorieFit: _scoreCal(recipe.nutrition.calories, perMealCal),
      macroFit: _scoreMacros(recipe.nutrition, profile.macroTargets),
      cuisineScore: _scoreCuisine(cuisineMatch, filter.cuisines, profile),
      cookingModeFit: _scoreMode(recipe, profile.cookingMode),
      popularity: _scorePop(recipe),
    );
  }

  double _scoreCal(double cal, double target) {
    if (target <= 0) return 10;
    final dev = (cal - target).abs() / target;
    if (dev <= 0.10) return 20;
    if (dev <= 0.20) return 15;
    if (dev <= 0.35) return 10;
    if (dev <= 0.50) return 5;
    return 0;
  }

  double _scoreMacros(SpoonacularNutrition n, MacroTargets t) {
    double s = 0;
    final tP = t.proteinG / 3, tC = t.carbsG / 3, tF = t.fatG / 3;
    s += tP > 0 ? _bell(n.protein / tP, 5, 1.0, 0.3) : 2.5;
    s += tC > 0 ? _bell(n.carbs  / tC, 5, 1.0, 0.4) : 2.5;
    s += tF > 0 ? _bell(n.fat    / tF, 5, 0.9, 0.4) : 2.5;
    return s.clamp(0, 15);
  }

  double _bell(double ratio, double max, double ideal, double tol) {
    final d = (ratio - ideal).abs();
    if (d <= tol * 0.5) return max;
    if (d <= tol)       return max * 0.7;
    if (d <= tol * 2)   return max * 0.3;
    return 0;
  }

  /// Cuisine score is BINARY when a cuisine preference is active:
  ///   match = 15 pts, no match = 0 pts.
  /// This 15-pt gap ensures cuisine-correct recipes always rank above
  /// cuisine-incorrect ones at equal pantry/nutrition quality, reinforcing
  /// the Stage-2 partition even if sortOrder is changed.
  double _scoreCuisine(
      bool match, List<String> filterCuisines, UserProfileModel profile) {
    final active =
        filterCuisines.isNotEmpty ? filterCuisines : profile.favoriteCuisines;
    if (active.isEmpty) return 7.5; // neutral — no preference set
    return match ? 15.0 : 0.0;
  }

  double _scoreMode(SpoonacularRecipe r, CookingMode mode) {
    switch (mode) {
      case CookingMode.general:
        return 5;
      case CookingMode.quickMeals:
        if (r.readyInMinutes <= 15) return 10;
        if (r.readyInMinutes <= 25) return 7;
        if (r.readyInMinutes <= 35) return 4;
        return 1;
      case CookingMode.healthyEating:
        return ((r.veryHealthy ? 5 : 0) +
                ((r.healthScore ?? 50) / 100 * 5))
            .clamp(0, 10);
      case CookingMode.bulkCooking:
        final sv = r.servings >= 6 ? 6 : r.servings >= 4 ? 4 : 1;
        final tm = r.readyInMinutes >= 45 ? 4 : r.readyInMinutes >= 30 ? 2 : 0;
        return (sv + tm).clamp(0, 10).toDouble();
      case CookingMode.budgetFriendly:
        return r.cheap ? 10 : 4;
      case CookingMode.gourmet:
        final ic = r.ingredients.length;
        final is_ = ic >= 12 ? 6 : ic >= 8 ? 4 : 2;
        final tm = r.readyInMinutes >= 60 ? 4 : r.readyInMinutes >= 40 ? 2 : 0;
        return (is_ + tm).clamp(0, 10).toDouble();
    }
  }

  double _scorePop(SpoonacularRecipe r) =>
      ((r.spoonacularScore ?? 50) / 100 * 3 +
              (r.healthScore ?? 50) / 100 * 2)
          .clamp(0, 5);

  // ── Sort ──────────────────────────────────────────────────────────────────

  void _sort(List<RankedRecipe> list, RecipeSortOrder order) {
    switch (order) {
      case RecipeSortOrder.bestMatch:
        list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
        break;
      case RecipeSortOrder.pantryMatch:
        list.sort(
            (a, b) => b.pantryMatchPercent.compareTo(a.pantryMatchPercent));
        break;
      case RecipeSortOrder.calories:
        list.sort((a, b) => a.recipe.nutrition.calories
            .compareTo(b.recipe.nutrition.calories));
        break;
      case RecipeSortOrder.prepTime:
        list.sort((a, b) =>
            a.recipe.readyInMinutes.compareTo(b.recipe.readyInMinutes));
        break;
      case RecipeSortOrder.healthScore:
        list.sort((a, b) =>
            (b.recipe.healthScore ?? 0).compareTo(a.recipe.healthScore ?? 0));
        break;
      case RecipeSortOrder.popularity:
        list.sort((a, b) => (b.recipe.spoonacularScore ?? 0)
            .compareTo(a.recipe.spoonacularScore ?? 0));
        break;
    }
  }

  // ── Ingredient matching ───────────────────────────────────────────────────

  _MatchResult _matchIngredients(
      SpoonacularRecipe recipe, Set<String> pantryNames) {
    final have = <String>[], missing = <String>[];
    for (final ing in recipe.ingredients) {
      (_inPantry(ing.name, pantryNames) ? have : missing).add(ing.name);
    }
    recipe.pantryMatchCount = have.length;
    recipe.missingIngredientCount = missing.length;
    return _MatchResult(have: have, missing: missing);
  }

  bool _inPantry(String name, Set<String> pantry) {
    final n = _norm(name);
    if (pantry.contains(n)) return true;
    for (final p in pantry) {
      if (p.contains(n) || n.contains(p)) return true;
    }
    return false;
  }

  bool _matchesCuisine(SpoonacularRecipe r, List<String> cuisines) {
    if (cuisines.isEmpty) return true;
    final rc = r.cuisines.map((c) => c.toLowerCase()).toSet();
    final wc = cuisines.map((c) => c.toLowerCase()).toSet();
    return rc.intersection(wc).isNotEmpty;
  }

  Set<String> _normPantry(List<PantryItem> pantry) =>
      pantry.map((i) => _norm(i.name)).toSet();

  String _norm(String s) => s.toLowerCase().trim();

  // ── Match reasons ─────────────────────────────────────────────────────────

  List<String> _reasons({
    required SpoonacularRecipe recipe,
    required UserProfileModel profile,
    required double fraction,
    required bool cuisineMatch,
    required RecipeFilter filter,
  }) {
    final r = <String>[];

    if (fraction >= 0.9)       r.add('✅ Almost everything in pantry');
    else if (fraction >= 0.6)  r.add('🧺 ${(fraction * 100).round()}% pantry match');

    final activeCuisines =
        filter.cuisines.isNotEmpty ? filter.cuisines : profile.favoriteCuisines;
    if (cuisineMatch && activeCuisines.isNotEmpty) {
      r.add('🍜 ${activeCuisines.first} cuisine');
    }

    if (recipe.vegan)           r.add('🌱 Vegan');
    else if (recipe.vegetarian) r.add('🥬 Vegetarian');
    if (recipe.glutenFree)      r.add('🌾 Gluten-free');
    if (recipe.dairyFree)       r.add('🥛 Dairy-free');
    if (recipe.veryHealthy)     r.add('🥗 Very healthy');

    switch (profile.cookingMode) {
      case CookingMode.quickMeals:
        if (recipe.readyInMinutes <= 20) r.add('⚡ ${recipe.readyInMinutes} min');
        break;
      case CookingMode.budgetFriendly:
        if (recipe.cheap) r.add('💰 Budget friendly');
        break;
      case CookingMode.bulkCooking:
        if (recipe.servings >= 6) r.add('🍲 ${recipe.servings} servings');
        break;
      default:
        break;
    }

    return r;
  }
}

// ─── Internal ─────────────────────────────────────────────────────────────────

class _MatchResult {
  final List<String> have;
  final List<String> missing;
  int get haveCount => have.length;
  _MatchResult({required this.have, required this.missing});
}