// lib/services/nutrition_history_service.dart
//
// Persists a log of meals (cooked recipes) and their nutrition to Firestore.
// Collection: nutrition_logs/{uid}/entries/{entryId}
//
// Each entry records:
//   - recipeId, recipeTitle, image
//   - macros at time of cooking (calories, protein, carbs, fat, fiber, sodium)
//   - servings consumed
//   - cookedAt timestamp
//   - tags (vegan, glutenFree, etc.)
//   - cuisines

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class NutritionLogEntry {
  final String id;
  final int recipeId;
  final String recipeTitle;
  final String? recipeImage;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sodium;
  final int servings;
  final DateTime cookedAt;
  final List<String> cuisines;
  final List<String> tags; // vegan, vegetarian, glutenFree, etc.

  const NutritionLogEntry({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    this.recipeImage,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.servings,
    required this.cookedAt,
    required this.cuisines,
    required this.tags,
  });

  double get totalCalories => calories * servings;
  double get totalProtein  => protein  * servings;
  double get totalCarbs    => carbs    * servings;
  double get totalFat      => fat      * servings;

  Map<String, dynamic> toMap() => {
    'recipeId':     recipeId,
    'recipeTitle':  recipeTitle,
    'recipeImage':  recipeImage,
    'calories':     calories,
    'protein':      protein,
    'carbs':        carbs,
    'fat':          fat,
    'fiber':        fiber,
    'sodium':       sodium,
    'servings':     servings,
    'cookedAt':     Timestamp.fromDate(cookedAt),
    'cuisines':     cuisines,
    'tags':         tags,
  };

  factory NutritionLogEntry.fromMap(String id, Map<String, dynamic> m) {
    DateTime cookedAt = DateTime.now();
    final raw = m['cookedAt'];
    if (raw is Timestamp) cookedAt = raw.toDate();

    return NutritionLogEntry(
      id:           id,
      recipeId:     m['recipeId'] as int? ?? 0,
      recipeTitle:  m['recipeTitle'] as String? ?? '',
      recipeImage:  m['recipeImage'] as String?,
      calories:     (m['calories'] as num?)?.toDouble() ?? 0,
      protein:      (m['protein']  as num?)?.toDouble() ?? 0,
      carbs:        (m['carbs']    as num?)?.toDouble() ?? 0,
      fat:          (m['fat']      as num?)?.toDouble() ?? 0,
      fiber:        (m['fiber']    as num?)?.toDouble() ?? 0,
      sodium:       (m['sodium']   as num?)?.toDouble() ?? 0,
      servings:     m['servings']  as int? ?? 1,
      cookedAt:     cookedAt,
      cuisines:     List<String>.from(m['cuisines'] ?? []),
      tags:         List<String>.from(m['tags'] ?? []),
    );
  }
}

// ── Daily summary convenience model ───────────────────────────────────────────

class DailySummary {
  final DateTime date;
  final List<NutritionLogEntry> entries;

  DailySummary({required this.date, required this.entries});

  double get calories => entries.fold(0, (s, e) => s + e.totalCalories);
  double get protein  => entries.fold(0, (s, e) => s + e.totalProtein);
  double get carbs    => entries.fold(0, (s, e) => s + e.totalCarbs);
  double get fat      => entries.fold(0, (s, e) => s + e.totalFat);
  int    get mealCount => entries.length;
}

// ── Service ────────────────────────────────────────────────────────────────────

class NutritionHistoryService {
  NutritionHistoryService._();
  static final NutritionHistoryService instance = NutritionHistoryService._();

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
      _db.collection('nutrition_logs').doc(uid).collection('entries');

  // ── Log a meal ──────────────────────────────────────────────────────────────

  Future<NutritionLogEntry> logMeal({
    required int recipeId,
    required String recipeTitle,
    String? recipeImage,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    double sodium = 0,
    int servings = 1,
    List<String> cuisines = const [],
    List<String> tags = const [],
  }) async {
    final uid = await _uid();
    final entry = NutritionLogEntry(
      id:          '',
      recipeId:    recipeId,
      recipeTitle: recipeTitle,
      recipeImage: recipeImage,
      calories:    calories,
      protein:     protein,
      carbs:       carbs,
      fat:         fat,
      fiber:       fiber,
      sodium:      sodium,
      servings:    servings,
      cookedAt:    DateTime.now(),
      cuisines:    cuisines,
      tags:        tags,
    );

    final ref = await _col(uid).add({
      ...entry.toMap(),
      'loggedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[NutritionHistory] Logged meal: $recipeTitle (${ref.id})');
    return NutritionLogEntry.fromMap(ref.id, entry.toMap());
  }

  // ── Delete a log entry ──────────────────────────────────────────────────────

  Future<void> deleteEntry(String entryId) async {
    final uid = await _uid();
    await _col(uid).doc(entryId).delete();
  }

  // ── Load entries ────────────────────────────────────────────────────────────

  /// Load all entries in a date range, newest first.
  Future<List<NutritionLogEntry>> loadRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final uid = await _uid();
    final snap = await _col(uid)
        .where('cookedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('cookedAt', isLessThanOrEqualTo:    Timestamp.fromDate(to))
        .orderBy('cookedAt', descending: true)
        .get();

    return snap.docs
        .map((d) => NutritionLogEntry.fromMap(d.id, d.data()))
        .toList();
  }

  /// Load last N days.
  Future<List<NutritionLogEntry>> loadLastDays(int days) async {
    final now  = DateTime.now();
    final from = now.subtract(Duration(days: days));
    return loadRange(from: from, to: now);
  }

  /// Stream of today's entries (real-time).
  Stream<List<NutritionLogEntry>> todayStream() async* {
    final uid  = await _uid();
    final now  = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to   = from.add(const Duration(days: 1));

    yield* _col(uid)
        .where('cookedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('cookedAt', isLessThan: Timestamp.fromDate(to))
        .orderBy('cookedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NutritionLogEntry.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Aggregations ────────────────────────────────────────────────────────────

  /// Group entries by day and return daily summaries (newest first).
  List<DailySummary> groupByDay(List<NutritionLogEntry> entries) {
    final map = <String, List<NutritionLogEntry>>{};
    for (final e in entries) {
      final key = '${e.cookedAt.year}-${e.cookedAt.month}-${e.cookedAt.day}';
      (map[key] ??= []).add(e);
    }
    final summaries = map.entries.map((kv) {
      final parts = kv.key.split('-').map(int.parse).toList();
      return DailySummary(
        date:    DateTime(parts[0], parts[1], parts[2]),
        entries: kv.value,
      );
    }).toList();
    summaries.sort((a, b) => b.date.compareTo(a.date));
    return summaries;
  }

  /// Cuisine frequency map from entries.
  Map<String, int> cuisineFrequency(List<NutritionLogEntry> entries) {
    final map = <String, int>{};
    for (final e in entries) {
      for (final c in e.cuisines) {
        map[c] = (map[c] ?? 0) + 1;
      }
    }
    return map;
  }

  /// Most-cooked recipes (by recipeId frequency).
  List<MapEntry<String, int>> topRecipes(List<NutritionLogEntry> entries, {int top = 5}) {
    final map = <int, String>{};
    final freq = <int, int>{};
    for (final e in entries) {
      map[e.recipeId] = e.recipeTitle;
      freq[e.recipeId] = (freq[e.recipeId] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(top)
        .map((e) => MapEntry(map[e.key] ?? 'Unknown', e.value))
        .toList();
  }
}
