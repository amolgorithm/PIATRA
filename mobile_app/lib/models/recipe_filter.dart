// lib/models/recipe_filter.dart
//
// Encapsulates all filter + sort criteria for the recipe recommendation engine.

import 'package:flutter/foundation.dart';

enum RecipeSortOrder {
  bestMatch,      // highest ranking score
  pantryMatch,    // most pantry ingredients used
  calories,       // lowest calories first
  prepTime,       // quickest first
  healthScore,    // healthiest first
  popularity,     // most popular
}

extension RecipeSortOrderLabel on RecipeSortOrder {
  String get label {
    switch (this) {
      case RecipeSortOrder.bestMatch:
        return 'Best Match';
      case RecipeSortOrder.pantryMatch:
        return 'Uses Most Ingredients';
      case RecipeSortOrder.calories:
        return 'Lowest Calories';
      case RecipeSortOrder.prepTime:
        return 'Quickest';
      case RecipeSortOrder.healthScore:
        return 'Healthiest';
      case RecipeSortOrder.popularity:
        return 'Most Popular';
    }
  }
}

@immutable
class RecipeFilter {
  // --- Pantry matching ---
  final int minPantryMatchPercent; // 0–100, default 0

  // --- Time ---
  final int? maxReadyMinutes;

  // --- Calories ---
  final int? minCalories;
  final int? maxCalories;

  // --- Macros ---
  final double? minProteinG;
  final double? maxCarbsG;
  final double? maxFatG;

  // --- Cuisine ---
  final List<String> cuisines; // empty = any

  // --- Diet tags (Spoonacular diet params) ---
  final List<String> diets; // e.g. ['vegan', 'gluten free']

  // --- Intolerances / allergies ---
  final List<String> intolerances; // e.g. ['dairy', 'peanut']

  // --- Dish type ---
  final List<String> dishTypes; // e.g. ['breakfast', 'main course']

  // --- Sort ---
  final RecipeSortOrder sortOrder;

  // --- Show only recipes cookable with pantry ---
  final bool pantryOnlyMode;

  const RecipeFilter({
    this.minPantryMatchPercent = 0,
    this.maxReadyMinutes,
    this.minCalories,
    this.maxCalories,
    this.minProteinG,
    this.maxCarbsG,
    this.maxFatG,
    this.cuisines = const [],
    this.diets = const [],
    this.intolerances = const [],
    this.dishTypes = const [],
    this.sortOrder = RecipeSortOrder.bestMatch,
    this.pantryOnlyMode = false,
  });

  /// Build a default filter from user profile
  factory RecipeFilter.fromProfile({
    required List<String> dietaryPreferences,
    required List<String> allergies,
    required List<String> favoriteCuisines,
    required int calorieTarget,
    int? maxReadyMinutes,
  }) {
    final diets = dietaryPreferences
        .map((p) => _mapDiet(p))
        .whereType<String>()
        .toList();

    final intolerances = allergies
        .map((a) => _mapIntolerance(a))
        .whereType<String>()
        .toList();

    return RecipeFilter(
      cuisines: favoriteCuisines,
      diets: diets,
      intolerances: intolerances,
      maxCalories: (calorieTarget * 0.6).round(), // single meal ≤ 60% daily cal
      minCalories: (calorieTarget * 0.15).round(), // at least 15% (not tiny snacks)
      maxReadyMinutes: maxReadyMinutes,
      sortOrder: RecipeSortOrder.bestMatch,
    );
  }

  RecipeFilter copyWith({
    int? minPantryMatchPercent,
    int? maxReadyMinutes,
    bool clearMaxReadyMinutes = false,
    int? minCalories,
    int? maxCalories,
    double? minProteinG,
    double? maxCarbsG,
    double? maxFatG,
    List<String>? cuisines,
    List<String>? diets,
    List<String>? intolerances,
    List<String>? dishTypes,
    RecipeSortOrder? sortOrder,
    bool? pantryOnlyMode,
  }) {
    return RecipeFilter(
      minPantryMatchPercent:
          minPantryMatchPercent ?? this.minPantryMatchPercent,
      maxReadyMinutes: clearMaxReadyMinutes
          ? null
          : (maxReadyMinutes ?? this.maxReadyMinutes),
      minCalories: minCalories ?? this.minCalories,
      maxCalories: maxCalories ?? this.maxCalories,
      minProteinG: minProteinG ?? this.minProteinG,
      maxCarbsG: maxCarbsG ?? this.maxCarbsG,
      maxFatG: maxFatG ?? this.maxFatG,
      cuisines: cuisines ?? this.cuisines,
      diets: diets ?? this.diets,
      intolerances: intolerances ?? this.intolerances,
      dishTypes: dishTypes ?? this.dishTypes,
      sortOrder: sortOrder ?? this.sortOrder,
      pantryOnlyMode: pantryOnlyMode ?? this.pantryOnlyMode,
    );
  }

  static String? _mapDiet(String pref) {
    const map = {
      'vegetarian': 'vegetarian',
      'vegan': 'vegan',
      'gluten free': 'gluten free',
      'gluten-free': 'gluten free',
      'keto': 'ketogenic',
      'ketogenic': 'ketogenic',
      'paleo': 'paleo',
      'pescetarian': 'pescetarian',
      'whole30': 'whole30',
      'low fodmap': 'low fodmap',
    };
    return map[pref.toLowerCase()];
  }

  static String? _mapIntolerance(String allergy) {
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
      'tree nut': 'tree nut',
      'nuts': 'tree nut',
      'nut': 'tree nut',
    };
    return map[allergy.toLowerCase()];
  }
}