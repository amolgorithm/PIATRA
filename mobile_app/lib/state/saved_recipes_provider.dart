// lib/state/saved_recipes_provider.dart
//
// ChangeNotifier that wraps SavedRecipesService and exposes:
//   • savedIds  — Set<int> for instant bookmark icon state
//   • savedList — List<SavedRecipe> for the saved recipes screen
//   • toggle()  — save or unsave a recipe in one call

import 'package:flutter/foundation.dart';
import '../services/saved_recipes_service.dart';
import '../services/spoonacular_service.dart';

class SavedRecipesProvider extends ChangeNotifier {
  SavedRecipesProvider();

  Set<int> _savedIds = {};
  Set<int> get savedIds => _savedIds;

  List<SavedRecipe> _savedList = [];
  List<SavedRecipe> get savedList => _savedList;

  bool _loading = false;
  bool get loading => _loading;

  bool isSaved(int id) => _savedIds.contains(id);

  // ── Initialise: stream saved IDs in real-time ──────────────────────────────

  void init() {
    SavedRecipesService.instance.savedIdsStream().listen((ids) {
      _savedIds = ids;
      notifyListeners();
    });
  }

  // ── Toggle save / unsave ───────────────────────────────────────────────────

  Future<void> toggle(SpoonacularRecipe recipe) async {
    if (isSaved(recipe.id)) {
      _savedIds.remove(recipe.id);
      notifyListeners();
      await SavedRecipesService.instance.remove(recipe.id);
      _savedList.removeWhere((r) => r.id == recipe.id);
    } else {
      _savedIds.add(recipe.id);
      notifyListeners();
      await SavedRecipesService.instance.save(recipe);
    }
    notifyListeners();
  }

  // ── Load full saved list (for the management screen) ──────────────────────

  Future<void> loadAll() async {
    _loading = true;
    notifyListeners();
    try {
      _savedList = await SavedRecipesService.instance.loadAll();
    } catch (e) {
      debugPrint('[SavedRecipesProvider] loadAll error: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> remove(int recipeId) async {
    _savedIds.remove(recipeId);
    _savedList.removeWhere((r) => r.id == recipeId);
    notifyListeners();
    await SavedRecipesService.instance.remove(recipeId);
  }
}