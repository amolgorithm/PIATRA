import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../widgets/ingredient_card.dart';
import '../../core/constants/theme/app_theme.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  // Hardcoded sample data for now
  final List<PantryItem> _pantryItems = [
    PantryItem(
      id: '1',
      name: 'Lettuce',
      quantity: '2 heads',
      expiryDate: DateTime.now().add(const Duration(days: 3)),
      category: 'Vegetables',
    ),
    PantryItem(
      id: '2',
      name: 'Tomatoes',
      quantity: '5',
      expiryDate: DateTime.now().add(const Duration(days: 6)),
      category: 'Vegetables',
    ),
    PantryItem(
      id: '3',
      name: 'Cheese',
      quantity: '1 block',
      expiryDate: DateTime.now().add(const Duration(days: 14)),
      category: 'Dairy',
    ),
    PantryItem(
      id: '4',
      name: 'Milk',
      quantity: '2 liters',
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      category: 'Dairy',
    ),
    PantryItem(
      id: '5',
      name: 'Chicken Breast',
      quantity: '500g',
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      category: 'Meat',
    ),
    PantryItem(
      id: '6',
      name: 'Eggs',
      quantity: '12',
      expiryDate: DateTime.now().add(const Duration(days: 10)),
      category: 'Dairy',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pantry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
          ),
        ],
      ),
      body: _pantryItems.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _pantryItems.length,
              itemBuilder: (context, index) {
                return IngredientCard(item: _pantryItems[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Your pantry is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add ingredients to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: const Text(
          'Manual ingredient entry coming soon!\nFor now, use the scan feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}