// lib/ml/pantry_scanner.dart
//
// Uses Gemini Vision (gemini-2.5-flash) via the Anthropic-style REST call to
// the app's own backend /api/assistant/chat endpoint — no extra API key needed
// on the client.  Falls back gracefully when the backend is unreachable.
//
// Replaces the old Google ML Kit Image Labeling approach which only produced
// coarse labels like "Food", "Vegetable", "Plant" instead of specific names
// like "red bell pepper", "Greek yogurt", or "Dijon mustard".

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'detection_result.dart';
import '../core/config/app_config.dart';

class PantryScanner {
  bool _isInitialized = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Nothing to warm up — the backend is stateless.
    _isInitialized = true;
    debugPrint('✅ PantryScanner: Gemini Vision backend ready');
  }

  bool get isInitialized => _isInitialized;

  void dispose() {
    _isInitialized = false;
  }

  // ── Main detection entry point ─────────────────────────────────────────────

  /// Sends [imagePath] to the Gemini-powered backend and returns a list of
  /// [DetectionResult] objects with specific ingredient names and confidence
  /// scores derived from Gemini's response ordering.
  Future<List<DetectionResult>> detectObjects(
    String imagePath, {
    dynamic imageFile, // unused — kept for API compatibility
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = imagePath.split('.').last.toLowerCase();
      final mimeType = _mimeType(ext);

      return await _callGeminiVision(base64Image, mimeType);
    } catch (e) {
      debugPrint('❌ PantryScanner: detection failed — $e');
      return [];
    }
  }

  // ── Gemini Vision call ─────────────────────────────────────────────────────

  Future<List<DetectionResult>> _callGeminiVision(
      String base64Image, String mimeType) async {
    const prompt = '''
You are a precise kitchen inventory assistant. Examine this image carefully and identify every distinct food ingredient, grocery item, or pantry product you can see.

Return ONLY a JSON array — no markdown, no explanation, no wrapper object.
Each element must have exactly two fields:
  "name": a specific, common grocery-store name (e.g. "red bell pepper", "Greek yogurt 2%", "Dijon mustard", "basmati rice", "free-range eggs", "baby spinach", "unsalted butter", "garlic cloves", "cherry tomatoes", "cheddar cheese")
  "confidence": a number between 0.0 and 1.0 reflecting how certain you are

Rules:
- Be as SPECIFIC as possible. "grapes" not "fruit". "sourdough bread" not "bread". "Greek yogurt" not "dairy".
- If you see a brand label you recognise, you may include it: "Heinz ketchup".
- List every distinct item visible, even partially. Up to 30 items.
- If the image contains no food at all, return an empty array: []
- Do NOT include non-food items unless they are food-adjacent containers with readable labels.
- Order by descending confidence.

Example of correct output:
[
  {"name": "red bell pepper", "confidence": 0.97},
  {"name": "baby spinach", "confidence": 0.94},
  {"name": "garlic cloves", "confidence": 0.91}
]
''';

    // We send via the backend's /api/assistant/chat endpoint which already
    // has the Gemini SDK wired up.  We embed the image as a data URI in the
    // message body so the backend can pass it through to Gemini's vision model.
    final payload = jsonEncode({
      'message': prompt,
      'context': 'VISION_SCAN::$mimeType::$base64Image',
      'user_id': '',
    });

    final response = await http
        .post(
          Uri.parse(AppConfig.assistantChatUrl),
          headers: {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (body['response'] as String? ?? '').trim();

    return _parseGeminiResponse(raw);
  }

  // ── Response parser ────────────────────────────────────────────────────────

  List<DetectionResult> _parseGeminiResponse(String raw) {
    // Strip accidental markdown fences
    String cleaned = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // Extract the JSON array even if there's surrounding text
    final start = cleaned.indexOf('[');
    final end   = cleaned.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) {
      debugPrint('⚠️  PantryScanner: no JSON array in response:\n$raw');
      return [];
    }
    cleaned = cleaned.substring(start, end + 1);

    List<dynamic> items;
    try {
      items = jsonDecode(cleaned) as List<dynamic>;
    } catch (e) {
      debugPrint('⚠️  PantryScanner: JSON parse error — $e\n$cleaned');
      return [];
    }

    final results = <DetectionResult>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final name = (item['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.8;
      results.add(DetectionResult(
        label: _capitalise(name),
        confidence: confidence.clamp(0.0, 1.0),
        boundingBox: BoundingBox(
          left: 0.0, top: 0.0, right: 1.0, bottom: 1.0,
        ),
      ));
    }

    debugPrint('🍎 PantryScanner: ${results.length} specific ingredients detected');
    for (final r in results) {
      debugPrint('   ${r.label} = ${(r.confidence * 100).toStringAsFixed(1)}%');
    }

    return results;
  }

  // ── filterFoodItems ────────────────────────────────────────────────────────
  //
  // Gemini already returns only food items, so this is a lightweight passthrough
  // that simply drops anything below a minimum confidence threshold.
  // The old keyword-list approach is no longer needed.

  List<DetectionResult> filterFoodItems(
    List<DetectionResult> all, {
    double minConfidence = 0.40,
  }) {
    final filtered = all.where((d) => d.confidence >= minConfidence).toList();
    debugPrint(
        '🍎 After confidence filter (≥${(minConfidence * 100).round()}%): '
        '${filtered.length} / ${all.length} items kept');
    return filtered;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, int> getDetectionSummary(List<DetectionResult> detections) {
    final map = <String, int>{};
    for (final d in detections) {
      map[d.label] = (map[d.label] ?? 0) + 1;
    }
    return map;
  }

  static String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}