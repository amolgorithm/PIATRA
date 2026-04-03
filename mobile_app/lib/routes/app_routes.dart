// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/pantry_screen.dart';
import '../ui/screens/scan_screen.dart';
import '../ui/screens/recipe_list_screen.dart';
import '../ui/screens/recipe_detail_screen.dart';
import '../ui/screens/assistant_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/feedback_form_screen.dart';
import '../ui/screens/analytics_screen.dart';
import '../ui/screens/meal_plan_screen.dart';
import '../models/recipe.dart';

class AppRoutes {
  static const String home       = '/';
  static const String pantry     = '/pantry';
  static const String scan       = '/scan';
  static const String recipes    = '/recipes';
  static const String recipeDetail = '/recipe-detail';
  static const String assistant  = '/assistant';
  static const String profile    = '/profile';
  static const String feedback   = '/feedback';
  static const String analytics  = '/analytics';
  static const String mealPlan   = '/meal-plan';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:         return MaterialPageRoute(builder: (_) => const HomeScreen());
      case pantry:       return MaterialPageRoute(builder: (_) => const PantryScreen());
      case scan:         return MaterialPageRoute(builder: (_) => const ScanScreen());
      case recipes:      return MaterialPageRoute(builder: (_) => const RecipeListScreen());
      case recipeDetail:
        final recipe = settings.arguments as Recipe?;
        return MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe));
      case assistant:    return MaterialPageRoute(builder: (_) => const AssistantScreen());
      case profile:      return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case feedback:     return MaterialPageRoute(builder: (_) => FeedbackFormScreen());
      case analytics:    return MaterialPageRoute(builder: (_) => const AnalyticsScreen());
      case mealPlan:     return MaterialPageRoute(builder: (_) => const MealPlanScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}