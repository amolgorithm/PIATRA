// lib/state/recipe_provider.dart
//
// Drives all recipe screens. Coordinates:
//   Spoonacular API  →  RecipeRankingEngine  →  UI
//
// Fetch strategy (two passes):
//   Pass 1 – findByIngredients (pantry-first discovery)
//   Pass 2 – complexSearch with active diet/cuisine/intolerance params
//   Pass 3 – if cuisine filter is active AND Pass 1+2 yield no cuisine matches,
//            run a cuisine-only complexSearch without pantry constraints so
//            the user always gets *some* results in their chosen cuisine.

import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';
import '../models/recipe_filter.dart';
import '../models/user_profile_model.dart';
import '../services/spoonacular_service.dart';
import '../services/recipe_ranking_engine.dart';
import '../services/pantry_service.dart';

export '../services/recipe_ranking_engine.dart' show RankedRecipe, RankingResult;

enum RecipeLoadState { idle, loading, loaded, error }

class RecipeProvider extends ChangeNotifier {
  RecipeProvider();

  // ── State ──────────────────────────────────────────────────────────────────

  RecipeLoadState _loadState = RecipeLoadState.idle;
  RecipeLoadState get loadState => _loadState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Full ranked list (cuisine group first, then fallback group).
  List<RankedRecipe> _rankedRecipes = [];
  List<RankedRecipe> get rankedRecipes => _rankedRecipes;

  /// Set by the engine: true when top results have poor pantry coverage.
  bool _pantryMatchWarning = false;
  bool get pantryMatchWarning => _pantryMatchWarning;

  /// True when a cuisine filter is active and there are non-cuisine recipes
  /// at the bottom of the list as "other suggestions".
  bool _hasFallbackSection = false;
  bool get hasFallbackSection => _hasFallbackSection;

  /// Index where the fallback (non-cuisine) section begins.
  int _fallbackStartIndex = 0;
  int get fallbackStartIndex => _fallbackStartIndex;

  RecipeFilter _filter = const RecipeFilter();
  RecipeFilter get filter => _filter;

  UserProfileModel? _profile;
  List<PantryItem> _pantry = [];

  bool get isLoading => _loadState == RecipeLoadState.loading;
  bool get hasResults => _rankedRecipes.isNotEmpty;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> loadRecommendations({
    required UserProfileModel profile,
    RecipeFilter? filterOverride,
  }) async {
    _profile = profile;
    _pantry = await PantryService.instance.getAllItems();

    _filter = filterOverride ??
        RecipeFilter.fromProfile(
          dietaryPreferences: profile.dietaryPreferences,
          allergies: profile.allergies,
          favoriteCuisines: profile.favoriteCuisines,
          calorieTarget: profile.calorieTarget,
          maxReadyMinutes: profile.cookingMode.maxCookMinutes,
        );

    await _fetch();
  }

  Future<void> applyFilter(RecipeFilter newFilter) async {
    _filter = newFilter;
    if (_rankedRecipes.isEmpty && _loadState != RecipeLoadState.loading) {
      await _fetch();
    } else {
      _rerank();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_profile == null) return;
    _rankedRecipes = [];
    await _fetch();
  }

  // ── Private fetch ──────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (_profile == null) {
      _loadState = RecipeLoadState.error;
      _errorMessage = 'No user profile loaded.';
      notifyListeners();
      return;
    }

    _loadState = RecipeLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    final pantryNames = _pantry.map((i) => i.name).toList();
    final combined = <SpoonacularRecipe>[];
    final seen = <int>{};

    void add(List<SpoonacularRecipe> list) {
      for (final r in list) {
        if (seen.add(r.id)) combined.add(r);
      }
    }

    // ── Pass 1: pantry-first discovery ────────────────────────────────────
    if (pantryNames.isNotEmpty) {
      try {
        final hits = await SpoonacularService.instance.findByIngredients(
          ingredients: pantryNames,
          number: 30,
          ranking: 1,
        );
        if (hits.isNotEmpty) {
          final details = await SpoonacularService.instance
              .getRecipesBulk(hits.map((r) => r.id).toList());
          add(details);
        }
      } catch (e) {
        debugPrint('[RecipeProvider] pass1 error: $e');
      }
    }

    // ── Pass 2: profile-tailored complexSearch ────────────────────────────
    try {
      add(await SpoonacularService.instance.complexSearch(
        cuisine: _filter.cuisines,
        diet: _filter.diets,
        intolerances: _filter.intolerances,
        includeIngredients: pantryNames.take(5).toList(),
        maxReadyTime: _filter.maxReadyMinutes,
        maxCalories: _filter.maxCalories,
        minCalories: _filter.minCalories,
        minProtein: _filter.minProteinG,
        maxCarbs: _filter.maxCarbsG,
        number: 20,
      ));
    } catch (e) {
      debugPrint('[RecipeProvider] pass2 error: $e');
    }

    // ── Pass 3: cuisine-only fallback (no pantry constraint) ──────────────
    // Runs when a cuisine filter is active but Pass 1+2 returned no or very
    // few recipes that actually match that cuisine. This ensures the user
    // always sees results in their selected cuisine even if pantry is sparse.
    if (_filter.cuisines.isNotEmpty) {
      final cuisineMatchCount = combined
          .where((r) => r.cuisines
              .map((c) => c.toLowerCase())
              .toSet()
              .intersection(_filter.cuisines.map((c) => c.toLowerCase()).toSet())
              .isNotEmpty)
          .length;

      if (cuisineMatchCount < 5) {
        try {
          add(await SpoonacularService.instance.complexSearch(
            cuisine: _filter.cuisines,
            diet: _filter.diets,
            intolerances: _filter.intolerances,
            number: 15,
            // No includeIngredients — fetch the best in that cuisine regardless
          ));
        } catch (e) {
          debugPrint('[RecipeProvider] pass3 cuisine fallback error: $e');
        }
      }
    }

    // ── Rank ──────────────────────────────────────────────────────────────
    try {
      final result = RecipeRankingEngine.instance.rankAndFilter(
        recipes: combined,
        profile: _profile!,
        pantry: _pantry,
        filter: _filter,
      );
      _applyResult(result);
      _loadState = RecipeLoadState.loaded;
    } catch (e) {
      debugPrint('[RecipeProvider] ranking error: $e');
      _errorMessage = e.toString();
      _loadState = RecipeLoadState.error;
    }

    notifyListeners();
  }

  void _rerank() {
    if (_profile == null) return;
    final result = RecipeRankingEngine.instance.rankAndFilter(
      recipes: _rankedRecipes.map((r) => r.recipe).toList(),
      profile: _profile!,
      pantry: _pantry,
      filter: _filter,
    );
    _applyResult(result);
  }

  void _applyResult(RankingResult result) {
    _rankedRecipes = result.recipes;
    _pantryMatchWarning = result.pantryMatchWarning;
    _hasFallbackSection = result.hasFallbackSection;
    _fallbackStartIndex = result.fallbackStartIndex;
  }
}