import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/theme/app_theme.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../../ml/pantry_scanner.dart';
import '../../ml/detection_result.dart';
import '../../models/detected_item.dart';
import '../../models/pantry_item.dart';
import '../../services/pantry_sync_manager.dart';

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
  List<DetectedItem> _detectedItems = [];

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
      _detectedItems = [];
    });
  }

  Future<void> _processImage() async {
    if (_capturedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final results = await _scanner.detectObjects(_capturedImage!.path);
      final foodItems = _scanner.filterFoodItems(results);

      setState(() {
        _detectedItems = foodItems
            .asMap()
            .entries
            .map((entry) => DetectedItem.fromDetection(entry.value, index: entry.key))
            .toList();
        _isProcessing = false;
      });

      if (_detectedItems.isEmpty) {
        _showWarningSnackBar('No food items detected. Try better lighting.');
      } else {
        _showDetectionResults();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showErrorSnackBar('Error processing image: $e');
    }
  }

  void _showDetectionResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetectionResultsSheet(
        detectedItems: _detectedItems,
        onItemsUpdated: (updatedItems) {
          setState(() => _detectedItems = updatedItems);
        },
        onConfirm: _addToPantry,
        onCancel: () => Navigator.pop(context),
      ),
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
                      : _isProcessing
                          ? 'Processing...'
                          : 'Review and confirm',
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
              kIsWeb
                  ? 'Click "Take Photo" for camera\nor "Gallery" for local files'
                  : 'Snap a photo or pick from gallery',
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_isProcessing ? 'Processing...' : 'Detect'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ],
    );
  }

  Future<void> _addToPantry() async {
    final activeItems = _detectedItems.where((item) => !item.isDeleted).toList();
    
    if (activeItems.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Add each item to the pantry using PantrySyncManager
      for (final item in activeItems) {
        final pantryItem = PantryItem(
          id: item.id,
          name: item.name,
          quantity: item.quantity,
          category: _categorizeItem(item.name),
          expiryDate: null, // Can be set later by user
          imageUrl: null,
        );
        
        // Add to local SQLite and sync to Firebase
        await PantrySyncManager.instance.addItem(pantryItem, push: true);
      }

      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Close results sheet
      Navigator.pop(context);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Added ${activeItems.length} ${activeItems.length == 1 ? 'item' : 'items'} to pantry!'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Reset for next scan
      _retake();
      
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      _showErrorSnackBar('Error adding items: $e');
    }
  }

  /// Categorize item based on name
  String _categorizeItem(String name) {
    final lowerName = name.toLowerCase();
    
    // Vegetables
    if (['broccoli', 'carrot', 'lettuce', 'tomato', 'cucumber', 'pepper', 'onion'].any((v) => lowerName.contains(v))) {
      return 'Vegetables';
    }
    
    // Fruits
    if (['apple', 'banana', 'orange', 'grape', 'berry', 'lemon', 'lime'].any((f) => lowerName.contains(f))) {
      return 'Fruits';
    }
    
    // Dairy
    if (['milk', 'cheese', 'yogurt', 'butter', 'cream'].any((d) => lowerName.contains(d))) {
      return 'Dairy';
    }
    
    // Meat
    if (['chicken', 'beef', 'pork', 'fish', 'turkey', 'meat'].any((m) => lowerName.contains(m))) {
      return 'Meat';
    }
    
    // Beverages
    if (['bottle', 'drink', 'juice', 'soda', 'water', 'wine', 'beer'].any((b) => lowerName.contains(b))) {
      return 'Beverages';
    }
    
    // Bakery
    if (['bread', 'cake', 'donut', 'pizza', 'sandwich'].any((b) => lowerName.contains(b))) {
      return 'Bakery';
    }
    
    return 'Other';
  }

  Widget _buildBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
              : [AppTheme.backgroundLight, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.warningYellow),
    );
  }
}

// Detection Results Sheet Widget
class _DetectionResultsSheet extends StatefulWidget {
  final List<DetectedItem> detectedItems;
  final Function(List<DetectedItem>) onItemsUpdated;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DetectionResultsSheet({
    required this.detectedItems,
    required this.onItemsUpdated,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_DetectionResultsSheet> createState() => _DetectionResultsSheetState();
}

class _DetectionResultsSheetState extends State<_DetectionResultsSheet> {
  late List<DetectedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.detectedItems);
  }

  void _updateItem(DetectedItem updatedItem) {
    setState(() {
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        _items[index] = updatedItem;
        widget.onItemsUpdated(_items);
      }
    });
  }

  void _deleteItem(String id) {
    setState(() {
      final index = _items.indexWhere((item) => item.id == id);
      if (index != -1) {
        _items[index] = _items[index].copyWith(isDeleted: true);
        widget.onItemsUpdated(_items);
      }
    });
  }

  void _showEditDialog(DetectedItem item) {
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: item.quantity);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedItem = item.copyWith(
                name: nameController.text.trim(),
                quantity: quantityController.text.trim(),
                isManuallyEdited: true,
              );
              _updateItem(updatedItem);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeItems = _items.where((item) => !item.isDeleted).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected Items',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${activeItems.length} ${activeItems.length == 1 ? 'item' : 'items'} found',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.cardDark : Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ),
          
          // Info message
          if (activeItems.any((item) => item.confidenceLevel == ConfidenceLevel.low))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warningYellow, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Some items have low confidence. Please review and edit if needed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Items list
          Expanded(
            child: activeItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activeItems.length,
                    itemBuilder: (context, index) {
                      final item = activeItems[index];
                      return _DetectedItemCard(
                        item: item,
                        onEdit: () => _showEditDialog(item),
                        onDelete: () => _deleteItem(item.id),
                      );
                    },
                  ),
          ),
          
          // Bottom actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.grey.shade50,
              border: Border(
                top: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: activeItems.isEmpty ? null : widget.onConfirm,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text('Add ${activeItems.length} to Pantry'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_sweep,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'All items removed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan again to detect more items',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }
}

// Individual item card widget
class _DetectedItemCard extends StatelessWidget {
  final DetectedItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DetectedItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Confidence indicator
            _buildConfidenceIndicator(),
            const SizedBox(width: 12),
            
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isManuallyEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 10,
                                color: AppTheme.infoBlue,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Edited',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.infoBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 14,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Qty: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildConfidenceBadge(),
                    ],
                  ),
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.infoBlue.withValues(alpha: 0.1),
                    foregroundColor: AppTheme.infoBlue,
                  ),
                  tooltip: 'Edit',
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.errorRed.withValues(alpha: 0.1),
                    foregroundColor: AppTheme.errorRed,
                  ),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator() {
    Color color;
    IconData icon;

    switch (item.confidenceLevel) {
      case ConfidenceLevel.high:
        color = AppTheme.successGreen;
        icon = Icons.check_circle;
        break;
      case ConfidenceLevel.medium:
        color = AppTheme.warningYellow;
        icon = Icons.warning;
        break;
      case ConfidenceLevel.low:
        color = AppTheme.errorRed;
        icon = Icons.error;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildConfidenceBadge() {
    Color color;
    String label;

    switch (item.confidenceLevel) {
      case ConfidenceLevel.high:
        color = AppTheme.successGreen;
        label = 'High';
        break;
      case ConfidenceLevel.medium:
        color = AppTheme.warningYellow;
        label = 'Medium';
        break;
      case ConfidenceLevel.low:
        color = AppTheme.errorRed;
        label = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${item.confidencePercentage}%',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}