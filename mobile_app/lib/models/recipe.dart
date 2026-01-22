import 'ingredient.dart';
import 'nutrition.dart';

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final Nutrition nutrition;
  final int prepTime; // in minutes
  final int cookTime; // in minutes
  final String difficulty;
  final String? imageUrl;
  final List<String> tags;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.prepTime,
    required this.cookTime,
    this.difficulty = 'Medium',
    this.imageUrl,
    this.tags = const [],
  });

  int get totalTime => prepTime + cookTime;

  int get availableIngredientsCount {
    return ingredients.where((i) => i.available).length;
  }

  double get ingredientMatchPercentage {
    if (ingredients.isEmpty) return 0;
    return (availableIngredientsCount / ingredients.length) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'steps': steps,
      'nutrition': nutrition.toMap(),
      'prepTime': prepTime,
      'cookTime': cookTime,
      'difficulty': difficulty,
      'imageUrl': imageUrl,
      'tags': tags,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      ingredients: (map['ingredients'] as List<dynamic>)
          .map((i) => Ingredient.fromMap(i as Map<String, dynamic>))
          .toList(),
      steps: List<String>.from(map['steps'] as List<dynamic>),
      nutrition: Nutrition.fromMap(map['nutrition'] as Map<String, dynamic>),
      prepTime: map['prepTime'] as int,
      cookTime: map['cookTime'] as int,
      difficulty: map['difficulty'] as String? ?? 'Medium',
      imageUrl: map['imageUrl'] as String?,
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? []),
    );
  }
}