import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../../core/constants/theme/app_theme.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  String _selectedFilter = 'All';
  
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
                            return IngredientCard(item: _pantryItems[index]);
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
                  : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
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