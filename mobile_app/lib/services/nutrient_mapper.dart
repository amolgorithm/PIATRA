// lib/services/nutrient_mapper.dart
//
// The optimizer backend expects nutrient keys like "protein_g", "sodium_mg".
// Spoonacular gives back a flat list of {name, amount, unit} where the name
// is a display string ("Protein", "Vitamin B12", "Saturated Fat") and the
// unit varies per nutrient. This file is the translation layer between the
// two, so the optimizer actually gets real numbers instead of an empty dict.

import 'spoonacular_service.dart';

class NutrientMapper {
  NutrientMapper._();

  // spoonacular's display name -> our key. only mapping what the optimizer
  // plan actually uses for now (protein floor, sodium ceiling, calories for
  // sanity checks). add more here as new nutrient targets get added, the
  // solver already handles missing keys fine, it just treats them as 0.
  static const Map<String, String> _keyMap = {
    'Calories': 'calories',
    'Protein': 'protein_g',
    'Carbohydrates': 'carbs_g',
    'Fat': 'fat_g',
    'Saturated Fat': 'saturated_fat_g',
    'Fiber': 'fiber_g',
    'Sugar': 'sugar_g',
    'Sodium': 'sodium_mg',
    'Iron': 'iron_mg',
    'Calcium': 'calcium_mg',
    'Vitamin C': 'vitamin_c_mg',
    'Vitamin B12': 'vitamin_b12_ug',
    'Potassium': 'potassium_mg',
    'Cholesterol': 'cholesterol_mg',
  };

  // spoonacular is mostly consistent on units per nutrient but this isn't
  // guaranteed across every recipe, so normalize instead of trusting it.
  // everything here converts to whatever unit is baked into the key name
  // above (protein_g means grams, sodium_mg means milligrams, etc).
  static double _normalize(String unit, double amount) {
    switch (unit.toLowerCase()) {
      case 'g':
        return amount;
      case 'mg':
        return amount;
      case 'µg':
      case 'mcg':
      case 'ug':
        return amount;
      case 'kg':
        return amount * 1000; // -> g
      default:
        return amount; // kcal, IU, % etc, just pass through
    }
  }

  /// Turns spoonacular's nutrient list into the flat dict the /api/optimize
  /// endpoint wants. Anything not in _keyMap is dropped, not because it's
  /// useless, just because the backend doesn't have a target for it yet.
  static Map<String, double> toOptimizerNutrients(SpoonacularNutrition n) {
    final result = <String, double>{};

    for (final nutrient in n.nutrients) {
      final key = _keyMap[nutrient.name];
      if (key == null) continue;
      result[key] = _normalize(nutrient.unit, nutrient.amount);
    }

    // the four headline macros are on the model directly too, fill them in
    // as a fallback in case the raw nutrients list is missing one of them
    result.putIfAbsent('calories', () => n.calories);
    result.putIfAbsent('protein_g', () => n.protein);
    result.putIfAbsent('carbs_g', () => n.carbs);
    result.putIfAbsent('fat_g', () => n.fat);
    result.putIfAbsent('fiber_g', () => n.fiber);
    result.putIfAbsent('sugar_g', () => n.sugar);
    result.putIfAbsent('sodium_mg', () => n.sodium);

    return result;
  }
}