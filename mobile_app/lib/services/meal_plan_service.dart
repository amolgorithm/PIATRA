// lib/services/meal_plan_service.dart
//
// Manages weekly meal plans and derived shopping lists.
// Collections:
//   meal_plans/{uid}/weeks/{weekKey}   → MealPlan document
//   shopping_lists/{uid}/lists/{listId} → ShoppingList document
//
// weekKey format: "YYYY-WW" (ISO week number)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spoonacular_service.dart';
import 'optimizer_service.dart' show PlanItem;

// ── Enums ──────────────────────────────────────────────────────────────────────

enum MealSlot { breakfast, lunch, dinner, snack }

extension MealSlotLabel on MealSlot {
  String get label {
    switch (this) {
      case MealSlot.breakfast: return 'Breakfast';
      case MealSlot.lunch:     return 'Lunch';
      case MealSlot.dinner:    return 'Dinner';
      case MealSlot.snack:     return 'Snack';
    }
  }
  IconData get slotIcon {
    switch (this) {
      case MealSlot.breakfast: return Icons.wb_twilight_rounded;
      case MealSlot.lunch:     return Icons.wb_sunny_outlined;
      case MealSlot.dinner:    return Icons.nightlight_outlined;
      case MealSlot.snack:     return Icons.apple_rounded;  // or Icons.local_dining_rounded
    }
  }
  int get order {
    switch (this) {
      case MealSlot.breakfast: return 0;
      case MealSlot.lunch:     return 1;
      case MealSlot.dinner:    return 2;
      case MealSlot.snack:     return 3;
    }
  }
}

// ── Models ─────────────────────────────────────────────────────────────────────

/// A single planned meal (one slot on one day).
class PlannedMeal {
  final int recipeId;
  final String title;
  final String? image;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int readyInMinutes;
  final int servings;
  final MealSlot slot;
  final List<PlannedIngredient> ingredients;

  const PlannedMeal({
    required this.recipeId,
    required this.title,
    this.image,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.readyInMinutes,
    required this.servings,
    required this.slot,
    required this.ingredients,
  });

  factory PlannedMeal.fromSpoonacular(SpoonacularRecipe r, MealSlot slot) =>
      PlannedMeal(
        recipeId:       r.id,
        title:          r.title,
        image:          r.image,
        calories:       r.nutrition.calories,
        protein:        r.nutrition.protein,
        carbs:          r.nutrition.carbs,
        fat:            r.nutrition.fat,
        readyInMinutes: r.readyInMinutes,
        servings:       r.servings,
        slot:           slot,
        ingredients:    r.ingredients
            .map((i) => PlannedIngredient(
                  name:   i.name,
                  amount: i.amount,
                  unit:   i.unit,
                ))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
    'recipeId':       recipeId,
    'title':          title,
    'image':          image,
    'calories':       calories,
    'protein':        protein,
    'carbs':          carbs,
    'fat':            fat,
    'readyInMinutes': readyInMinutes,
    'servings':       servings,
    'slot':           slot.index,
    'ingredients':    ingredients.map((i) => i.toMap()).toList(),
  };

  factory PlannedMeal.fromMap(Map<String, dynamic> m) => PlannedMeal(
    recipeId:       m['recipeId'] as int? ?? 0,
    title:          m['title'] as String? ?? '',
    image:          m['image'] as String?,
    calories:       (m['calories'] as num?)?.toDouble() ?? 0,
    protein:        (m['protein']  as num?)?.toDouble() ?? 0,
    carbs:          (m['carbs']    as num?)?.toDouble() ?? 0,
    fat:            (m['fat']      as num?)?.toDouble() ?? 0,
    readyInMinutes: m['readyInMinutes'] as int? ?? 0,
    servings:       m['servings'] as int? ?? 1,
    slot:           MealSlot.values[m['slot'] as int? ?? 2],
    ingredients:    (m['ingredients'] as List<dynamic>?)
        ?.map((i) => PlannedIngredient.fromMap(i as Map<String, dynamic>))
        .toList() ?? [],
  );
}

/// A single ingredient on a planned meal.
class PlannedIngredient {
  final String name;
  final double amount;
  final String unit;

  const PlannedIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {
    'name': name, 'amount': amount, 'unit': unit,
  };

  factory PlannedIngredient.fromMap(Map<String, dynamic> m) => PlannedIngredient(
    name:   m['name']   as String? ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    unit:   m['unit']   as String? ?? '',
  );
}

/// One day in a meal plan (0 = Monday … 6 = Sunday).
class MealPlanDay {
  final int dayIndex; // 0-6, Monday=0
  final Map<MealSlot, PlannedMeal> meals;

  const MealPlanDay({required this.dayIndex, required this.meals});

  String get dayName => const [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ][dayIndex];

