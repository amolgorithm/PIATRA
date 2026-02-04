// lib/ml/image_preprocessor.dart

import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  // MobileNet-SSD expects 300x300 input
  static const int inputWidth = 300;
  static const int inputHeight = 300;
  
  /// Preprocess image for MobileNet-SSD model
  /// Returns normalized Float32List in format [1, 300, 300, 3]
  static Future<Float32List> preprocessImage(String imagePath) async {
    // Read the image file
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize to 300x300 (MobileNet-SSD input size)
    img.Image resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );
    
    // Convert to Float32List and normalize to [0, 1]
    return _imageToFloat32List(resizedImage);
  }
  
  /// Convert image to normalized Float32List
  static Float32List _imageToFloat32List(img.Image image) {
    final int totalPixels = inputWidth * inputHeight * 3;
    final Float32List buffer = Float32List(totalPixels);
    
    int pixelIndex = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // Extract RGB values and normalize to [0, 1]
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    
    return buffer;
  }
  
  /// Alternative preprocessing with mean subtraction and scaling
  /// Use this if your model was trained with ImageNet normalization
  static Float32List preprocessImageWithNormalization(img.Image image) {
    // ImageNet mean values
    const double meanR = 0.485;
    const double meanG = 0.456;
    const double meanB = 0.406;
    
    // ImageNet std values
    const double stdR = 0.229;
    const double stdG = 0.224;
    const double stdB = 0.225;
    
    final int totalPixels = inputWidth * inputHeight * 3;
    final Float32List buffer = Float32List(totalPixels);
    
    int pixelIndex = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // Normalize with mean and std
        buffer[pixelIndex++] = (pixel.r / 255.0 - meanR) / stdR;
        buffer[pixelIndex++] = (pixel.g / 255.0 - meanG) / stdG;
        buffer[pixelIndex++] = (pixel.b / 255.0 - meanB) / stdB;
      }
    }
    
    return buffer;
  }
  
  /// Get image dimensions for bounding box scaling
  static Future<Map<String, int>> getImageDimensions(String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    return {
      'width': image.width,
      'height': image.height,
    };
  }
}