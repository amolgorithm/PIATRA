// lib/services/spoonacular_service.dart
//
// Spoonacular API integration for:
//  - Searching recipes by pantry ingredients
//  - Fetching full recipe details (nutrition, steps, ingredients)
//  - Searching by cuisine, diet, intolerances
//
// API docs: https://spoonacular.com/food-api/docs

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/env_config.dart';

// ---------------------------------------------------------------------------
// Data models returned by Spoonacular
// ---------------------------------------------------------------------------

class SpoonacularIngredient {
  final int id;
  final String name;
  final String originalName;
  final double amount;
  final String unit;
  final String? image;
  final bool? inPantry; // set locally after matching

  SpoonacularIngredient({
    required this.id,
    required this.name,
    required this.originalName,
    required this.amount,
    required this.unit,
    this.image,
    this.inPantry,
  });

  factory SpoonacularIngredient.fromJson(Map<String, dynamic> j) =>
      SpoonacularIngredient(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        originalName: j['originalName'] as String? ?? j['name'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        unit: j['unit'] as String? ?? '',
        image: j['image'] as String?,
      );
}

class SpoonacularNutrient {
  final String name;
  final double amount;
  final String unit;
  final double percentOfDailyNeeds;

  SpoonacularNutrient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.percentOfDailyNeeds,
  });

  factory SpoonacularNutrient.fromJson(Map<String, dynamic> j) =>
      SpoonacularNutrient(
        name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(),
        unit: j['unit'] as String? ?? '',
        percentOfDailyNeeds: (j['percentOfDailyNeeds'] as num?)?.toDouble() ?? 0,
      );
}

class SpoonacularNutrition {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final List<SpoonacularNutrient> nutrients;

  SpoonacularNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.nutrients,
  });

  factory SpoonacularNutrition.fromJson(Map<String, dynamic> j) {
    final nutrients = (j['nutrients'] as List<dynamic>?)
            ?.map((n) => SpoonacularNutrient.fromJson(n as Map<String, dynamic>))
            .toList() ??
        [];

    double get(String name) => nutrients
        .firstWhere((n) => n.name == name,
            orElse: () => SpoonacularNutrient(
                name: name, amount: 0, unit: '', percentOfDailyNeeds: 0))
        .amount;

    return SpoonacularNutrition(
      calories: get('Calories'),
      protein: get('Protein'),
      carbs: get('Carbohydrates'),
      fat: get('Fat'),
      fiber: get('Fiber'),
      sugar: get('Sugar'),
      sodium: get('Sodium'),
      nutrients: nutrients,
    );
  }

  factory SpoonacularNutrition.empty() => SpoonacularNutrition(
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        fiber: 0,
        sugar: 0,
        sodium: 0,
        nutrients: [],
      );
}

class SpoonacularStep {
  final int number;
  final String step;
  final List<String> ingredients;
  final List<String> equipment;
  final int? lengthMinutes; // not always present in spoonacular's data

  SpoonacularStep({
    required this.number,
    required this.step,
    required this.ingredients,
    required this.equipment,
    this.lengthMinutes,
  });

  factory SpoonacularStep.fromJson(Map<String, dynamic> j) =>
      SpoonacularStep(
        number: (j['number'] as num).toInt(),
        step: j['step'] as String,
        ingredients: (j['ingredients'] as List<dynamic>?)
                ?.map((i) => (i as Map)['name'].toString())
                .toList() ??
            [],
        equipment: (j['equipment'] as List<dynamic>?)
                ?.map((e) => (e as Map)['name'].toString())
                .toList() ??
            [],
        lengthMinutes: (j['length'] as Map<String, dynamic>?)?['number'] != null
            ? ((j['length'] as Map<String, dynamic>)['number'] as num).toInt()
            : null,
      );

  // spoonacular only gives per-step timing on some recipes. when it's
  // missing, fall back to a rough guess from the instruction text, still
  // better than pretending every step takes the same length of time
  double estimateDuration() {
    if (lengthMinutes != null) return lengthMinutes!.toDouble();
    final lower = step.toLowerCase();
    if (lower.contains('bake') || lower.contains('roast') || lower.contains('simmer')) return 20;
    if (lower.contains('marinate') || lower.contains('chill') || lower.contains('rest')) return 15;
    if (lower.contains('boil')) return 10;
    return 5;
  }

