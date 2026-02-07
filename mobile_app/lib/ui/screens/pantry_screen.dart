import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../services/pantry_sync_manager.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  String _selectedFilter = 'All';

  final List<PantryItem> _pantryItems = [];
  StreamSubscription<List<PantryItem>>? _syncSub;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
                    : [AppTheme.backgroundLight, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
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
                            Text(
                              'My Pantry',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              '${_pantryItems.length} items',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showAddItemDialog,
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedFilter == 'All',
                        onTap: () => setState(() => _selectedFilter = 'All'),
                      ),
                      _FilterChip(
                        label: 'Expiring Soon',
                        isSelected: _selectedFilter == 'Expiring Soon',
                        onTap: () => setState(() => _selectedFilter = 'Expiring Soon'),
                      ),
                      _FilterChip(
                        label: 'Vegetables',
                        isSelected: _selectedFilter == 'Vegetables',
                        onTap: () => setState(() => _selectedFilter = 'Vegetables'),
                      ),
                      _FilterChip(
                        label: 'Dairy',
                        isSelected: _selectedFilter == 'Dairy',
                        onTap: () => setState(() => _selectedFilter = 'Dairy'),
                      ),
                      _FilterChip(
                        label: 'Meat',
                        isSelected: _selectedFilter == 'Meat',
                        onTap: () => setState(() => _selectedFilter = 'Meat'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Items list
                Expanded(
                  child: _pantryItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _pantryItems.length,
                          itemBuilder: (context, index) {
                            final item = _pantryItems[index];
                            return IngredientCard(
                              item: item,
                              onEdit: () => _showAddEditDialog(item: item),
                              onDelete: () => PantrySyncManager.instance.deleteItem(item.id),
                            );
                          },
                        ),
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

  @override
  void initState() {
    super.initState();
    // Start sync manager and listen for local item updates
    PantrySyncManager.instance.start();
    _syncSub = PantrySyncManager.instance.localStream.listen((items) {
      setState(() {
        _pantryItems
          ..clear()
          ..addAll(items);
      });
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    PantrySyncManager.instance.stop();
    super.dispose();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.kitchen_outlined,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your pantry is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add ingredients to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    _showAddEditDialog();
  }

  void _showAddEditDialog({PantryItem? item}) {
    final isNew = item == null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(text: item?.quantity ?? '');
    String category = item?.category ?? 'Other';
    DateTime? expiry = item?.expiryDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text(isNew ? 'Add Item' : 'Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: const [
                    DropdownMenuItem(value: 'Vegetables', child: Text('Vegetables')),
                    DropdownMenuItem(value: 'Dairy', child: Text('Dairy')),
                    DropdownMenuItem(value: 'Meat', child: Text('Meat')),
                    DropdownMenuItem(value: 'Fruits', child: Text('Fruits')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => category = v ?? 'Other'),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                          child: Text(expiry != null ? 'Expiry: ${_formatDate(expiry!)}' : 'No expiry'),
                        ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expiry ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => expiry = picked);
                      },
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  PantrySyncManager.instance.deleteItem(item!.id);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final qty = qtyCtrl.text.trim();
                if (name.isEmpty || qty.isEmpty) return;
                if (isNew) {
                  final newItem = PantryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    quantity: qty,
                    expiryDate: expiry,
                    category: category,
                  );
                  PantrySyncManager.instance.addItem(newItem);
                } else {
                  final updated = PantryItem(
                    id: item!.id,
                    name: name,
                    quantity: qty,
                    expiryDate: expiry,
                    category: category,
                  );
                  PantrySyncManager.instance.updateItem(updated);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            color: isSelected
                ? null
                : isDark
                    ? AppTheme.cardDark
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}