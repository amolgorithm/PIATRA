// lib/models/user_profile_model.dart

import 'package:flutter/material.dart';

enum CookingMode {
  general,        // profile_screen.dart default fallback
  quickMeals,
  healthyEating,
  bulkCooking,
  budgetFriendly,
  gourmet,
}

extension CookingModeExtension on CookingMode {
  String get label {
    switch (this) {
      case CookingMode.general:        return 'General';
      case CookingMode.quickMeals:     return 'Quick Meals';
      case CookingMode.healthyEating:  return 'Healthy Eating';
      case CookingMode.bulkCooking:    return 'Bulk Cooking';
      case CookingMode.budgetFriendly: return 'Budget Friendly';
      case CookingMode.gourmet:        return 'Gourmet';
    }
  }

  String get emoji {
    switch (this) {
      case CookingMode.general:        return '🍽';
      case CookingMode.quickMeals:     return '⚡';
      case CookingMode.healthyEating:  return '🥗';
      case CookingMode.bulkCooking:    return '🍲';
      case CookingMode.budgetFriendly: return '💰';
      case CookingMode.gourmet:        return '👨‍🍳';
    }
  }

  String get tagline {
    switch (this) {
      case CookingMode.general:        return 'Cook anything, your way';
      case CookingMode.quickMeals:     return 'On the table in 20 minutes';
      case CookingMode.healthyEating:  return 'Nourish your body every day';
      case CookingMode.bulkCooking:    return 'Cook once, eat all week';
      case CookingMode.budgetFriendly: return 'Delicious meals on a budget';
      case CookingMode.gourmet:        return 'Restaurant-quality at home';
    }
  }

  String get description {
    switch (this) {
      case CookingMode.general:
        return 'No restrictions — discover all kinds of recipes tailored to your pantry.';
      case CookingMode.quickMeals:
        return 'Recipes ready in 20 minutes or less, perfect for busy weeknights.';
      case CookingMode.healthyEating:
        return 'Balanced, nutritious meals aligned with your calorie and macro goals.';
      case CookingMode.bulkCooking:
        return 'High-yield recipes great for meal prep and batch cooking.';
      case CookingMode.budgetFriendly:
        return 'Make the most of affordable ingredients without sacrificing flavour.';
      case CookingMode.gourmet:
        return 'Elevated recipes with complex flavours and techniques.';
    }
  }

  IconData get icon {
    switch (this) {
      case CookingMode.general:        return Icons.restaurant_menu_rounded;
      case CookingMode.quickMeals:     return Icons.bolt_rounded;
      case CookingMode.healthyEating:  return Icons.eco_rounded;
      case CookingMode.bulkCooking:    return Icons.set_meal_rounded;
      case CookingMode.budgetFriendly: return Icons.savings_rounded;
      case CookingMode.gourmet:        return Icons.star_rounded;
    }
  }

  List<int> get gradientColors {
    switch (this) {
      case CookingMode.general:        return [0xFF9C88FF, 0xFF8C7AE6];
      case CookingMode.quickMeals:     return [0xFF6C63FF, 0xFF5B54E8];
      case CookingMode.healthyEating:  return [0xFF00D4AA, 0xFF00B894];
      case CookingMode.bulkCooking:    return [0xFFFF6B6B, 0xFFEE5A6F];
      case CookingMode.budgetFriendly: return [0xFFFFB800, 0xFFFFA000];
      case CookingMode.gourmet:        return [0xFF4E9FF9, 0xFF3A8EE8];
    }
  }

  int get defaultCalorieTarget {
    switch (this) {
      case CookingMode.general:        return 2000;
      case CookingMode.quickMeals:     return 1800;
      case CookingMode.healthyEating:  return 1800;
      case CookingMode.bulkCooking:    return 2400;
      case CookingMode.budgetFriendly: return 2000;
      case CookingMode.gourmet:        return 2200;
    }
  }

  List<String> get defaultDietaryPreferences {
    switch (this) {
      case CookingMode.general:        return [];
      case CookingMode.quickMeals:     return [];
      case CookingMode.healthyEating:  return ['Low Fat', 'High Protein'];
      case CookingMode.bulkCooking:    return ['High Protein'];
      case CookingMode.budgetFriendly: return [];
      case CookingMode.gourmet:        return [];
    }
  }

