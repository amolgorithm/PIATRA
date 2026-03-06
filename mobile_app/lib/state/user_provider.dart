// lib/state/user_provider.dart

import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/profile_firebase_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfileModel? _profile;
  bool _isLoading = false;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null;

  // ── Load on app start ────────────────────────────────────────────────────

  /// Call once from main() or App widget's initState.
  Future<void> loadFromFirebase({String? uid}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final saved = await ProfileFirebaseService.instance.loadProfile(uid: uid);
      if (saved != null) {
        _profile = saved;
      }
      // If nothing saved yet, leave _profile null — UI will prompt setup
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Setters (each auto-saves to Firebase) ────────────────────────────────

  Future<void> setProfile(UserProfileModel profile) async {
    _profile = profile;
    notifyListeners();
    await _save();
  }

  Future<void> updateCookingMode(CookingMode mode) async {
    _profile = (_profile ?? UserProfileModel.defaultProfile())
        .copyWith(cookingMode: mode);
    notifyListeners();
    await _save();
  }

  Future<void> updateDietaryPreferences(List<String> prefs) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(dietaryPreferences: prefs);
    notifyListeners();
    await _save();
  }

  Future<void> updateAllergies(List<String> allergies) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(allergies: allergies);
    notifyListeners();
    await _save();
  }

  Future<void> updateCalorieTarget(int calories) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      calorieTarget: calories,
      macroTargets: MacroTargets.fromCalories(calories),
    );
    notifyListeners();
    await _save();
  }

  Future<void> updateDisplayName(String name) async {
    _profile = (_profile ?? UserProfileModel.defaultProfile())
        .copyWith(displayName: name);
    notifyListeners();
    await _save();
  }

  Future<void> updateFavoriteCuisines(List<String> cuisines) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(favoriteCuisines: cuisines);
    notifyListeners();
    await _save();
  }

  void clearProfile() {
    _profile = null;
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_profile == null) return;
    await ProfileFirebaseService.instance.saveProfile(_profile!);
  }
}