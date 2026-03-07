// lib/services/saved_recipes_service.dart
//
// Persists saved/bookmarked recipes to Firestore.
// Collection: saved_recipes/{uid}/items/{recipeId}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/spoonacular_service.dart';

class SavedRecipesService {
  SavedRecipesService._();
  static final SavedRecipesService instance = SavedRecipesService._();

  final _db = FirebaseFirestore.instance;

  // ── UID resolution (same pattern as ProfileFirebaseService) ────────────────

  Future<String> _uid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;
    final prefs = await SharedPreferences.getInstance();
    var local = prefs.getString('piatra_local_uid');
    if (local == null) {
      local = 'local_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('piatra_local_uid', local);
    }
    return local;
  }

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('saved_recipes').doc(uid).collection('items');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Save a recipe. Idempotent — saving the same recipe twice is a no-op.
  Future<void> save(SpoonacularRecipe recipe) async {
    final uid = await _uid();
    await _col(uid).doc('${recipe.id}').set({
      ...recipe.toMap(),
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a saved recipe.
  Future<void> remove(int recipeId) async {
    final uid = await _uid();
    await _col(uid).doc('$recipeId').delete();
  }

  /// Load all saved recipes, newest first.
  Future<List<SavedRecipe>> loadAll() async {
    final uid = await _uid();
    final snap = await _col(uid)
        .orderBy('savedAt', descending: true)
        .get();
    return snap.docs.map((d) => SavedRecipe.fromMap(d.data())).toList();
  }

  /// Check if a specific recipe is saved.
  Future<bool> isSaved(int recipeId) async {
    final uid = await _uid();
    final doc = await _col(uid).doc('$recipeId').get();
    return doc.exists;
  }

  /// Stream of saved recipe IDs — for real-time bookmark icon updates.
  Stream<Set<int>> savedIdsStream() async* {
    final uid = await _uid();
    yield* _col(uid).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()['id'] as int).toSet(),
        );
  }
}

// ── SavedRecipe model ──────────────────────────────────────────────────────────

class SavedRecipe {
  final int id;
  final String title;
  final String? image;
  final int readyInMinutes;
  final int servings;
  final double calories;
  final List<String> cuisines;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final DateTime? savedAt;

  const SavedRecipe({
    required this.id,
    required this.title,
    this.image,
    required this.readyInMinutes,
    required this.servings,
    required this.calories,
    required this.cuisines,
    required this.vegetarian,
    required this.vegan,
    required this.glutenFree,
    this.savedAt,
  });

  factory SavedRecipe.fromMap(Map<String, dynamic> m) {
    DateTime? saved;
    final raw = m['savedAt'];
    if (raw is Timestamp) saved = raw.toDate();
    return SavedRecipe(
      id: m['id'] as int? ?? 0,
      title: m['title'] as String? ?? '',
      image: m['image'] as String?,
      readyInMinutes: m['readyInMinutes'] as int? ?? 0,
      servings: m['servings'] as int? ?? 1,
      calories: (m['calories'] as num?)?.toDouble() ?? 0,
      cuisines: List<String>.from(m['cuisines'] ?? []),
      vegetarian: m['vegetarian'] as bool? ?? false,
      vegan: m['vegan'] as bool? ?? false,
      glutenFree: m['glutenFree'] as bool? ?? false,
      savedAt: saved,
    );
  }
}

// ── Extension on SpoonacularRecipe to serialise for Firestore ─────────────────

extension SpoonacularRecipeFirestore on SpoonacularRecipe {
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'image': image,
        'readyInMinutes': readyInMinutes,
        'servings': servings,
        'calories': nutrition.calories,
        'cuisines': cuisines,
        'vegetarian': vegetarian,
        'vegan': vegan,
        'glutenFree': glutenFree,
      };
}