  String get shortName => const [
    'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
  ][dayIndex];

  double get totalCalories => meals.values.fold(0, (s, m) => s + m.calories);
  double get totalProtein  => meals.values.fold(0, (s, m) => s + m.protein);
  double get totalCarbs    => meals.values.fold(0, (s, m) => s + m.carbs);
  double get totalFat      => meals.values.fold(0, (s, m) => s + m.fat);

  Map<String, dynamic> toMap() => {
    'dayIndex': dayIndex,
    'meals': meals.map((slot, meal) => MapEntry(slot.index.toString(), meal.toMap())),
  };

  factory MealPlanDay.fromMap(Map<String, dynamic> m) {
    final rawMeals = m['meals'] as Map<String, dynamic>? ?? {};
    final meals = <MealSlot, PlannedMeal>{};
    rawMeals.forEach((key, value) {
      final slot = MealSlot.values[int.parse(key)];
      meals[slot] = PlannedMeal.fromMap(value as Map<String, dynamic>);
    });
    return MealPlanDay(
      dayIndex: m['dayIndex'] as int? ?? 0,
      meals:    meals,
    );
  }
}

/// A full week meal plan.
class MealPlan {
  final String id; // weekKey e.g. "2025-W03"
  final DateTime weekStart; // Monday of that week
  final List<MealPlanDay> days;
  final String? name; // user-set name, e.g. "Healthy Week"
  final DateTime createdAt;

  const MealPlan({
    required this.id,
    required this.weekStart,
    required this.days,
    this.name,
    required this.createdAt,
  });

  double get avgDailyCalories {
    if (days.isEmpty) return 0;
    return days.fold(0.0, (s, d) => s + d.totalCalories) / days.length;
  }

  int get totalMeals => days.fold(0, (s, d) => s + d.meals.length);

  Map<String, dynamic> toMap() => {
    'weekKey':   id,
    'weekStart': Timestamp.fromDate(weekStart),
    'days':      days.map((d) => d.toMap()).toList(),
    'name':      name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory MealPlan.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseTs(dynamic raw) =>
        raw is Timestamp ? raw.toDate() : DateTime.now();

    return MealPlan(
      id:         id,
      weekStart:  parseTs(m['weekStart']),
      days:       (m['days'] as List<dynamic>?)
          ?.map((d) => MealPlanDay.fromMap(d as Map<String, dynamic>))
          .toList() ?? [],
      name:       m['name'] as String?,
      createdAt:  parseTs(m['createdAt']),
    );
  }
}

// ── Shopping list models ────────────────────────────────────────────────────────

class ShoppingItem {
  final String name;
  final double amount;
  final String unit;
  bool isChecked;
  final List<String> usedInRecipes; // recipe titles that need this ingredient

  ShoppingItem({
    required this.name,
    required this.amount,
    required this.unit,
    this.isChecked = false,
    required this.usedInRecipes,
  });

  Map<String, dynamic> toMap() => {
    'name':           name,
    'amount':         amount,
    'unit':           unit,
    'isChecked':      isChecked,
    'usedInRecipes':  usedInRecipes,
  };

  factory ShoppingItem.fromMap(Map<String, dynamic> m) => ShoppingItem(
    name:          m['name'] as String? ?? '',
    amount:        (m['amount'] as num?)?.toDouble() ?? 0,
    unit:          m['unit'] as String? ?? '',
    isChecked:     m['isChecked'] as bool? ?? false,
    usedInRecipes: List<String>.from(m['usedInRecipes'] ?? []),
  );
}

class ShoppingList {
  final String id;
  final String weekKey; // which meal plan this was generated from
  final String? title;
  final List<ShoppingItem> items;
  final List<String> alreadyInPantry; // item names the user already has
  final DateTime createdAt;

  const ShoppingList({
    required this.id,
    required this.weekKey,
    this.title,
    required this.items,
    required this.alreadyInPantry,
    required this.createdAt,
  });

  int get checkedCount  => items.where((i) => i.isChecked).length;
  int get totalCount    => items.length;
  double get progress   => totalCount == 0 ? 0 : checkedCount / totalCount;

  Map<String, dynamic> toMap() => {
    'weekKey':         weekKey,
    'title':           title,
    'items':           items.map((i) => i.toMap()).toList(),
    'alreadyInPantry': alreadyInPantry,
    'createdAt':       Timestamp.fromDate(createdAt),
  };

