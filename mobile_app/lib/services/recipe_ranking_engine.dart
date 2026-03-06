// lib/services/recipe_ranking_engine.dart
//
// Pure ranking / scoring logic — no API calls.
// Input:  List<SpoonacularRecipe>  +  user context
// Output: sorted List<RankedRecipe> with per-recipe score breakdown
//
// ─── Scoring breakdown (total = 100 pts) ────────────────────────────────────
//  40 pts  Pantry match          – how many ingredients already in pantry
//  20 pts  Calorie fit           – how close calories are to per-meal target
//  15 pts  Macro fit             – protein / carb / fat vs user targets
//  10 pts  Cuisine preference    – bonus if recipe cuisine matches user prefs
//  10 pts  Cooking-mode fit      – prep time, health flags vs CookingMode
//   5 pts  Popularity / quality  – spoonacularScore + healthScore as tie-breaker
// ────────────────────────────────────────────────────────────────────────────

import '../models/user_profile_model.dart';
import '../models/recipe_filter.dart';
import '../models/pantry_item.dart';
import 'spoonacular_service.dart';

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

class ScoreBreakdown {
  final double pantryMatch;    // 0–40
  final double calorieFit;     // 0–20
  final double macroFit;       // 0–15
  final double cuisineBonus;   // 0–10
  final double cookingModeFit; // 0–10
  final double popularity;     // 0–5

  const ScoreBreakdown({
    required this.pantryMatch,
    required this.calorieFit,
    required this.macroFit,
    required this.cuisineBonus,
    required this.cookingModeFit,
    required this.popularity,
  });

  double get total =>
      pantryMatch + calorieFit + macroFit + cuisineBonus + cookingModeFit + popularity;

  @override
  String toString() =>
      'Total=${total.toStringAsFixed(1)} '
      '[pantry=${pantryMatch.toStringAsFixed(1)}, '
      'cal=${calorieFit.toStringAsFixed(1)}, '
      'macro=${macroFit.toStringAsFixed(1)}, '
      'cuisine=${cuisineBonus.toStringAsFixed(1)}, '
      'mode=${cookingModeFit.toStringAsFixed(1)}, '
      'pop=${popularity.toStringAsFixed(1)}]';
}

class RankedRecipe {
  final SpoonacularRecipe recipe;
  final ScoreBreakdown score;
  final List<String> pantryIngredients;   // ingredients user has
  final List<String> missingIngredients;  // ingredients to buy
  final List<String> matchReasons;        // human-readable score reasons

  RankedRecipe({
    required this.recipe,
    required this.score,
    required this.pantryIngredients,
    required this.missingIngredients,
    required this.matchReasons,
  });

  double get totalScore => score.total;
  double get pantryMatchPercent => recipe.pantryMatchPercent;
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

class RecipeRankingEngine {
  RecipeRankingEngine._();
  static final RecipeRankingEngine instance = RecipeRankingEngine._();

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  /// Filter + rank [recipes] against the user's [profile] and [pantry].
  /// Returns sorted list (highest score first).
  List<RankedRecipe> rankAndFilter({
    required List<SpoonacularRecipe> recipes,
    required UserProfileModel profile,
    required List<PantryItem> pantry,
    required RecipeFilter filter,
  }) {
    final pantryNames = _normalisePantryNames(pantry);
    final perMealCalTarget = (profile.calorieTarget / 3).roundToDouble(); // 3 meals/day

    final ranked = <RankedRecipe>[];

    for (final recipe in recipes) {
      // ── 1. Hard filters ──────────────────────────────────────────
      if (!_passesHardFilters(recipe, filter, pantryNames)) continue;

      // ── 2. Pantry matching ────────────────────────────────────────
      final pantryMatch = _matchIngredients(recipe, pantryNames);

      // ── 3. Score ──────────────────────────────────────────────────
      final score = _computeScore(
        recipe: recipe,
        profile: profile,
        perMealCalTarget: perMealCalTarget,
        pantryMatchFraction:
            recipe.ingredients.isEmpty ? 1.0 : pantryMatch.haveCount / recipe.ingredients.length,
        filter: filter,
      );

      // ── 4. Match reasons ──────────────────────────────────────────
      final reasons = _buildMatchReasons(
        recipe: recipe,
        score: score,
        profile: profile,
        pantryMatchFraction: recipe.ingredients.isEmpty
            ? 1.0
            : pantryMatch.haveCount / recipe.ingredients.length,
      );

      ranked.add(RankedRecipe(
        recipe: recipe,
        score: score,
        pantryIngredients: pantryMatch.have,
        missingIngredients: pantryMatch.missing,
        matchReasons: reasons,
      ));
    }

    _applySortOrder(ranked, filter.sortOrder);

    return ranked;
  }

