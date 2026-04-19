// lib/state/recipe_provider.dart
//
// Drives all recipe screens. Coordinates:
//   Spoonacular API  →  RecipeRankingEngine  →  UI
//
// Fetch strategy (three passes):
//   Pass 1 – findByIngredients with up to 20 pantry items (pantry-first discovery).
//            Run multiple batches if pantry > 20 items so we don't miss matches.
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

  bool _pantryMatchWarning = false;
  bool get pantryMatchWarning => _pantryMatchWarning;

  bool _hasFallbackSection = false;
  bool get hasFallbackSection => _hasFallbackSection;

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
    // Run in batches of 20 so large pantries (>20 items) are fully explored.
    // We cap at 3 batches (60 items) to keep API usage reasonable.
    if (pantryNames.isNotEmpty) {
      const batchSize = 20;
      const maxBatches = 3;
      final batches = <List<String>>[];

      for (int i = 0; i < pantryNames.length && batches.length < maxBatches; i += batchSize) {
        batches.add(pantryNames.skip(i).take(batchSize).toList());
      }

      for (final batch in batches) {
        try {
          final hits = await SpoonacularService.instance.findByIngredients(
            ingredients: batch,
            number: 30,
            ranking: 1,
          );
          if (hits.isNotEmpty) {
            final details = await SpoonacularService.instance
                .getRecipesBulk(hits.map((r) => r.id).toList());
            add(details);
          }
        } catch (e) {
          debugPrint('[RecipeProvider] pass1 batch error: $e');
        }
      }

      // Also run with ranking=2 (minimise missing ingredients) on the first
      // batch — this surfaces recipes where you already have MOST ingredients.
      if (pantryNames.length >= 3) {
        try {
          final hits2 = await SpoonacularService.instance.findByIngredients(
            ingredients: pantryNames.take(20).toList(),
            number: 20,
            ranking: 2,
          );
          if (hits2.isNotEmpty) {
            final details2 = await SpoonacularService.instance
                .getRecipesBulk(hits2.map((r) => r.id).toList());
            add(details2);
          }
        } catch (e) {
          debugPrint('[RecipeProvider] pass1 ranking2 error: $e');
        }
      }
    }

    // ── Pass 2: profile-tailored complexSearch ────────────────────────────
    // Use up to 10 pantry ingredients (Spoonacular cap) — rotate through
    // different slices of the pantry to maximise variety.
    try {
      // Slice A: first 10 items
      add(await SpoonacularService.instance.complexSearch(
        cuisine: _filter.cuisines,
        diet: _filter.diets,
        intolerances: _filter.intolerances,
        includeIngredients: pantryNames.take(10).toList(),
        maxReadyTime: _filter.maxReadyMinutes,
        maxCalories: _filter.maxCalories,
        minCalories: _filter.minCalories,
        minProtein: _filter.minProteinG,
        maxCarbs: _filter.maxCarbsG,
        number: 20,
      ));
    } catch (e) {
      debugPrint('[RecipeProvider] pass2a error: $e');
    }

    // Slice B: next 10 items (if pantry is large enough)
    if (pantryNames.length > 10) {
      try {
        add(await SpoonacularService.instance.complexSearch(
          cuisine: _filter.cuisines,
          diet: _filter.diets,
          intolerances: _filter.intolerances,
          includeIngredients: pantryNames.skip(10).take(10).toList(),
          maxReadyTime: _filter.maxReadyMinutes,
          maxCalories: _filter.maxCalories,
          minCalories: _filter.minCalories,
          number: 15,
        ));
      } catch (e) {
        debugPrint('[RecipeProvider] pass2b error: $e');
      }
    }

    // ── Pass 3: cuisine-only fallback (no pantry constraint) ──────────────
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