  // rough mapping from spoonacular's equipment list to a kitchen resource,
  // used by the batch-cook scheduler to figure out what's competing with what
  String estimateResource() {
    final eq = equipment.map((e) => e.toLowerCase()).join(' ');
    if (eq.contains('oven')) return 'oven';
    if (eq.contains('stove') ||
        eq.contains('pan') ||
        eq.contains('pot') ||
        eq.contains('skillet') ||
        eq.contains('wok')) {
      return 'stove';
    }
    return 'hands';
  }
}

/// Full recipe as returned by Spoonacular's /recipes/{id}/information endpoint
class SpoonacularRecipe {
  final int id;
  final String title;
  final String? image;
  final int readyInMinutes;
  final int servings;
  final String? sourceUrl;
  final String? summary;
  final List<String> cuisines;
  final List<String> dishTypes;
  final List<String> diets;
  final List<String> occasions;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool dairyFree;
  final bool veryHealthy;
  final bool cheap;
  final bool veryPopular;
  final int? healthScore;
  final double? spoonacularScore;
  final double? pricePerServing; // dollars, converted from spoonacular's cents
  final List<SpoonacularIngredient> ingredients;
  final List<SpoonacularStep> steps;
  final SpoonacularNutrition nutrition;

  // Set locally by the ranking engine
  int pantryMatchCount = 0;
  int missingIngredientCount = 0;
  double rankingScore = 0;

  SpoonacularRecipe({
    required this.id,
    required this.title,
    this.image,
    required this.readyInMinutes,
    required this.servings,
    this.sourceUrl,
    this.summary,
    required this.cuisines,
    required this.dishTypes,
    required this.diets,
    required this.occasions,
    required this.vegetarian,
    required this.vegan,
    required this.glutenFree,
    required this.dairyFree,
    required this.veryHealthy,
    required this.cheap,
    required this.veryPopular,
    this.healthScore,
    this.spoonacularScore,
    this.pricePerServing,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
  });

  double get pantryMatchPercent =>
      ingredients.isEmpty ? 0 : pantryMatchCount / ingredients.length * 100;

  factory SpoonacularRecipe.fromJson(Map<String, dynamic> j) {
    // Parse analyzedInstructions → steps
    final steps = <SpoonacularStep>[];
    final instructions =
        j['analyzedInstructions'] as List<dynamic>? ?? [];
    for (final block in instructions) {
      final stepsList =
          (block as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
      for (final s in stepsList) {
        steps.add(SpoonacularStep.fromJson(s as Map<String, dynamic>));
      }
    }

    return SpoonacularRecipe(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String,
      image: j['image'] as String?,
      readyInMinutes: (j['readyInMinutes'] as num?)?.toInt() ?? 30,
      servings: (j['servings'] as num?)?.toInt() ?? 2,
      sourceUrl: j['sourceUrl'] as String?,
      summary: j['summary'] as String?,
      cuisines: List<String>.from(j['cuisines'] as List? ?? []),
      dishTypes: List<String>.from(j['dishTypes'] as List? ?? []),
      diets: List<String>.from(j['diets'] as List? ?? []),
      occasions: List<String>.from(j['occasions'] as List? ?? []),
      vegetarian: j['vegetarian'] as bool? ?? false,
      vegan: j['vegan'] as bool? ?? false,
      glutenFree: j['glutenFree'] as bool? ?? false,
      dairyFree: j['dairyFree'] as bool? ?? false,
      veryHealthy: j['veryHealthy'] as bool? ?? false,
      cheap: j['cheap'] as bool? ?? false,
      veryPopular: j['veryPopular'] as bool? ?? false,
      healthScore: (j['healthScore'] as num?)?.toInt(),
      spoonacularScore: (j['spoonacularScore'] as num?)?.toDouble(),
      // spoonacular gives this in cents, per serving, already computed for us
      pricePerServing: (j['pricePerServing'] as num?)?.toDouble() != null
          ? (j['pricePerServing'] as num).toDouble() / 100
          : null,
      ingredients: (j['extendedIngredients'] as List<dynamic>?)
              ?.map((i) => SpoonacularIngredient.fromJson(
                  i as Map<String, dynamic>))
              .toList() ??
          [],
      steps: steps,
      nutrition: j['nutrition'] != null
          ? SpoonacularNutrition.fromJson(
              j['nutrition'] as Map<String, dynamic>)
          : SpoonacularNutrition.empty(),
    );
  }
}

/// Lightweight search result from /recipes/findByIngredients
class SpoonacularSearchResult {
  final int id;
  final String title;
  final String? image;
  final int usedIngredientCount;
  final int missedIngredientCount;
  final List<String> usedIngredients;
  final List<String> missedIngredients;
  final double likes;