  List<String> get suggestedTags {
    switch (this) {
      case CookingMode.general:        return ['Any cuisine', 'Flexible', 'Pantry-based'];
      case CookingMode.quickMeals:     return ['≤ 20 min', 'One-pan', 'No-cook'];
      case CookingMode.healthyEating:  return ['Low calorie', 'High protein', 'Whole foods'];
      case CookingMode.bulkCooking:    return ['4+ servings', 'Freezer-friendly', 'Meal prep'];
      case CookingMode.budgetFriendly: return ['Cheap', 'Pantry staples', 'Filling'];
      case CookingMode.gourmet:        return ['Complex', 'Fine dining', 'Seasonal'];
    }
  }

  /// Max cook time preference in minutes (used by recipe ranking engine)
  int get maxCookMinutes {
    switch (this) {
      case CookingMode.general:        return 60;
      case CookingMode.quickMeals:     return 20;
      case CookingMode.healthyEating:  return 45;
      case CookingMode.bulkCooking:    return 120;
      case CookingMode.budgetFriendly: return 60;
      case CookingMode.gourmet:        return 180;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class MacroTargets {
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MacroTargets({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MacroTargets.fromCalories(int calories) {
    return MacroTargets(
      proteinG: (calories * 0.30) / 4,
      carbsG: (calories * 0.40) / 4,
      fatG: (calories * 0.30) / 9,
    );
  }

  Map<String, dynamic> toMap() => {
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };

  factory MacroTargets.fromMap(Map<String, dynamic> m) => MacroTargets(
        proteinG: (m['proteinG'] as num).toDouble(),
        carbsG: (m['carbsG'] as num).toDouble(),
        fatG: (m['fatG'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class UserProfileModel {
  final String uid;
  final String displayName;
  final CookingMode cookingMode;
  final int calorieTarget;
  final MacroTargets macroTargets;
  final List<String> favoriteCuisines;
  final List<String> dietaryPreferences;
  final List<String> allergies;

  const UserProfileModel({
    required this.uid,
    required this.displayName,
    required this.cookingMode,
    required this.calorieTarget,
    required this.macroTargets,
    required this.favoriteCuisines,
    required this.dietaryPreferences,
    required this.allergies,
  });

  factory UserProfileModel.defaultProfile() {
    const calories = 2000;
    return UserProfileModel(
      uid: '',
      displayName: 'Chef',
      cookingMode: CookingMode.general,
      calorieTarget: calories,
      macroTargets: MacroTargets.fromCalories(calories),
      favoriteCuisines: [],
      dietaryPreferences: [],
      allergies: [],
    );
  }

  UserProfileModel copyWith({
    String? uid,
    String? displayName,
    CookingMode? cookingMode,
    int? calorieTarget,
    MacroTargets? macroTargets,
    List<String>? favoriteCuisines,
    List<String>? dietaryPreferences,
    List<String>? allergies,
  }) {
    return UserProfileModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      cookingMode: cookingMode ?? this.cookingMode,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      macroTargets: macroTargets ?? this.macroTargets,
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      allergies: allergies ?? this.allergies,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'cookingMode': cookingMode.index,
        'calorieTarget': calorieTarget,
        'macroTargets': macroTargets.toMap(),
        'favoriteCuisines': favoriteCuisines,
        'dietaryPreferences': dietaryPreferences,
        'allergies': allergies,
      };

  factory UserProfileModel.fromMap(Map<String, dynamic> m) => UserProfileModel(
        uid: m['uid'] as String? ?? '',
        displayName: m['displayName'] as String? ?? 'Chef',
        cookingMode: CookingMode.values[m['cookingMode'] as int? ?? 0],
        calorieTarget: m['calorieTarget'] as int? ?? 2000,
        macroTargets: m['macroTargets'] != null
            ? MacroTargets.fromMap(m['macroTargets'] as Map<String, dynamic>)
            : MacroTargets.fromCalories(m['calorieTarget'] as int? ?? 2000),
        favoriteCuisines:
            List<String>.from(m['favoriteCuisines'] as List? ?? []),
        dietaryPreferences:
            List<String>.from(m['dietaryPreferences'] as List? ?? []),
        allergies: List<String>.from(m['allergies'] as List? ?? []),
      );
}