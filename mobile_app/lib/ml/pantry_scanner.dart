// lib/ml/pantry_scanner.dart
//
// Uses Google ML Kit Image Labeling with the BUILT-IN on-device model.
// No custom .tflite file needed — works on x86 emulators and real devices.

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'detection_result.dart';

class PantryScanner {
  ImageLabeler? _labeler;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final options = ImageLabelerOptions(confidenceThreshold: 0.50);
    _labeler = ImageLabeler(options: options);
    _isInitialized = true;
    print('✅ PantryScanner: ML Kit built-in labeler ready');
  }

  Future<List<DetectionResult>> detectObjects(
    String imagePath, {
    dynamic imageFile,
  }) async {
    if (!_isInitialized) await initialize();

    final inputImage = InputImage.fromFilePath(imagePath);
    final labels = await _labeler!.processImage(inputImage);

    print('🔍 PantryScanner: ${labels.length} raw labels from ML Kit');
    for (final l in labels) {
      print('   RAW: ${l.label} = ${(l.confidence * 100).toStringAsFixed(1)}%');
    }

    final results = labels
        .map((l) => DetectionResult(
              label: _cleanLabel(l.label),
              confidence: l.confidence,
              boundingBox: BoundingBox(
                left: 0.0, top: 0.0, right: 1.0, bottom: 1.0,
              ),
            ))
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return results;
  }

  /// Filter to food-relevant labels from the general ML Kit model.
  List<DetectionResult> filterFoodItems(List<DetectionResult> all) {
    const foodKeywords = [
      // Produce
      'apple', 'banana', 'orange', 'lemon', 'lime', 'grape', 'berry',
      'strawberry', 'blueberry', 'raspberry', 'mango', 'pineapple',
      'watermelon', 'peach', 'pear', 'cherry', 'avocado', 'tomato',
      'broccoli', 'carrot', 'lettuce', 'cucumber', 'pepper', 'onion',
      'potato', 'corn', 'mushroom', 'garlic', 'spinach', 'celery',
      'kale', 'cabbage', 'zucchini', 'eggplant', 'cauliflower', 'radish',
      // Protein
      'egg', 'chicken', 'beef', 'pork', 'fish', 'meat', 'turkey',
      'salmon', 'tuna', 'shrimp', 'sausage', 'bacon', 'ham', 'steak',
      // Dairy
      'milk', 'cheese', 'yogurt', 'butter', 'cream', 'dairy',
      // Grains / Bakery
      'bread', 'rice', 'pasta', 'noodle', 'cereal', 'oat', 'flour',
      'cake', 'cookie', 'donut', 'muffin', 'bagel', 'pizza', 'sandwich',
      'waffle', 'pancake', 'tortilla', 'cracker', 'biscuit',
      // Pantry / packaged
      'sauce', 'oil', 'vinegar', 'juice', 'soup', 'jam', 'honey',
      'sugar', 'salt', 'spice', 'herb', 'chocolate', 'candy', 'syrup',
      'bean', 'lentil', 'nut', 'seed', 'chip', 'snack',
      // Generic food words the model uses
      'food', 'fruit', 'vegetable', 'produce', 'dish', 'meal',
      'cuisine', 'ingredient', 'drink', 'beverage', 'coffee', 'tea',
      'salad', 'dessert', 'breakfast', 'lunch', 'dinner',
      // Containers that imply food
      'bottle', 'jar', 'can',
    ];

    final filtered = all.where((d) {
      final lower = d.label.toLowerCase();
      return foodKeywords.any((kw) => lower.contains(kw));
    }).toList();

    print('🍎 After food filter: ${filtered.length} / ${all.length} items kept');
    return filtered;
  }

  Map<String, int> getDetectionSummary(List<DetectionResult> detections) {
    final map = <String, int>{};
    for (final d in detections) {
      map[d.label] = (map[d.label] ?? 0) + 1;
    }
    return map;
  }

  bool get isInitialized => _isInitialized;

  void dispose() {
    _labeler?.close();
    _labeler = null;
    _isInitialized = false;
  }

  static String _cleanLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}