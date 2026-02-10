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
  static Future<List<List<List<List<double>>>>> preprocessImage(String imagePath) async {
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
    
    // Convert to 4D tensor [1, 300, 300, 3]
    return _imageToTensor4D(resizedImage);
  }
  
  /// Convert image to 4D tensor [batch, height, width, channels]
  static List<List<List<List<double>>>> _imageToTensor4D(img.Image image) {
    // Create 4D array: [1, height, width, 3]
    final tensor = List.generate(
      1, // batch size
      (_) => List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            final pixel = image.getPixel(x, y);
            // Return [R, G, B] normalized to [0, 1]
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
    
    return tensor;
  }
  
  /// Alternative: Convert to Float32List if model expects flattened input
  /// This maintains 4D structure but as typed data
  static Future<Float32List> preprocessImageFlat(String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    img.Image resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );
    
    return _imageToFloat32List(resizedImage);
  }
  
  /// Convert image to Float32List (flattened but preserving HWC order)
  static Float32List _imageToFloat32List(img.Image image) {
    final int totalElements = 1 * inputHeight * inputWidth * 3;
    final Float32List buffer = Float32List(totalElements);
    
    int bufferIndex = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // Store in HWC format: Height, Width, Channels
        buffer[bufferIndex++] = pixel.r / 255.0;
        buffer[bufferIndex++] = pixel.g / 255.0;
        buffer[bufferIndex++] = pixel.b / 255.0;
      }
    }
    
    return buffer;
  }
  
  /// Convert to uint8 format if model uses quantized input
  static Future<Uint8List> preprocessImageUint8(String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    img.Image resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );
    
    return _imageToUint8List(resizedImage);
  }
  
  /// Convert image to Uint8List for quantized models
  static Uint8List _imageToUint8List(img.Image image) {
    final int totalElements = 1 * inputHeight * inputWidth * 3;
    final Uint8List buffer = Uint8List(totalElements);
    
    int bufferIndex = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        
        // Store raw RGB values [0-255]
        buffer[bufferIndex++] = pixel.r.toInt();
        buffer[bufferIndex++] = pixel.g.toInt();
        buffer[bufferIndex++] = pixel.b.toInt();
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