  factory ShoppingList.fromMap(String id, Map<String, dynamic> m) =>
      ShoppingList(
        id:              id,
        weekKey:         m['weekKey'] as String? ?? '',
        title:           m['title'] as String?,
        items:           (m['items'] as List<dynamic>?)
            ?.map((i) => ShoppingItem.fromMap(i as Map<String, dynamic>))
            .toList() ?? [],
        alreadyInPantry: List<String>.from(m['alreadyInPantry'] ?? []),
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

// ── Service ────────────────────────────────────────────────────────────────────

class MealPlanService {
  MealPlanService._();
  static final MealPlanService instance = MealPlanService._();

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

  CollectionReference<Map<String, dynamic>> _plansCol(String uid) =>
      _db.collection('meal_plans').doc(uid).collection('weeks');

  CollectionReference<Map<String, dynamic>> _listsCol(String uid) =>
      _db.collection('shopping_lists').doc(uid).collection('lists');

  // ── Week key helpers ────────────────────────────────────────────────────────

  static String weekKey(DateTime date) {
    final monday = _mondayOf(date);
    final week   = _isoWeekNumber(monday);
    return '${monday.year}-W${week.toString().padLeft(2, '0')}';
  }

  static DateTime _mondayOf(DateTime date) {
    final diff = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - diff);
  }

  static int _isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    return woy < 1 ? 52 : (woy > 52 ? 1 : woy);
  }

  static DateTime currentWeekStart() => _mondayOf(DateTime.now());

  // ── Save / update plan ──────────────────────────────────────────────────────