  // ------------------------------------------------------------------
  // Hard filter
  // ------------------------------------------------------------------

  bool _passesHardFilters(
    SpoonacularRecipe recipe,
    RecipeFilter filter,
    Set<String> pantryNames,
  ) {
    // Pantry-only mode: must be cookable with what we have
    if (filter.pantryOnlyMode) {
      final match = _matchIngredients(recipe, pantryNames);
      if (recipe.ingredients.isNotEmpty &&
          match.haveCount / recipe.ingredients.length < 1.0) {
        return false;
      }
    }

    // Minimum pantry match %
    if (filter.minPantryMatchPercent > 0 && recipe.ingredients.isNotEmpty) {
      final match = _matchIngredients(recipe, pantryNames);
      final pct = match.haveCount / recipe.ingredients.length * 100;
      if (pct < filter.minPantryMatchPercent) return false;
    }

    // Max ready time
    if (filter.maxReadyMinutes != null &&
        recipe.readyInMinutes > filter.maxReadyMinutes!) {
      return false;
    }

    // Calories
    final cal = recipe.nutrition.calories;
    if (filter.minCalories != null && cal < filter.minCalories!) return false;
    if (filter.maxCalories != null && cal > filter.maxCalories!) return false;

    // Macros
    if (filter.minProteinG != null &&
        recipe.nutrition.protein < filter.minProteinG!) return false;
    if (filter.maxCarbsG != null &&
        recipe.nutrition.carbs > filter.maxCarbsG!) return false;
    if (filter.maxFatG != null &&
        recipe.nutrition.fat > filter.maxFatG!) return false;

    // Dish types
    if (filter.dishTypes.isNotEmpty) {
      final have = recipe.dishTypes.map((d) => d.toLowerCase()).toSet();
      final want = filter.dishTypes.map((d) => d.toLowerCase()).toSet();
      if (have.intersection(want).isEmpty) return false;
    }

    return true;
  }

  // ------------------------------------------------------------------
  // Ingredient matching
  // ------------------------------------------------------------------

  _MatchResult _matchIngredients(
    SpoonacularRecipe recipe,
    Set<String> pantryNames,
  ) {
    final have = <String>[];
    final missing = <String>[];

    for (final ing in recipe.ingredients) {
      if (_ingredientInPantry(ing.name, pantryNames)) {
        have.add(ing.name);
      } else {
        missing.add(ing.name);
      }
    }

    // Update recipe counters in-place for display
    recipe.pantryMatchCount = have.length;
    recipe.missingIngredientCount = missing.length;

    return _MatchResult(have: have, missing: missing);
  }

  bool _ingredientInPantry(String ingredientName, Set<String> pantryNames) {
    final n = _normalise(ingredientName);
    // Exact match
    if (pantryNames.contains(n)) return true;
    // Partial match: pantry item contains ingredient name or vice versa
    for (final p in pantryNames) {
      if (p.contains(n) || n.contains(p)) return true;
    }
    return false;
  }

  Set<String> _normalisePantryNames(List<PantryItem> pantry) =>
      pantry.map((i) => _normalise(i.name)).toSet();

  String _normalise(String s) => s.toLowerCase().trim();

  // ------------------------------------------------------------------
  // Scoring
  // ------------------------------------------------------------------

  ScoreBreakdown _computeScore({
    required SpoonacularRecipe recipe,
    required UserProfileModel profile,
    required double perMealCalTarget,
    required double pantryMatchFraction,
    required RecipeFilter filter,
  }) {
    return ScoreBreakdown(
      pantryMatch: _scorePantryMatch(pantryMatchFraction),
      calorieFit: _scoreCalorieFit(recipe.nutrition.calories, perMealCalTarget),
      macroFit: _scoreMacroFit(recipe.nutrition, profile.macroTargets),
      cuisineBonus: _scoreCuisine(recipe, profile),
      cookingModeFit: _scoreCookingMode(recipe, profile.cookingMode),
      popularity: _scorePopularity(recipe),
    );
  }

