// lib/ml/pantry_scanner.dart
//
// Uses Gemini Vision (gemini-2.5-flash) via the app's own backend
// /api/assistant/chat endpoint — no extra API key needed on the client.
//
// Fixed: prompt now forbids generic category labels and forces specific
// grocery-store names. Handles multi-ingredient images correctly.

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
    _isInitialized = true;
    debugPrint('✅ PantryScanner: Gemini Vision backend ready');
  }

  bool get isInitialized => _isInitialized;

  void dispose() {
    _isInitialized = false;
  }

  // ── Main detection entry point ─────────────────────────────────────────────

  Future<List<DetectionResult>> detectObjects(
    String imagePath, {
    dynamic imageFile,
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
    // IMPORTANT: This prompt is designed to force Gemini to be specific.
    // Generic labels like "fruit", "vegetable", "food" are explicitly banned.
    const prompt = '''
You are a highly precise kitchen inventory scanner. Your job is to identify every specific food item visible in this image.

CRITICAL RULES — YOU MUST FOLLOW THESE:
1. NEVER use generic category names. BANNED words: "fruit", "vegetable", "food", "produce", "ingredient", "item", "object", "plant", "dairy", "meat", "grain".
2. ALWAYS use the specific common name as you would see on a grocery store label or receipt.
   - NOT "fruit" → YES "apple", "red apple", "green apple", "Granny Smith apple"
   - NOT "vegetable" → YES "broccoli", "red bell pepper", "baby carrots"
   - NOT "dairy" → YES "whole milk", "cheddar cheese", "Greek yogurt"
   - NOT "meat" → YES "chicken breast", "ground beef", "salmon fillet"
3. If you can see a brand name clearly, include it: "Heinz ketchup", "Quaker oats".
4. If there are multiple items, list ALL of them — do not skip any visible food.
5. Include partial items if clearly identifiable.
6. Be as specific as possible about variety/type: "cherry tomatoes" not just "tomatoes", "baby spinach" not just "spinach".

Return ONLY a valid JSON array. No markdown, no explanation, no text before or after.
Each element: {"name": "specific name here", "confidence": 0.0-1.0}

If the image has NO food items at all, return: []

Examples of CORRECT output:
[
  {"name": "Granny Smith apple", "confidence": 0.96},
  {"name": "red bell pepper", "confidence": 0.94},
  {"name": "baby spinach", "confidence": 0.91},
  {"name": "Greek yogurt", "confidence": 0.88},
  {"name": "free-range eggs", "confidence": 0.85}
]

Examples of WRONG output (DO NOT DO THIS):
[
  {"name": "fruit", "confidence": 0.9},
  {"name": "vegetable", "confidence": 0.8}
]

Now analyze the image and return the JSON array:''';

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
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (body['response'] as String? ?? '').trim();

    debugPrint('🔍 PantryScanner raw response: $raw');

    final results = _parseGeminiResponse(raw);

    // If we got generic labels back despite the prompt, filter them out
    // and log a warning so we can debug
    final genericLabels = {
      'fruit', 'vegetable', 'food', 'produce', 'ingredient',
      'item', 'object', 'plant', 'dairy', 'meat', 'grain', 'beverage',
    };
    final filtered = results.where((r) {
      final nameLower = r.label.toLowerCase();
      if (genericLabels.contains(nameLower)) {
        debugPrint('⚠️  PantryScanner: filtered out generic label "${r.label}"');
        return false;
      }
      return true;
    }).toList();

    return filtered;
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

  List<DetectionResult> filterFoodItems(
    List<DetectionResult> all, {
    double minConfidence = 0.35,
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