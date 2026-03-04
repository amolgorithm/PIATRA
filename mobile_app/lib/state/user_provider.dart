import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';

class UserProvider extends ChangeNotifier {
  UserProfileModel? _profile;
  bool _isLoading = false;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null;

  void setProfile(UserProfileModel profile) {
    _profile = profile;
    notifyListeners();
  }

  void updateCookingMode(CookingMode mode) {
    _profile ??= UserProfileModel.defaultProfile();
    _profile = _profile!.copyWith(cookingMode: mode);
    notifyListeners();
  }

  void updateDietaryPreferences(List<String> prefs) {
    if (_profile == null) return;
    _profile = _profile!.copyWith(dietaryPreferences: prefs);
    notifyListeners();
  }

  void updateAllergies(List<String> allergies) {
    if (_profile == null) return;
    _profile = _profile!.copyWith(allergies: allergies);
    notifyListeners();
  }

  void clearProfile() {
    _profile = null;
    notifyListeners();
  }
}