  // ── Pantry match (0–40) ──────────────────────────────────────────────────

  double _scorePantryMatch(double fraction) {
    // 40 pts if all ingredients are in pantry; scales linearly
    return (fraction * 40).clamp(0, 40);
  }

  // ── Calorie fit (0–20) ───────────────────────────────────────────────────
  // Bell-curve score centred on the per-meal calorie target.
  // ±10%  → 20 pts   ±20% → 15 pts   ±50% → 5 pts   beyond → 0

  double _scoreCalorieFit(double recipeCal, double targetCal) {
    if (targetCal <= 0) return 10; // no data — neutral
    final deviation = (recipeCal - targetCal).abs() / targetCal;
    if (deviation <= 0.10) return 20;
    if (deviation <= 0.20) return 15;
    if (deviation <= 0.35) return 10;
    if (deviation <= 0.50) return 5;
    return 0;
  }

  // ── Macro fit (0–15) ─────────────────────────────────────────────────────
  // Compare per-meal protein, carbs, fat against targets derived from profile.

  double _scoreMacroFit(
      SpoonacularNutrition nutrition, MacroTargets targets) {
    // Per-meal targets = daily / 3
    final tProt = targets.proteinG / 3;
    final tCarb = targets.carbsG / 3;
    final tFat = targets.fatG / 3;

    double macroScore = 0;

    // Protein: reward being near or above target (up to 5 pts)
    if (tProt > 0) {
      final ratio = nutrition.protein / tProt;
      macroScore += _bellCurve(ratio, maxPts: 5, idealRatio: 1.0, tolerance: 0.3);
    } else {
      macroScore += 2.5;
    }

    // Carbs: reward being near target (up to 5 pts)
    if (tCarb > 0) {
      final ratio = nutrition.carbs / tCarb;
      macroScore += _bellCurve(ratio, maxPts: 5, idealRatio: 1.0, tolerance: 0.4);
    } else {
      macroScore += 2.5;
    }

    // Fat: reward not over-shooting target (up to 5 pts)
    if (tFat > 0) {
      final ratio = nutrition.fat / tFat;
      macroScore += _bellCurve(ratio, maxPts: 5, idealRatio: 0.9, tolerance: 0.4);
    } else {
      macroScore += 2.5;
    }

    return macroScore.clamp(0, 15);
  }

  double _bellCurve(double ratio,
      {required double maxPts, required double idealRatio, required double tolerance}) {
    final deviation = (ratio - idealRatio).abs();
    if (deviation <= tolerance * 0.5) return maxPts;
    if (deviation <= tolerance) return maxPts * 0.7;
    if (deviation <= tolerance * 2) return maxPts * 0.3;
    return 0;
  }

  // ── Cuisine preference (0–10) ────────────────────────────────────────────

  double _scoreCuisine(SpoonacularRecipe recipe, UserProfileModel profile) {
    if (profile.favoriteCuisines.isEmpty) return 5; // neutral bonus
    final recipeCuisines =
        recipe.cuisines.map((c) => c.toLowerCase()).toSet();
    final userCuisines =
        profile.favoriteCuisines.map((c) => c.toLowerCase()).toSet();
    if (recipeCuisines.intersection(userCuisines).isNotEmpty) return 10;
    return 0;
  }

  // ── Cooking-mode fit (0–10) ──────────────────────────────────────────────

