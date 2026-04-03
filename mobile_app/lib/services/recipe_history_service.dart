// lib/services/recipe_history_service.dart
//
// Tracks every recipe the user has cooked (distinct from nutrition log —
// this stores the full recipe snapshot so they can easily re-cook it).
// Collection: recipe_history/{uid}/cooked/{recipeId}
//
// Uses the recipeId as the document ID so re-cooks just update the
// existing doc (increments cookCount, updates lastCookedAt).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spoonacular_service.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class CookedRecipe {
  final int recipeId;
  final String title;
  final String? image;
  final int readyInMinutes;
  final int servings;
  final double calories;
  final List<String> cuisines;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final int cookCount;
  final DateTime firstCookedAt;
  final DateTime lastCookedAt;
  final bool isFavorite;
  final String? userNote;

  const CookedRecipe({
    required this.recipeId,
    required this.title,
    this.image,
    required this.readyInMinutes,
    required this.servings,
    required this.calories,
    required this.cuisines,
    required this.vegetarian,
    required this.vegan,
    required this.glutenFree,
    required this.cookCount,
    required this.firstCookedAt,
    required this.lastCookedAt,
    this.isFavorite = false,
    this.userNote,
  });

  CookedRecipe copyWith({
    int? cookCount,
    DateTime? lastCookedAt,
    bool? isFavorite,
    String? userNote,
  }) => CookedRecipe(
    recipeId:      recipeId,
    title:         title,
    image:         image,
    readyInMinutes: readyInMinutes,
    servings:      servings,
    calories:      calories,
    cuisines:      cuisines,
    vegetarian:    vegetarian,
    vegan:         vegan,
    glutenFree:    glutenFree,
    cookCount:     cookCount     ?? this.cookCount,
    firstCookedAt: firstCookedAt,
    lastCookedAt:  lastCookedAt  ?? this.lastCookedAt,
    isFavorite:    isFavorite    ?? this.isFavorite,
    userNote:      userNote      ?? this.userNote,
  );

  Map<String, dynamic> toMap() => {
    'recipeId':      recipeId,
    'title':         title,
    'image':         image,
    'readyInMinutes': readyInMinutes,
    'servings':      servings,
    'calories':      calories,
    'cuisines':      cuisines,
    'vegetarian':    vegetarian,
    'vegan':         vegan,
    'glutenFree':    glutenFree,
    'cookCount':     cookCount,
    'firstCookedAt': Timestamp.fromDate(firstCookedAt),
    'lastCookedAt':  Timestamp.fromDate(lastCookedAt),
    'isFavorite':    isFavorite,
    'userNote':      userNote,
  };

  factory CookedRecipe.fromMap(Map<String, dynamic> m) {
    DateTime parseTs(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      return DateTime.now();
    }

    return CookedRecipe(
      recipeId:      m['recipeId'] as int? ?? 0,
      title:         m['title'] as String? ?? '',
      image:         m['image'] as String?,
      readyInMinutes: m['readyInMinutes'] as int? ?? 0,
      servings:      m['servings'] as int? ?? 1,
      calories:      (m['calories'] as num?)?.toDouble() ?? 0,
      cuisines:      List<String>.from(m['cuisines'] ?? []),
      vegetarian:    m['vegetarian'] as bool? ?? false,
      vegan:         m['vegan'] as bool? ?? false,
      glutenFree:    m['glutenFree'] as bool? ?? false,
      cookCount:     m['cookCount'] as int? ?? 1,
      firstCookedAt: parseTs(m['firstCookedAt']),
      lastCookedAt:  parseTs(m['lastCookedAt']),
      isFavorite:    m['isFavorite'] as bool? ?? false,
      userNote:      m['userNote'] as String?,
    );
  }

  factory CookedRecipe.fromSpoonacular(SpoonacularRecipe r) => CookedRecipe(
    recipeId:      r.id,
    title:         r.title,
    image:         r.image,
    readyInMinutes: r.readyInMinutes,
    servings:      r.servings,
    calories:      r.nutrition.calories,
    cuisines:      r.cuisines,
    vegetarian:    r.vegetarian,
    vegan:         r.vegan,
    glutenFree:    r.glutenFree,
    cookCount:     1,
    firstCookedAt: DateTime.now(),
    lastCookedAt:  DateTime.now(),
  );
}

// ── Service ────────────────────────────────────────────────────────────────────

class RecipeHistoryService {
  RecipeHistoryService._();
  static final RecipeHistoryService instance = RecipeHistoryService._();

  final _db = FirebaseFirestore.instance;

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
      _db.collection('recipe_history').doc(uid).collection('cooked');

  // ── Record a cook ───────────────────────────────────────────────────────────

  Future<void> recordCook(SpoonacularRecipe recipe) async {
    final uid = await _uid();
    final docRef = _col(uid).doc('${recipe.id}');
    final snap = await docRef.get();

    if (snap.exists) {
      // Increment cook count and update lastCookedAt
      await docRef.update({
        'cookCount':    FieldValue.increment(1),
        'lastCookedAt': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('[RecipeHistory] Updated cook count for: ${recipe.title}');
    } else {
      final cr = CookedRecipe.fromSpoonacular(recipe);
      await docRef.set({
        ...cr.toMap(),
        'savedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[RecipeHistory] First cook recorded: ${recipe.title}');
    }
  }

  // ── Load all cooked recipes ─────────────────────────────────────────────────

  Future<List<CookedRecipe>> loadAll({bool favoritesOnly = false}) async {
    final uid = await _uid();
    Query<Map<String, dynamic>> q = _col(uid).orderBy('lastCookedAt', descending: true);
    if (favoritesOnly) q = q.where('isFavorite', isEqualTo: true);
    final snap = await q.get();
    return snap.docs.map((d) => CookedRecipe.fromMap(d.data())).toList();
  }

  /// Most cooked, sorted by cookCount desc.
  Future<List<CookedRecipe>> loadTopCooked({int limit = 10}) async {
    final uid = await _uid();
    final snap = await _col(uid)
        .orderBy('cookCount', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => CookedRecipe.fromMap(d.data())).toList();
  }

  /// Recent cooks (for "cook again" feature).
  Future<List<CookedRecipe>> loadRecent({int limit = 10}) async {
    final uid = await _uid();
    final snap = await _col(uid)
        .orderBy('lastCookedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => CookedRecipe.fromMap(d.data())).toList();
  }

  // ── Toggle favorite ─────────────────────────────────────────────────────────

  Future<void> toggleFavorite(int recipeId, {required bool value}) async {
    final uid = await _uid();
    await _col(uid).doc('$recipeId').update({'isFavorite': value});
  }

  // ── Add/update note ─────────────────────────────────────────────────────────

  Future<void> updateNote(int recipeId, String note) async {
    final uid = await _uid();
    await _col(uid).doc('$recipeId').update({'userNote': note});
  }

  // ── Delete from history ─────────────────────────────────────────────────────

  Future<void> removeFromHistory(int recipeId) async {
    final uid = await _uid();
    await _col(uid).doc('$recipeId').delete();
  }

  // ── Check if cooked ─────────────────────────────────────────────────────────

  Future<bool> hasCooked(int recipeId) async {
    final uid = await _uid();
    final doc = await _col(uid).doc('$recipeId').get();
    return doc.exists;
  }

  // ── Stream ──────────────────────────────────────────────────────────────────

  Stream<List<CookedRecipe>> recentStream({int limit = 5}) async* {
    final uid = await _uid();
    yield* _col(uid)
        .orderBy('lastCookedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CookedRecipe.fromMap(d.data()))
            .toList());
  }
}
