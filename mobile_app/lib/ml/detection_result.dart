// lib/ml/detection_result.dart

/// Represents a single detected object from MobileNet-SSD
class DetectionResult {
  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  
  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
  
  @override
  String toString() {
    return 'DetectionResult(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%, box: $boundingBox)';
  }
}

/// Represents a bounding box for a detected object
class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;
  
  BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  
  double get width => right - left;
  double get height => bottom - top;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
  
  /// Scale bounding box from model coordinates (0-1) to image coordinates
  BoundingBox scaleToImage(int imageWidth, int imageHeight) {
    return BoundingBox(
      left: left * imageWidth,
      top: top * imageHeight,
      right: right * imageWidth,
      bottom: bottom * imageHeight,
    );
  }
  
  @override
  String toString() {
    return 'BoundingBox(left: ${left.toStringAsFixed(2)}, top: ${top.toStringAsFixed(2)}, right: ${right.toStringAsFixed(2)}, bottom: ${bottom.toStringAsFixed(2)})';
  }
}