  double _scoreCookingMode(SpoonacularRecipe recipe, CookingMode mode) {
    double score = 0;

    switch (mode) {
      case CookingMode.general:
        // No strong preference — give a neutral mid-range score
        score = 5;
        break;

      case CookingMode.quickMeals:
        // Reward fast recipes
        if (recipe.readyInMinutes <= 15) score = 10;
        else if (recipe.readyInMinutes <= 25) score = 7;
        else if (recipe.readyInMinutes <= 35) score = 4;
        else score = 1;
        break;

      case CookingMode.healthyEating:
        // Reward health score and veryHealthy flag
        if (recipe.veryHealthy) score += 5;
        final hs = recipe.healthScore ?? 50;
        score += (hs / 100 * 5).clamp(0, 5);
        break;

      case CookingMode.bulkCooking:
        // Reward recipes with many servings or longer cook time (batch-friendly)
        if (recipe.servings >= 6) score += 6;
        else if (recipe.servings >= 4) score += 4;
        else score += 1;
        if (recipe.readyInMinutes >= 45) score += 4;
        else if (recipe.readyInMinutes >= 30) score += 2;
        break;

      case CookingMode.budgetFriendly:
        if (recipe.cheap) score = 10;
        else score = 4; // unknown — neutral
        break;

      case CookingMode.gourmet:
        // Reward complexity: more ingredients, longer time
        final ingCount = recipe.ingredients.length;
        if (ingCount >= 12) score += 6;
        else if (ingCount >= 8) score += 4;
        else score += 2;
        if (recipe.readyInMinutes >= 60) score += 4;
        else if (recipe.readyInMinutes >= 40) score += 2;
        break;
    }

    return score.clamp(0, 10);
  }

  // ── Popularity (0–5) ─────────────────────────────────────────────────────

  double _scorePopularity(SpoonacularRecipe recipe) {
    double score = 0;
    // spoonacularScore is 0–100
    final ss = recipe.spoonacularScore ?? 50;
    score += (ss / 100 * 3).clamp(0, 3); // up to 3 pts

    // Health score bonus
    final hs = recipe.healthScore ?? 50;
    score += (hs / 100 * 2).clamp(0, 2); // up to 2 pts

    return score.clamp(0, 5);
  }

  // ------------------------------------------------------------------
  // Sort
  // ------------------------------------------------------------------

  void _applySortOrder(List<RankedRecipe> list, RecipeSortOrder order) {
    switch (order) {
      case RecipeSortOrder.bestMatch:
        list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
        break;
      case RecipeSortOrder.pantryMatch:
        list.sort((a, b) =>
            b.pantryMatchPercent.compareTo(a.pantryMatchPercent));
        break;
      case RecipeSortOrder.calories:
        list.sort((a, b) =>
            a.recipe.nutrition.calories.compareTo(b.recipe.nutrition.calories));
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

  // ------------------------------------------------------------------
  // Match reasons (human-readable)
  // ------------------------------------------------------------------

  List<String> _buildMatchReasons({
    required SpoonacularRecipe recipe,
    required ScoreBreakdown score,
    required UserProfileModel profile,
    required double pantryMatchFraction,
  }) {
    final reasons = <String>[];

    if (pantryMatchFraction >= 0.9) {
      reasons.add('✅ You have almost everything!');
    } else if (pantryMatchFraction >= 0.6) {
      reasons.add('🧺 ${(pantryMatchFraction * 100).round()}% of ingredients in pantry');
    }

    if (score.calorieFit >= 15) {
      reasons.add('🎯 Matches your calorie target');
    }

    if (score.macroFit >= 10) {
      reasons.add('💪 Great macro balance');
    }

    if (score.cuisineBonus == 10) {
      reasons.add('🍜 Your favourite cuisine');
    }

    if (recipe.veryHealthy) {
      reasons.add('🥗 Very healthy');
    }

    switch (profile.cookingMode) {
      case CookingMode.quickMeals:
        if (recipe.readyInMinutes <= 20) {
          reasons.add('⚡ Ready in ${recipe.readyInMinutes} min');
        }
        break;
      case CookingMode.budgetFriendly:
        if (recipe.cheap) reasons.add('💰 Budget friendly');
        break;
      case CookingMode.bulkCooking:
        if (recipe.servings >= 6) reasons.add('🍲 Great for meal prep (${recipe.servings} servings)');
        break;
      default:
        break;
    }

    if (recipe.vegan) reasons.add('🌱 Vegan');
    else if (recipe.vegetarian) reasons.add('🥬 Vegetarian');
    if (recipe.glutenFree) reasons.add('🌾 Gluten-free');
    if (recipe.dairyFree) reasons.add('🥛 Dairy-free');

    return reasons;
  }
}

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

class _MatchResult {
  final List<String> have;
  final List<String> missing;
  int get haveCount => have.length;
  _MatchResult({required this.have, required this.missing});
}