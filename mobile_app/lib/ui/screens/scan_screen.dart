import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/theme/app_theme.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../../ml/pantry_scanner.dart';
import '../../ml/detection_result.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // ML & Processing State
  bool _isProcessing = false;
  XFile? _capturedImage;
  final ImagePicker _imagePicker = ImagePicker();
  final PantryScanner _scanner = PantryScanner();
  List<DetectionResult>? _detectionResults;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      await _scanner.initialize();
      debugPrint('Scanner initialized successfully');
    } catch (e) {
      debugPrint('Error initializing scanner: $e');
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  // Logic from "Old version" - Using ImagePicker with specific constraints
  Future<void> _takePicture() async {
    setState(() => _isProcessing = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _capturedImage = image);
      }
    } catch (e) {
      _showErrorSnackBar('Error accessing camera: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _capturedImage = image);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _detectionResults = null;
    });
  }

  // MobileNet-SSD Logic from "New version"
  Future<void> _processImage() async {
    if (_capturedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final results = await _scanner.detectObjects(_capturedImage!.path);
      final foodItems = _scanner.filterFoodItems(results);

      setState(() {
        _detectionResults = foodItems;
        _isProcessing = false;
      });

      if (foodItems.isEmpty) {
        _showWarningSnackBar('No food items detected. Try better lighting.');
      } else {
        _showDetectionResults();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showErrorSnackBar('Error processing image: $e');
    }
  }

  // UI: Results Sheet from "New version"
  void _showDetectionResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResultsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(isDark),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _capturedImage != null
                        ? _buildCapturedImage()
                        : _buildInstructions(isDark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _capturedImage != null
                      ? _buildReviewControls()
                      : _buildCaptureControls(),
                ),
              ],
            ),
          ),
          const ThemeToggleFAB(),
          const AIAssistantFAB(),
        ],
      ),
    );
  }

  // UI Components -----------------------------------------------------------

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan Ingredient', style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  _capturedImage == null
                      ? 'Choose how to add image'
                      : _isProcessing ? 'Processing...' : 'Review and confirm',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text('Ready to Scan', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              kIsWeb ? 'Click "Take Photo" for camera\nor "Gallery" for local files' : 'Snap a photo or pick from gallery',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: kIsWeb
          ? Image.network(_capturedImage!.path, fit: BoxFit.contain)
          : Image.file(File(_capturedImage!.path), fit: BoxFit.contain),
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _takePicture,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _retake,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retake'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processImage,
            icon: _isProcessing 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_isProcessing ? 'Processing...' : 'Detect'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ],
    );
  }

  // Re-used helper from your new version for the bottom sheet
  Widget _buildResultsSheet() {
    final summary = _scanner.getDetectionSummary(_detectionResults!);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant_rounded, color: Colors.white)),
                const SizedBox(width: 12),
                Text('Detected Items', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: summary.length,
              itemBuilder: (context, index) {
                final entry = summary.entries.elementAt(index);
                return Card(
                  child: ListTile(
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('x${entry.value}', style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addToPantry();
              },
              child: const Center(child: Text('Add to Pantry')),
            ),
          ),
        ],
      ),
    );
  }

  void _addToPantry() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${_detectionResults?.length ?? 0} items!'), backgroundColor: AppTheme.successGreen),
    );
    _retake();
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [AppTheme.backgroundDark, AppTheme.surfaceDark] : [AppTheme.backgroundLight, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed));
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.warningYellow));
  }
}