  Future<void> savePlan(MealPlan plan) async {
    final uid = await _uid();
    await _plansCol(uid).doc(plan.id).set({
      ...plan.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[MealPlan] Saved plan: ${plan.id}');
  }

  Future<void> addMealToDay({
    required String planId,
    required int dayIndex,
    required PlannedMeal meal,
  }) async {
    final uid = await _uid();
    // Load, mutate, save
    final plan = await loadPlan(planId);
    if (plan == null) return;

    final updatedDays = List<MealPlanDay>.from(plan.days);
    final dayIdx = updatedDays.indexWhere((d) => d.dayIndex == dayIndex);

    if (dayIdx == -1) {
      updatedDays.add(MealPlanDay(dayIndex: dayIndex, meals: {meal.slot: meal}));
    } else {
      final updatedMeals = Map<MealSlot, PlannedMeal>.from(updatedDays[dayIdx].meals);
      updatedMeals[meal.slot] = meal;
      updatedDays[dayIdx] = MealPlanDay(dayIndex: dayIndex, meals: updatedMeals);
    }
    updatedDays.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final updatedPlan = MealPlan(
      id: plan.id,
      weekStart: plan.weekStart,
      days: updatedDays,
      name: plan.name,
      createdAt: plan.createdAt,
    );
    await savePlan(updatedPlan);
  }

  Future<void> removeMealFromDay({
    required String planId,
    required int dayIndex,
    required MealSlot slot,
  }) async {
    final uid  = await _uid();
    final plan = await loadPlan(planId);
    if (plan == null) return;

    final updatedDays = plan.days.map((d) {
      if (d.dayIndex != dayIndex) return d;
      final m = Map<MealSlot, PlannedMeal>.from(d.meals)..remove(slot);
      return MealPlanDay(dayIndex: dayIndex, meals: m);
    }).toList();

    await savePlan(MealPlan(
      id: plan.id, weekStart: plan.weekStart,
      days: updatedDays, name: plan.name, createdAt: plan.createdAt,
    ));
  }

  // ── Apply an optimized plan ─────────────────────────────────────────────────

  /// Takes what the LP/QP solver picked and drops it into real day/slot spots
  /// on the current week. Servings come back as a float (e.g. 3.37 servings
  /// of lentil soup), round to the nearest whole meal since you can't cook
  /// a third of a bowl, and cap at 7 since that's the max the solver was told
  /// to consider per recipe anyway.
  Future<MealPlan> applyOptimizedPlan({
    required List<PlanItem> items,
    required Map<String, SpoonacularRecipe> recipesById,
  }) async {
    final plan = await getOrCreateCurrentWeekPlan();

    final occurrences = <SpoonacularRecipe>[];
    for (final item in items) {
      final recipe = recipesById[item.id];
      if (recipe == null) continue; // shouldn't happen, id came from our own candidates
      final count = item.servings.round().clamp(1, 7);
      occurrences.addAll(List.filled(count, recipe));
    }

    // dinner fills first since that's the slot people plan around most,
    // then spill into lunch, breakfast, snack as the list runs out
    const slotPriority = [
      MealSlot.dinner,
      MealSlot.lunch,
      MealSlot.breakfast,
      MealSlot.snack,
    ];

    var i = 0;
    outer:
    for (final slot in slotPriority) {
      for (var day = 0; day < 7; day++) {
        if (i >= occurrences.length) break outer;
        await addMealToDay(
          planId: plan.id,
          dayIndex: day,
          meal: PlannedMeal.fromSpoonacular(occurrences[i], slot),
        );
        i++;
      }
    }

    return await loadPlan(plan.id) ?? plan;
  }

  // ── Load plans ──────────────────────────────────────────────────────────────

  Future<MealPlan?> loadPlan(String planId) async {
    final uid  = await _uid();
    final snap = await _plansCol(uid).doc(planId).get();
    if (!snap.exists || snap.data() == null) return null;
    return MealPlan.fromMap(planId, snap.data()!);
  }

  Future<MealPlan?> loadCurrentWeekPlan() async =>
      loadPlan(weekKey(DateTime.now()));

  Future<List<MealPlan>> loadAllPlans() async {
    final uid  = await _uid();
    final snap = await _plansCol(uid)
        .orderBy('weekStart', descending: true)
        .limit(12)
        .get();
    return snap.docs.map((d) => MealPlan.fromMap(d.id, d.data())).toList();
  }

  /// Create an empty plan for the current week (or return existing).
  Future<MealPlan> getOrCreateCurrentWeekPlan() async {
    final key  = weekKey(DateTime.now());
    final existing = await loadPlan(key);
    if (existing != null) return existing;

    final plan = MealPlan(
      id:        key,
      weekStart: currentWeekStart(),
      days:      [],
      createdAt: DateTime.now(),
    );
    await savePlan(plan);
    return plan;
  }

  // ── Delete plan ─────────────────────────────────────────────────────────────

  Future<void> deletePlan(String planId) async {
    final uid = await _uid();
    await _plansCol(uid).doc(planId).delete();
  }

  // ── Shopping list ───────────────────────────────────────────────────────────

  /// Generate a shopping list from a meal plan, minus pantry items.
  Future<ShoppingList> generateShoppingList({
    required MealPlan plan,
    required List<String> pantryItemNames,
  }) async {
    // Aggregate all ingredients across the plan
    final raw = <String, _AggItem>{};

    for (final day in plan.days) {
      for (final meal in day.meals.values) {
        for (final ing in meal.ingredients) {
          final key = ing.name.toLowerCase().trim();
          if (raw.containsKey(key)) {
            raw[key]!.amount += ing.amount;
            if (!raw[key]!.recipes.contains(meal.title)) {
              raw[key]!.recipes.add(meal.title);
            }
          } else {
            raw[key] = _AggItem(
              name:    ing.name,
              amount:  ing.amount,
              unit:    ing.unit,
              recipes: [meal.title],
            );
          }
        }
      }
    }

    // Separate pantry-available vs missing
    final pantryLower = pantryItemNames.map((n) => n.toLowerCase()).toSet();
    final alreadyHave = <String>[];
    final toShop      = <ShoppingItem>[];

    for (final item in raw.values) {
      final key = item.name.toLowerCase().trim();
      final inPantry = pantryLower.any((p) => p.contains(key) || key.contains(p));
      if (inPantry) {
        alreadyHave.add(item.name);
      } else {
        toShop.add(ShoppingItem(
          name:          item.name,
          amount:        item.amount,
          unit:          item.unit,
          usedInRecipes: item.recipes,
        ));
      }
    }

    toShop.sort((a, b) => a.name.compareTo(b.name));

    final shoppingList = ShoppingList(
      id:              '',
      weekKey:         plan.id,
      title:           'Week of ${_fmtDate(plan.weekStart)}',
      items:           toShop,
      alreadyInPantry: alreadyHave,
      createdAt:       DateTime.now(),
    );

    // Persist to Firestore
    final uid = await _uid();
    final ref = await _listsCol(uid).add({
      ...shoppingList.toMap(),
      'savedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[MealPlan] Shopping list saved: ${ref.id}');
    return ShoppingList.fromMap(ref.id, shoppingList.toMap());
  }

  Future<ShoppingList?> loadShoppingListForWeek(String weekKey) async {
    final uid  = await _uid();
    final snap = await _listsCol(uid)
        .where('weekKey', isEqualTo: weekKey)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ShoppingList.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  Future<void> updateShoppingListItem({
    required String listId,
    required int itemIndex,
    required bool isChecked,
  }) async {
    final uid  = await _uid();
    final snap = await _listsCol(uid).doc(listId).get();
    if (!snap.exists) return;

    final list = ShoppingList.fromMap(listId, snap.data()!);
    final items = list.items.toList();
    if (itemIndex >= items.length) return;
    items[itemIndex] = ShoppingItem(
      name:          items[itemIndex].name,
      amount:        items[itemIndex].amount,
      unit:          items[itemIndex].unit,
      isChecked:     isChecked,
      usedInRecipes: items[itemIndex].usedInRecipes,
    );

    await _listsCol(uid).doc(listId).update({
      'items': items.map((i) => i.toMap()).toList(),
    });
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _AggItem {
  final String name;
  double amount;
  final String unit;
  final List<String> recipes;
  _AggItem({required this.name, required this.amount, required this.unit, required this.recipes});
}