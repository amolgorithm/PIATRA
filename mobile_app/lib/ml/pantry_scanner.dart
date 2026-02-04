// lib/ml/pantry_scanner.dart

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'image_preprocessor.dart';
import 'detection_result.dart';

class PantryScanner {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;
  
  // MobileNet-SSD output configuration
  static const int maxDetections = 10;
  static const double confidenceThreshold = 0.5;
  
  // COCO dataset labels (91 classes)
  // MobileNet-SSD is typically trained on COCO which includes many food items
  static const List<String> cocoLabels = [
    'background',
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
    'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep',
    'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase',
    'frisbee', 'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
    'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich',
    'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant',
    'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave',
    'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier',
    'toothbrush'
  ];
  
  /// Initialize the TFLite model
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load the model
      _interpreter = await Interpreter.fromAsset('assets/models/pantry_model.tflite');
      
      // Use COCO labels by default
      _labels = cocoLabels;
      
      _isInitialized = true;
      print('PantryScanner initialized successfully');
      print('Model input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('Error initializing PantryScanner: $e');
      throw Exception('Failed to initialize model: $e');
    }
  }
  
  /// Detect objects in an image
  Future<List<DetectionResult>> detectObjects(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Preprocess the image
      final Float32List inputImage = await ImagePreprocessor.preprocessImage(imagePath);
      
      // Reshape input for the model [1, 300, 300, 3]
      final input = inputImage.reshape([1, 300, 300, 3]);
      
      // Prepare output buffers
      // MobileNet-SSD typically outputs:
      // - Bounding boxes: [1, num_detections, 4]
      // - Classes: [1, num_detections]
      // - Scores: [1, num_detections]
      // - Number of detections: [1]
      
      final outputLocations = List.generate(1, (i) => 
        List.generate(maxDetections, (j) => List.filled(4, 0.0))
      );
      final outputClasses = List.filled(maxDetections, 0.0).reshape([1, maxDetections]);
      final outputScores = List.filled(maxDetections, 0.0).reshape([1, maxDetections]);
      final numDetections = List.filled(1, 0.0);
      
      // Create outputs map
      final outputs = {
        0: outputLocations,
        1: outputClasses,
        2: outputScores,
        3: numDetections,
      };
      
      // Run inference
      _interpreter!.runForMultipleInputs([input], outputs);
      
      // Parse results
      return _parseDetections(
        outputLocations,
        outputClasses[0],
        outputScores[0],
        numDetections[0].toInt(),
      );
    } catch (e) {
      print('Error during detection: $e');
      throw Exception('Detection failed: $e');
    }
  }
  
  /// Parse detection results and filter by confidence
  List<DetectionResult> _parseDetections(
    List<List<List<double>>> locations,
    List<double> classes,
    List<double> scores,
    int numDetections,
  ) {
    final List<DetectionResult> results = [];
    
    for (int i = 0; i < numDetections && i < maxDetections; i++) {
      final score = scores[i];
      
      // Filter by confidence threshold
      if (score < confidenceThreshold) continue;
      
      final classIndex = classes[i].toInt();
      
      // Skip background class
      if (classIndex == 0) continue;
      
      // Get label
      final label = classIndex < _labels!.length 
          ? _labels![classIndex] 
          : 'Unknown';
      
      // Parse bounding box [top, left, bottom, right] or [ymin, xmin, ymax, xmax]
      final box = locations[0][i];
      final boundingBox = BoundingBox(
        left: box[1],   // xmin
        top: box[0],    // ymin
        right: box[3],  // xmax
        bottom: box[2], // ymax
      );
      
      results.add(DetectionResult(
        label: label,
        confidence: score,
        boundingBox: boundingBox,
      ));
    }
    
    // Sort by confidence (highest first)
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return results;
  }
  
  /// Filter detections to only include food-related items
  List<DetectionResult> filterFoodItems(List<DetectionResult> detections) {
    // COCO food-related class indices
    const foodIndices = {
      47, 48, 49, 50, 51, 52, 53, 54, 55, 56, // banana to donut
      40, 41, 42, 43, 44, 45, 46, // bottle to bowl
    };
    
    final foodLabels = {
      'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
      'hot dog', 'pizza', 'donut', 'cake', 'bottle', 'wine glass',
      'cup', 'fork', 'knife', 'spoon', 'bowl'
    };
    
    return detections.where((detection) {
      return foodLabels.contains(detection.label.toLowerCase());
    }).toList();
  }
  
  /// Get a summary of detected items with counts
  Map<String, int> getDetectionSummary(List<DetectionResult> detections) {
    final Map<String, int> summary = {};
    
    for (final detection in detections) {
      summary[detection.label] = (summary[detection.label] ?? 0) + 1;
    }
    
    return summary;
  }
  
  /// Dispose of resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}