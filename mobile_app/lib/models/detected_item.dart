import '../ml/detection_result.dart';

/// Enhanced detected item with editable fields and confidence tracking
class DetectedItem {
  final String id;
  String name;
  String quantity;
  final double confidence;
  bool isManuallyEdited;
  bool isDeleted;

  DetectedItem({
    required this.id,
    required this.name,
    this.quantity = '1',
    required this.confidence,
    this.isManuallyEdited = false,
    this.isDeleted = false,
  });

  /// Create from ML detection result
  factory DetectedItem.fromDetection(DetectionResult detection, {int index = 0}) {
    return DetectedItem(
      id: 'detected_${DateTime.now().millisecondsSinceEpoch}_$index',
      name: _formatLabel(detection.label),
      quantity: '1',
      confidence: detection.confidence,
    );
  }

  /// Create a copy with updated fields
  DetectedItem copyWith({
    String? name,
    String? quantity,
    bool? isManuallyEdited,
    bool? isDeleted,
  }) {
    return DetectedItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      confidence: confidence,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Get confidence level category
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.80) return ConfidenceLevel.high;
    if (confidence >= 0.60) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  /// Get confidence percentage
  int get confidencePercentage => (confidence * 100).round();

  /// Format label from ML model to display name
  static String _formatLabel(String label) {
    // Capitalize first letter of each word
    return label
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'confidence': confidence,
      'isManuallyEdited': isManuallyEdited,
      'isDeleted': isDeleted,
    };
  }

  factory DetectedItem.fromMap(Map<String, dynamic> map) {
    return DetectedItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as String? ?? '1',
      confidence: (map['confidence'] as num).toDouble(),
      isManuallyEdited: map['isManuallyEdited'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }
}

enum ConfidenceLevel {
  high,
  medium,
  low,
}