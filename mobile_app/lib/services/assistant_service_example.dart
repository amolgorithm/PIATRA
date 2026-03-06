import 'package:http/http.dart' as http;
import 'dart:convert';

/// Example service showing how to use the context-aware AI assistant
class AssistantService {
  static const String _backendUrl = 'http://10.0.2.2:8000/api/assistant';

  /// Send a chat message with user context for personalized responses
  static Future<String> sendChatMessage({
    required String userId,
    required String message,
    String? conversationContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'context': conversationContext ?? '',
          'user_id': userId,  // This enables context-aware responses
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['response'] as String? ?? 'No response received.';
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to get response: $e');
    }
  }

  /// Get nutrition advice personalized to user's diet and health goals
  static Future<String> getNutritionAdvice({
    required String userId,
    required String query,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/nutrition-advice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'user_id': userId,  // Includes dietary preferences and allergies
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['response'] as String? ?? 'No response received.';
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to get nutrition advice: $e');
    }
  }

  /// Get recipe suggestions based on available pantry items and preferences
  static Future<String> getRecipeSuggestions({
    required String userId,
    required List<String> ingredients,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/recipe-suggestions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ingredients': ingredients,
          'user_id': userId,  // Includes pantry inventory and dietary constraints
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['response'] as String? ?? 'No response received.';
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to get recipe suggestions: $e');
    }
  }
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

/// Example 1: Simple chat with context awareness
Future<void> exampleChatWithContext() async {
  final userId = "user_123";  // From authentication
  final userMessage = "What can I make for dinner?";

  try {
    final response = await AssistantService.sendChatMessage(
      userId: userId,
      message: userMessage,
    );
    print("Assistant: $response");
    // Response will be aware of user's pantry, dietary preferences, allergies
  } catch (e) {
    print("Error: $e");
  }
}

/// Example 2: Nutrition advice considering user profile
Future<void> exampleNutritionAdvice() async {
  final userId = "user_123";
  final query = "What should I eat to gain muscle?";

  try {
    final response = await AssistantService.getNutritionAdvice(
      userId: userId,
      query: query,
    );
    print("Nutrition Advice: $response");
    // Response considers dietary preferences and allergies
  } catch (e) {
    print("Error: $e");
  }
}

/// Example 3: Recipe suggestions using pantry inventory
Future<void> exampleRecipeSuggestions() async {
  final userId = "user_123";
  final ingredients = ["chicken", "rice", "garlic"];

  try {
    final response = await AssistantService.getRecipeSuggestions(
      userId: userId,
      ingredients: ingredients,
    );
    print("Recipe Suggestions: $response");
    // Response will:
    // - Use items in user's pantry
    // - Respect dietary preferences
    // - Avoid allergens
    // - Consider cooking skill level
  } catch (e) {
    print("Error: $e");
  }
}

/// Example 4: Multi-turn conversation with history
Future<void> exampleConversationFlow(String userId) async {
  String conversationHistory = "";

  // User's first message
  final firstResponse = await AssistantService.sendChatMessage(
    userId: userId,
    message: "I have chicken and rice. What can I make?",
  );
  conversationHistory += "User: I have chicken and rice. What can I make?\n";
  conversationHistory += "Assistant: $firstResponse\n\n";
  print("Assistant: $firstResponse\n");

  // Follow-up with context
  final secondResponse = await AssistantService.sendChatMessage(
    userId: userId,
    message: "Can you make it spicy?",
    conversationContext: conversationHistory,
  );
  conversationHistory += "User: Can you make it spicy?\n";
  conversationHistory += "Assistant: $secondResponse\n\n";
  print("Assistant: $secondResponse\n");
}
