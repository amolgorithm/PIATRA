// lib/ui/screens/scan_screen.dart
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
  bool _isProcessing = false;
  String? _statusMessage;
  XFile? _capturedImage;
  final ImagePicker _imagePicker = ImagePicker();
  final PantryScanner _scanner = PantryScanner();
  List<DetectedItem> _detectedItems = [];

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    try {
      await _scanner.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ML model failed to load: $e'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 6),
          ),
        );
      }
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
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) setState(() => _capturedImage = image);
    } catch (e) {
      _showErrorSnackBar('Camera error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) setState(() => _capturedImage = image);
    } catch (e) {
      _showErrorSnackBar('Gallery error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _detectedItems = [];
      _statusMessage = null;
    });
  }

  Future<void> _processImage() async {
    if (_capturedImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Identifying food items…';
    });

    try {
      final results = await _scanner.detectObjects(_capturedImage!.path);
      final foodItems = _scanner.filterFoodItems(results);

      setState(() {
        _detectedItems = foodItems
            .asMap()
            .entries
            .map((e) => DetectedItem.fromDetection(e.value, index: e.key))
            .toList();
        _isProcessing = false;
        _statusMessage = null;
      });

      if (_detectedItems.isEmpty) {
        _showWarningSnackBar(
          results.isEmpty
              ? 'Nothing detected. Try better lighting or a closer shot.'
              : 'No food found in image. Make sure food is clearly visible.',
        );
      } else {
        _showDetectionResults();
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
      _showErrorSnackBar('Detection failed: $e');
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
        onItemsUpdated: (updated) => setState(() => _detectedItems = updated),
        onConfirm: _addToPantry,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _addToPantry() async {
    final activeItems = _detectedItems.where((i) => !i.isDeleted).toList();
    if (activeItems.isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final item in activeItems) {
        await PantrySyncManager.instance.addItem(
          PantryItem(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            category: _categorize(item.name),
          ),
          push: true,
        );
      }
      if (!mounted) return;
      Navigator.pop(context); // loader
      Navigator.pop(context); // sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Added ${activeItems.length} item${activeItems.length == 1 ? '' : 's'} to pantry!'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      _retake();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Error saving: $e');
    }
  }

  String _categorize(String name) {
    final n = name.toLowerCase();
    if (['salad', 'broccoli', 'carrot', 'onion', 'tomato', 'cucumber',
        'spinach', 'lettuce', 'pepper', 'vegetable', 'zucchini',
        'eggplant', 'potato', 'garlic', 'celery', 'kale', 'mushroom']
        .any(n.contains)) return 'Vegetables';
    if (['apple', 'banana', 'orange', 'berry', 'grape', 'mango',
        'pineapple', 'watermelon', 'peach', 'pear', 'cherry',
        'lemon', 'lime', 'melon', 'fruit', 'avocado', 'coconut']
        .any(n.contains)) return 'Fruits';
    if (['milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg',
        'dairy', 'cottage', 'custard']
        .any(n.contains)) return 'Dairy';
    if (['chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'shrimp',
        'turkey', 'lamb', 'sausage', 'bacon', 'ham', 'meat', 'steak']
        .any(n.contains)) return 'Meat';
    if (['bread', 'cake', 'donut', 'pizza', 'cookie', 'muffin',
        'croissant', 'bagel', 'pastry', 'biscuit', 'waffle', 'pancake']
        .any(n.contains)) return 'Bakery';
    if (['juice', 'soda', 'coffee', 'tea', 'water', 'wine', 'beer',
        'smoothie', 'latte', 'drink', 'beverage', 'cocktail']
        .any(n.contains)) return 'Beverages';
    if (['rice', 'pasta', 'noodle', 'bread', 'cereal', 'oat', 'flour',
        'quinoa', 'lentil', 'bean', 'chickpea', 'tortilla', 'wrap']
        .any(n.contains)) return 'Grains & Legumes';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          _buildBg(isDark),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _capturedImage != null
                        ? _buildImagePreview()
                        : _buildInstructions(isDark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
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
      padding: const EdgeInsets.all(20),
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
                Text('Scan Ingredients',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  _capturedImage == null
                      ? 'Photo or gallery'
                      : _isProcessing
                          ? (_statusMessage ?? 'Processing…')
                          : 'Review detected items',
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
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 80, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text('Scan Your Pantry',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Point at any food item or ingredient.\nAI identifies ~2000 food types on-device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: kIsWeb
              ? Image.network(_capturedImage!.path,
                  fit: BoxFit.contain, width: double.infinity)
              : Image.file(File(_capturedImage!.path),
                  fit: BoxFit.contain, width: double.infinity),
        ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage ?? 'Processing…',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _takePicture,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processImage,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_isProcessing ? 'Detecting…' : 'Identify Food'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildBg(bool isDark) {
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

  void _showErrorSnackBar(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.errorRed));

  void _showWarningSnackBar(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.warningYellow));
}

// ─────────────────────────────────────────────────────────────────────────────
// Detection Results Sheet
// ─────────────────────────────────────────────────────────────────────────────

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

  void _updateItem(DetectedItem updated) {
    setState(() {
      final idx = _items.indexWhere((i) => i.id == updated.id);
      if (idx != -1) {
        _items[idx] = updated;
        widget.onItemsUpdated(_items);
      }
    });
  }

  void _deleteItem(String id) {
    setState(() {
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _items[idx] = _items[idx].copyWith(isDeleted: true);
        widget.onItemsUpdated(_items);
      }
    });
  }

  void _showEditDialog(DetectedItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name', prefixIcon: Icon(Icons.label)),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                  labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _updateItem(item.copyWith(
                name: nameCtrl.text.trim(),
                quantity: qtyCtrl.text.trim(),
                isManuallyEdited: true,
              ));
              Navigator.pop(ctx);
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
    final active = _items.where((i) => !i.isDeleted).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.restaurant_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detected Items',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('${active.length} food item${active.length == 1 ? '' : 's'} found',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.cardDark : Colors.grey.shade100),
                ),
              ],
            ),
          ),
          // Warning for low confidence items
          if (active.any((i) => i.confidenceLevel == ConfidenceLevel.low))
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.warningYellow.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warningYellow, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Some items have low confidence — tap the edit icon to rename.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // List
          Expanded(
            child: active.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_sweep, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('All items removed',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: active.length,
                    itemBuilder: (_, i) => _DetectedItemCard(
                      item: active[i],
                      onEdit: () => _showEditDialog(active[i]),
                      onDelete: () => _deleteItem(active[i].id),
                    ),
                  ),
          ),
          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.grey.shade50,
              border: Border(
                  top: BorderSide(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.1))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: active.isEmpty ? null : widget.onConfirm,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text('Add ${active.length} to Pantry'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual item card
// ─────────────────────────────────────────────────────────────────────────────

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

    Color indicatorColor;
    IconData indicatorIcon;
    String confidenceLabel;
    switch (item.confidenceLevel) {
      case ConfidenceLevel.high:
        indicatorColor = AppTheme.successGreen;
        indicatorIcon = Icons.check_circle;
        confidenceLabel = 'High';
        break;
      case ConfidenceLevel.medium:
        indicatorColor = AppTheme.warningYellow;
        indicatorIcon = Icons.warning;
        confidenceLabel = 'Medium';
        break;
      case ConfidenceLevel.low:
        indicatorColor = AppTheme.errorRed;
        indicatorIcon = Icons.error;
        confidenceLabel = 'Low';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Confidence circle
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: indicatorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(indicatorIcon, color: indicatorColor, size: 24),
            ),
            const SizedBox(width: 12),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (item.isManuallyEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.infoBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Edited',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.infoBlue,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.inventory_2,
                          size: 13,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text('Qty: ${item.quantity}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: indicatorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.confidencePercentage}% $confidenceLabel',
                          style: TextStyle(
                              fontSize: 11,
                              color: indicatorColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
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
                    backgroundColor: AppTheme.infoBlue.withOpacity(0.1),
                    foregroundColor: AppTheme.infoBlue,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.errorRed.withOpacity(0.1),
                    foregroundColor: AppTheme.errorRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}