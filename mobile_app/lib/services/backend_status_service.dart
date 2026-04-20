// lib/services/backend_status_service.dart
//
// Wakes the Render backend immediately when the app opens — silently,
// with no browser redirect or visible disruption to the user.
//
// How it works:
//   1. App calls BackendStatusService.instance.init() in main().
//   2. The service fires a lightweight GET /health ping every few seconds
//      until it gets a 200, then marks status as [BackendStatus.online].
//   3. Any widget can listen to statusStream or read currentStatus.
//   4. If the backend was already warm the first ping resolves in <1s.
//      If it was sleeping on Render free tier it normally wakes in 20-40s.
//
// No browser, no redirect, no user action required.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

enum BackendStatus {
  /// Initial state — ping not yet sent.
  idle,

  /// Ping sent, waiting for response (backend may be waking up).
  waking,

  /// Backend responded with HTTP 200 — ready to use.
  online,

  /// Could not reach backend after [maxAttempts] tries.
  offline,
}

class BackendStatusService {
  BackendStatusService._();
  static final BackendStatusService instance = BackendStatusService._();

  // ── Config ─────────────────────────────────────────────────────────────────

  /// How long to wait for each individual ping.
  static const _pingTimeout = Duration(seconds: 12);

  /// Delay between failed pings while waking.
  static const _retryInterval = Duration(seconds: 4);

  /// Give up after this many consecutive failures.
  static const _maxAttempts = 20; // ~80s total window

  // ── State ──────────────────────────────────────────────────────────────────

  BackendStatus _status = BackendStatus.idle;
  BackendStatus get currentStatus => _status;

  final _controller = StreamController<BackendStatus>.broadcast();
  Stream<BackendStatus> get statusStream => _controller.stream;

  bool _started = false;
  int _attempts = 0;
  Timer? _retryTimer;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once from main() before runApp(). Safe to call multiple times.
  void init() {
    if (_started) return;
    _started = true;
    debugPrint('[BackendStatus] Starting wake-up sequence for ${AppConfig.baseUrl}');
    _setStatus(BackendStatus.waking);
    _ping();
  }

  /// Force a manual re-check (e.g. user taps a retry button).
  void retry() {
    _retryTimer?.cancel();
    _attempts = 0;
    _setStatus(BackendStatus.waking);
    _ping();
  }

  void dispose() {
    _retryTimer?.cancel();
    _controller.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _setStatus(BackendStatus s) {
    _status = s;
    if (!_controller.isClosed) _controller.add(s);
    debugPrint('[BackendStatus] Status → $s');
  }

  Future<void> _ping() async {
    _attempts++;
    if (_attempts > _maxAttempts) {
      _setStatus(BackendStatus.offline);
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/health'))
          .timeout(_pingTimeout);

      if (response.statusCode == 200) {
        _setStatus(BackendStatus.online);
        return; // done — no more pings needed
      }

      debugPrint('[BackendStatus] Ping attempt $_attempts: HTTP ${response.statusCode}');
    } on TimeoutException {
      debugPrint('[BackendStatus] Ping attempt $_attempts: timeout');
    } catch (e) {
      debugPrint('[BackendStatus] Ping attempt $_attempts: $e');
    }

    // Schedule next attempt unless we are already online
    if (_status != BackendStatus.online) {
      _retryTimer = Timer(_retryInterval, _ping);
    }
  }
}