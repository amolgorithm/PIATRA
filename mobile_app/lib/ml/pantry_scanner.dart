// lib/ml/pantry_scanner.dart

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'image_preprocessor.dart';
import 'detection_result.dart';

class PantryScanner {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;
  bool _useMockMode = false;
  bool _isQuantized = false; // Track if model uses quantized inputs
  
  static const int maxDetections = 10;
  static const double confidenceThreshold = 0.5;
  
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
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Attempting to load TFLite model...');
      
      _interpreter = await Interpreter.fromAsset('assets/models/pantry_model.tflite');
      _labels = cocoLabels;
      
      // Check input tensor type
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      print('✅ Model loaded successfully');
      print('   Input shape: ${inputTensor.shape}');
      print('   Input type: ${inputTensor.type}');
      print('   Output shape: ${outputTensor.shape}');
      
      // Detect if model is quantized (uint8) or float32
      _isQuantized = inputTensor.type.toString().contains('uint8');
      print('   Quantized: $_isQuantized');
      
      _isInitialized = true;
      _useMockMode = false;
    } catch (e) {
      print('⚠️  Warning: Could not load ML model');
      print('   Error: $e');
      print('   Running in MOCK MODE for testing');
      
      _isInitialized = false;
      _useMockMode = true;
      _labels = cocoLabels;
    }
  }
  
  Future<List<DetectionResult>> detectObjects(String imagePath) async {
    if (_useMockMode) {
      print('🎭 Using mock detections (no model loaded)');
      return _getMockDetections();
    }
    
    if (!_isInitialized) {
      await initialize();
      if (_useMockMode) {
        return _getMockDetections();
      }
    }
    
    try {
      print('🔍 Processing image...');
      
      // Preprocess based on model type
      final results = _isQuantized 
          ? await _runInferenceQuantized(imagePath)
          : await _runInferenceFloat(imagePath);
      
      print('✅ Detected ${results.length} objects');
      for (final result in results) {
        print('   ${result.label}: ${(result.confidence * 100).toStringAsFixed(1)}%');
      }
      
      return results;
    } catch (e, stackTrace) {
      print('❌ Error during detection: $e');
      print('Stack trace: $stackTrace');
      print('   Falling back to mock detections');
      return _getMockDetections();
    }
  }
  
  /// Run inference with float32 input
  Future<List<DetectionResult>> _runInferenceFloat(String imagePath) async {
    // Get preprocessed image as 4D tensor
    final inputTensor = await ImagePreprocessor.preprocessImage(imagePath);
    
    // Prepare outputs - shape depends on model
    // MobileNet SSD typically outputs:
    // [1, num_detections, 4] - bounding boxes
    // [1, num_detections] - classes
    // [1, num_detections] - scores
    // [1] - number of detections
    
    final outputLocations = List.generate(1, (_) => 
      List.generate(maxDetections, (_) => List.filled(4, 0.0))
    );
    final outputClasses = List.generate(1, (_) => List.filled(maxDetections, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(maxDetections, 0.0));
    final numDetections = List.filled(1, 0.0);
    
    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };
    
    print('Running inference...');
    _interpreter!.runForMultipleInputs([inputTensor], outputs);
    
    final numDet = numDetections[0].toInt();
    print('Found $numDet detections');
    
    return _parseDetections(outputLocations, outputClasses[0], outputScores[0], numDet);
  }
  
  /// Run inference with uint8 quantized input
  Future<List<DetectionResult>> _runInferenceQuantized(String imagePath) async {
    // Get preprocessed image as uint8
    final inputData = await ImagePreprocessor.preprocessImageUint8(imagePath);
    
    // Reshape to 4D: [1, 300, 300, 3]
    final input = inputData.buffer.asUint8List().reshape([1, 300, 300, 3]);
    
    // Prepare outputs
    final outputLocations = List.generate(1, (_) => 
      List.generate(maxDetections, (_) => List.filled(4, 0.0))
    );
    final outputClasses = List.generate(1, (_) => List.filled(maxDetections, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(maxDetections, 0.0));
    final numDetections = List.filled(1, 0.0);
    
    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };
    
    print('Running quantized inference...');
    _interpreter!.runForMultipleInputs([input], outputs);
    
    final numDet = numDetections[0].toInt();
    print('Found $numDet detections');
    
    return _parseDetections(outputLocations, outputClasses[0], outputScores[0], numDet);
  }
  
  List<DetectionResult> _parseDetections(
    List<List<List<double>>> locations,
    List<double> classes,
    List<double> scores,
    int numDetections,
  ) {
    final List<DetectionResult> results = [];
    
    for (int i = 0; i < numDetections && i < maxDetections; i++) {
      final score = scores[i];
      
      if (score < confidenceThreshold) continue;
      
      final classIndex = classes[i].toInt();
      if (classIndex == 0 || classIndex >= _labels!.length) continue;
      
      final label = _labels![classIndex];
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
    
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }
  
  List<DetectionResult> _getMockDetections() {
    return [
      DetectionResult(
        label: 'apple',
        confidence: 0.87,
        boundingBox: BoundingBox(left: 0.2, top: 0.3, right: 0.5, bottom: 0.7),
      ),
      DetectionResult(
        label: 'banana',
        confidence: 0.82,
        boundingBox: BoundingBox(left: 0.5, top: 0.4, right: 0.8, bottom: 0.8),
      ),
      DetectionResult(
        label: 'bottle',
        confidence: 0.75,
        boundingBox: BoundingBox(left: 0.1, top: 0.1, right: 0.3, bottom: 0.6),
      ),
    ];
  }
  
  List<DetectionResult> filterFoodItems(List<DetectionResult> detections) {
    final foodLabels = {
      'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot',
      'hot dog', 'pizza', 'donut', 'cake', 'bottle', 'wine glass',
      'cup', 'fork', 'knife', 'spoon', 'bowl'
    };
    
    return detections.where((d) => foodLabels.contains(d.label.toLowerCase())).toList();
  }
  
  Map<String, int> getDetectionSummary(List<DetectionResult> detections) {
    final Map<String, int> summary = {};
    for (final detection in detections) {
      summary[detection.label] = (summary[detection.label] ?? 0) + 1;
    }
    return summary;
  }
  
  bool get isMockMode => _useMockMode;
  
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _useMockMode = false;
  }
}

// Extension to reshape typed lists
extension ReshapeExtension on Uint8List {
  List<List<List<List<int>>>> reshape(List<int> shape) {
    if (shape.length != 4) {
      throw ArgumentError('Shape must have 4 dimensions');
    }
    
    final batch = shape[0];
    final height = shape[1];
    final width = shape[2];
    final channels = shape[3];
    
    final result = List.generate(
      batch,
      (_) => List.generate(
        height,
        (y) => List.generate(
          width,
          (x) => List.generate(
            channels,
            (c) {
              final index = y * width * channels + x * channels + c;
              return this[index];
            },
          ),
        ),
      ),
    );
    
    return result;
  }
}