  SpoonacularSearchResult({
    required this.id,
    required this.title,
    this.image,
    required this.usedIngredientCount,
    required this.missedIngredientCount,
    required this.usedIngredients,
    required this.missedIngredients,
    required this.likes,
  });

  factory SpoonacularSearchResult.fromJson(Map<String, dynamic> j) =>
      SpoonacularSearchResult(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        image: j['image'] as String?,
        usedIngredientCount: (j['usedIngredientCount'] as num?)?.toInt() ?? 0,
        missedIngredientCount: (j['missedIngredientCount'] as num?)?.toInt() ?? 0,
        usedIngredients: (j['usedIngredients'] as List<dynamic>?)
                ?.map((i) => (i as Map)['name'].toString())
                .toList() ??
            [],
        missedIngredients: (j['missedIngredients'] as List<dynamic>?)
                ?.map((i) => (i as Map)['name'].toString())
                .toList() ??
            [],
        likes: (j['likes'] as num?)?.toDouble() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class SpoonacularService {
  SpoonacularService._();
  static final SpoonacularService instance = SpoonacularService._();

  static const String _baseUrl = 'https://api.spoonacular.com';

  // API key is loaded from mobile_app/.env  →  SPOONACULAR_API_KEY=your_key_here
  // Free tier: 150 points/day.  Each recipe info call costs 1 point.
  // findByIngredients costs 1 point per recipe returned.
  static String get _apiKey => EnvConfig.spoonacularApiKey;

  static bool get _hasKey => _apiKey.isNotEmpty;

  // ------------------------------------------------------------------
  // Search by pantry ingredients
  // ------------------------------------------------------------------

  /// Returns lightweight search results sorted by ingredient match.
  /// [ingredients] – names of pantry items (max ~20 for URL length)
  /// [number]      – results to return (1-100, default 10)
  /// [ranking]     – 1 = maximise used ingredients, 2 = minimise missing
  Future<List<SpoonacularSearchResult>> findByIngredients({
    required List<String> ingredients,
    int number = 20,
    int ranking = 1,
    bool ignorePantry = false,
  }) async {
    if (ingredients.isEmpty || !_hasKey) return [];

    final ingredientStr = ingredients.take(20).join(',+');
    final uri = Uri.parse(
      '$_baseUrl/recipes/findByIngredients'
      '?apiKey=$_apiKey'
      '&ingredients=$ingredientStr'
      '&number=$number'
      '&ranking=$ranking'
      '&ignorePantry=$ignorePantry',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((j) =>
                SpoonacularSearchResult.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint(
            '[Spoonacular] findByIngredients error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[Spoonacular] findByIngredients exception: $e');
      return [];
    }
  }

  // ------------------------------------------------------------------
  // Complex search (supports diet, cuisine, intolerances, nutrition)
  // ------------------------------------------------------------------

  /// Full-featured search.  Returns list of [SpoonacularRecipe] with nutrition
  /// already included (addRecipeNutrition=true saves an extra API call).
  Future<List<SpoonacularRecipe>> complexSearch({
    String? query,
    List<String> cuisine = const [],
    List<String> diet = const [],
    List<String> intolerances = const [],
    List<String> includeIngredients = const [],
    int? maxReadyTime,
    int? minCalories,
    int? maxCalories,
    double? minProtein,
    double? minCarbs,
    double? maxCarbs,
    double? minFat,
    double? maxFat,
    int number = 20,
    int offset = 0,
  }) async {
    if (!_hasKey) return [];

    final params = <String, String>{
      'apiKey': _apiKey,
      'number': number.toString(),
      'offset': offset.toString(),
      'addRecipeNutrition': 'true',
      'addRecipeInformation': 'true',
      'fillIngredients': 'true',
    };

    if (query != null && query.isNotEmpty) params['query'] = query;
    if (cuisine.isNotEmpty) params['cuisine'] = cuisine.join(',');
    if (diet.isNotEmpty) params['diet'] = diet.join(',');
    if (intolerances.isNotEmpty) params['intolerances'] = intolerances.join(',');
    if (includeIngredients.isNotEmpty) {
      params['includeIngredients'] = includeIngredients.take(10).join(',');
    }
    if (maxReadyTime != null) params['maxReadyTime'] = maxReadyTime.toString();
    if (minCalories != null) params['minCalories'] = minCalories.toString();
    if (maxCalories != null) params['maxCalories'] = maxCalories.toString();
    if (minProtein != null) params['minProtein'] = minProtein.toString();
    if (minCarbs != null) params['minCarbs'] = minCarbs.toString();
    if (maxCarbs != null) params['maxCarbs'] = maxCarbs.toString();
    if (minFat != null) params['minFat'] = minFat.toString();
    if (maxFat != null) params['maxFat'] = maxFat.toString();

    final uri = Uri.parse('$_baseUrl/recipes/complexSearch')
        .replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as List<dynamic>? ?? [];
        return results
            .map((j) =>
                SpoonacularRecipe.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint(
            '[Spoonacular] complexSearch error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[Spoonacular] complexSearch exception: $e');
      return [];
    }
  }

  // ------------------------------------------------------------------
  // Fetch full recipe details
  // ------------------------------------------------------------------

  Future<SpoonacularRecipe?> getRecipeInformation(int recipeId) async {
    if (!_hasKey) return null;

    final uri = Uri.parse(
      '$_baseUrl/recipes/$recipeId/information'
      '?apiKey=$_apiKey&includeNutrition=true',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return SpoonacularRecipe.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        debugPrint(
            '[Spoonacular] getRecipeInformation error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[Spoonacular] getRecipeInformation exception: $e');
      return null;
    }
  }

  /// Bulk fetch up to 100 recipes in one API call.
  Future<List<SpoonacularRecipe>> getRecipesBulk(List<int> ids) async {
    if (ids.isEmpty || !_hasKey) return [];
    final idStr = ids.take(100).join(',');
    final uri = Uri.parse(
      '$_baseUrl/recipes/informationBulk'
      '?apiKey=$_apiKey&ids=$idStr&includeNutrition=true',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((j) =>
                SpoonacularRecipe.fromJson(j as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint(
            '[Spoonacular] getRecipesBulk error ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[Spoonacular] getRecipesBulk exception: $e');
      return [];
    }
  }

  // ------------------------------------------------------------------
  // Dietary tag mapping helpers
  // ------------------------------------------------------------------

  /// Map user dietary preference strings → Spoonacular diet param values
  static String? mapDietPreference(String pref) {
    const map = {
      'vegetarian': 'vegetarian',
      'vegan': 'vegan',
      'gluten free': 'gluten free',
      'gluten-free': 'gluten free',
      'ketogenic': 'ketogenic',
      'keto': 'ketogenic',
      'paleo': 'paleo',
      'primal': 'primal',
      'low fodmap': 'low fodmap',
      'whole30': 'whole30',
      'pescetarian': 'pescetarian',
    };
    return map[pref.toLowerCase()];
  }

  /// Map user allergy strings → Spoonacular intolerance param values
  static String? mapIntolerance(String allergy) {
    const map = {
      'dairy': 'dairy',
      'lactose': 'dairy',
      'egg': 'egg',
      'eggs': 'egg',
      'gluten': 'gluten',
      'wheat': 'wheat',
      'peanut': 'peanut',
      'peanuts': 'peanut',
      'sesame': 'sesame',
      'seafood': 'seafood',
      'shellfish': 'shellfish',
      'soy': 'soy',
      'sulfite': 'sulfite',
      'tree nut': 'tree nut',
      'tree nuts': 'tree nut',
      'nut': 'tree nut',
      'nuts': 'tree nut',
    };
    return map[allergy.toLowerCase()];
  }
}