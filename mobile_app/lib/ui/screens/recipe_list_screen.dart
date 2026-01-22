import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../models/ingredient.dart';
import '../../models/nutrition.dart';
import '../widgets/recipe_card.dart';
import '../../routes/app_routes.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  // Hardcoded sample recipes
  final List<Recipe> _recipes = [
    Recipe(
      id: '1',
      name: 'Fresh Garden Salad',
      description: 'A light and refreshing salad with fresh vegetables',
      ingredients: [
        Ingredient(name: 'Lettuce', amount: '1', unit: 'head', available: true),
        Ingredient(name: 'Tomatoes', amount: '2', available: true),
        Ingredient(name: 'Cucumber', amount: '1', available: false),
        Ingredient(name: 'Olive Oil', amount: '2', unit: 'tbsp', available: true),
        Ingredient(name: 'Lemon Juice', amount: '1', unit: 'tbsp', available: false),
      ],
      steps: [
        'Wash all vegetables thoroughly',
        'Chop lettuce into bite-sized pieces',
        'Slice tomatoes and cucumber',
        'Combine in a large bowl',
        'Drizzle with olive oil and lemon juice',
        'Toss well and serve immediately',
      ],
      nutrition: Nutrition(
        calories: 250,
        protein: 8,
        carbs: 30,
        fat: 12,
      ),
      prepTime: 10,
      cookTime: 0,
      difficulty: 'Easy',
      tags: ['healthy', 'vegetarian', 'quick'],
    ),
    Recipe(
      id: '2',
      name: 'Classic Cheese Omelette',
      description: 'Fluffy omelette with melted cheese',
      ingredients: [
        Ingredient(name: 'Eggs', amount: '3', available: true),
        Ingredient(name: 'Cheese', amount: '50', unit: 'g', available: true),
        Ingredient(name: 'Butter', amount: '1', unit: 'tbsp', available: false),
        Ingredient(name: 'Salt', amount: '1', unit: 'pinch', available: true),
        Ingredient(name: 'Pepper', amount: '1', unit: 'pinch', available: true),
      ],
      steps: [
        'Beat eggs in a bowl with salt and pepper',
        'Heat butter in a non-stick pan',
        'Pour eggs into the pan',
        'Cook until edges set',
        'Add cheese to one half',
        'Fold omelette and serve',
      ],
      nutrition: Nutrition(
        calories: 320,
        protein: 24,
        carbs: 4,
        fat: 24,
      ),
      prepTime: 5,
      cookTime: 5,
      difficulty: 'Easy',
      tags: ['breakfast', 'protein'],
    ),
    Recipe(
      id: '3',
      name: 'Grilled Chicken Breast',
      description: 'Perfectly seasoned and grilled chicken',
      ingredients: [
        Ingredient(name: 'Chicken Breast', amount: '250', unit: 'g', available: true),
        Ingredient(name: 'Olive Oil', amount: '1', unit: 'tbsp', available: false),
        Ingredient(name: 'Garlic Powder', amount: '1', unit: 'tsp', available: false),
        Ingredient(name: 'Salt', amount: '1', unit: 'tsp', available: true),
        Ingredient(name: 'Pepper', amount: '1', unit: 'tsp', available: true),
      ],
      steps: [
        'Pat chicken dry with paper towels',
        'Brush with olive oil',
        'Season with salt, pepper, and garlic powder',
        'Preheat grill to medium-high heat',
        'Grill for 6-7 minutes per side',
        'Rest for 5 minutes before serving',
      ],
      nutrition: Nutrition(
        calories: 280,
        protein: 45,
        carbs: 2,
        fat: 10,
      ),
      prepTime: 10,
      cookTime: 15,
      difficulty: 'Medium',
      tags: ['healthy', 'protein', 'main-course'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          return RecipeCard(
            recipe: _recipes[index],
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.recipeDetail,
                arguments: _recipes[index],
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Recipes'),
        content: const Text(
          'Recipe filtering coming soon!\nFilter by dietary preferences, cuisine, and more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}