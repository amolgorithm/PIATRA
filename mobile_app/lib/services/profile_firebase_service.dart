// lib/services/profile_firebase_service.dart
//
// Persists UserProfileModel to Firestore under:
//   /user_profiles/{uid}
//
// If the user has no uid yet (guest), uses a stable device-local ID
// stored in SharedPreferences so the profile still survives app restarts.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile_model.dart';

class ProfileFirebaseService {
  ProfileFirebaseService._();
  static final ProfileFirebaseService instance = ProfileFirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'user_profiles';
  static const String _localUidKey = 'piatra_local_uid';

  // ── Stable device UID (used when not signed in) ──────────────────────────

  Future<String> _getOrCreateLocalUid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString(_localUidKey);
    if (uid == null || uid.isEmpty) {
      uid = 'local_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_localUidKey, uid);
    }
    return uid;
  }

  Future<String> _resolveUid(String? providedUid) async {
    if (providedUid != null && providedUid.isNotEmpty) return providedUid;
    return _getOrCreateLocalUid();
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> saveProfile(UserProfileModel profile) async {
    try {
      final uid = await _resolveUid(profile.uid);
      final data = profile.toMap();
      data['uid'] = uid; // make sure uid is consistent
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _db
          .collection(_collection)
          .doc(uid)
          .set(data, SetOptions(merge: true));

      debugPrint('[ProfileFirebaseService] ✅ Profile saved (uid=$uid)');
    } catch (e) {
      debugPrint('[ProfileFirebaseService] ❌ Save failed: $e');
      rethrow;
    }
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  /// Returns null if no profile exists yet in Firestore.
  Future<UserProfileModel?> loadProfile({String? uid}) async {
    try {
      final resolvedUid = await _resolveUid(uid);
      final doc = await _db.collection(_collection).doc(resolvedUid).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('[ProfileFirebaseService] No profile found for uid=$resolvedUid');
        return null;
      }

      final data = doc.data()!;
      // Remove Firestore-only fields before parsing
      data.remove('updatedAt');

      final profile = UserProfileModel.fromMap(data);
      debugPrint('[ProfileFirebaseService] ✅ Profile loaded (uid=$resolvedUid)');
      return profile;
    } catch (e) {
      debugPrint('[ProfileFirebaseService] ❌ Load failed: $e');
      return null;
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteProfile({String? uid}) async {
    try {
      final resolvedUid = await _resolveUid(uid);
      await _db.collection(_collection).doc(resolvedUid).delete();
      debugPrint('[ProfileFirebaseService] 🗑 Profile deleted (uid=$resolvedUid)');
    } catch (e) {
      debugPrint('[ProfileFirebaseService] ❌ Delete failed: $e');
    }
  }
}