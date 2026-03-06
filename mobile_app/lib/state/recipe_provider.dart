// lib/state/recipe_provider.dart
//
// ChangeNotifier that drives the Recipe screens.
// Coordinates: Spoonacular API  →  Ranking Engine  →  UI

import 'package:flutter/foundation.dart';
import '../models/pantry_item.dart';
import '../models/recipe_filter.dart';
import '../models/user_profile_model.dart';
import '../services/spoonacular_service.dart';
import '../services/recipe_ranking_engine.dart';
import '../services/pantry_service.dart';

enum RecipeLoadState { idle, loading, loaded, error }

class RecipeProvider extends ChangeNotifier {
  RecipeProvider();

  // ── State ──────────────────────────────────────────────────────────────────
  RecipeLoadState _loadState = RecipeLoadState.idle;
  RecipeLoadState get loadState => _loadState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<RankedRecipe> _rankedRecipes = [];
  List<RankedRecipe> get rankedRecipes => _rankedRecipes;

  RecipeFilter _filter = const RecipeFilter();
  RecipeFilter get filter => _filter;

  UserProfileModel? _profile;
  List<PantryItem> _pantry = [];

  bool get isLoading => _loadState == RecipeLoadState.loading;
  bool get hasResults => _rankedRecipes.isNotEmpty;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once when the screen opens (or on pull-to-refresh).
  Future<void> loadRecommendations({
    required UserProfileModel profile,
    RecipeFilter? filterOverride,
  }) async {
    _profile = profile;
    _pantry = await PantryService.instance.getAllItems();

    // Build a default filter from the user profile if none is provided
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

  /// Re-rank + filter the already-loaded recipes when only the filter changes
  /// (avoids spending API quota on every filter tweak).
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

  // ── Private ────────────────────────────────────────────────────────────────

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

    // ── Step 1: findByIngredients + bulk detail fetch ──────────────────────
    try {
      if (pantryNames.isNotEmpty) {
        final searchResults = await SpoonacularService.instance.findByIngredients(
          ingredients: pantryNames,
          number: 30,
          ranking: 1,
        );
        if (searchResults.isNotEmpty) {
          final ids = searchResults.map((r) => r.id).toList();
          final details = await SpoonacularService.instance.getRecipesBulk(ids);
          for (final r in details) {
            if (seen.add(r.id)) combined.add(r);
          }
        }
      }
    } catch (e) {
      debugPrint('[RecipeProvider] findByIngredients error: $e');
    }

    // ── Step 2: complexSearch tailored to profile ──────────────────────────
    try {
      final profileRecipes = await SpoonacularService.instance.complexSearch(
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
      );
      for (final r in profileRecipes) {
        if (seen.add(r.id)) combined.add(r);
      }
    } catch (e) {
      debugPrint('[RecipeProvider] complexSearch error: $e');
    }

    // ── Step 3: Rank whatever we got ──────────────────────────────────────
    try {
      _rankedRecipes = RecipeRankingEngine.instance.rankAndFilter(
        recipes: combined,
        profile: _profile!,
        pantry: _pantry,
        filter: _filter,
      );
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
    _rankedRecipes = RecipeRankingEngine.instance.rankAndFilter(
      recipes: _rankedRecipes.map((r) => r.recipe).toList(),
      profile: _profile!,
      pantry: _pantry,
      filter: _filter,
    );
  }
}