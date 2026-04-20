// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/env_config.dart';
import 'services/backend_status_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env before anything else
  await EnvConfig.load();

  // Wake the Render backend immediately, runs in background,
  // never blocks the UI, no browser redirect.
  BackendStatusService.instance.init();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('App will run in offline mode (SQLite only)');
  }

  runApp(const RootApp());
}