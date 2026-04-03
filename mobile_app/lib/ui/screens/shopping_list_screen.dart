// lib/ui/screens/shopping_list_screen.dart
//
// Displays a generated shopping list.  Users can check off items as
// they shop. Progress bar at the top, items grouped alphabetically,
// pantry-available items shown in a separate "Already have" section.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../services/meal_plan_service.dart';

class ShoppingListScreen extends StatefulWidget {
  final ShoppingList shoppingList;
  const ShoppingListScreen({super.key, required this.shoppingList});

  @override
  State<ShoppingListScreen> createState() =>
      _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late ShoppingList _list;
  bool _showHave = false;

  @override
  void initState() {
    super.initState();
    _list = widget.shoppingList;
  }

  Future<void> _toggleItem(int index, bool value) async {
    setState(() {
      final updated = List<ShoppingItem>.from(_list.items);
      updated[index] = ShoppingItem(
        name:          _list.items[index].name,
        amount:        _list.items[index].amount,
        unit:          _list.items[index].unit,
        isChecked:     value,
        usedInRecipes: _list.items[index].usedInRecipes,
      );
      _list = ShoppingList(
        id:              _list.id,
        weekKey:         _list.weekKey,
        title:           _list.title,
        items:           updated,
        alreadyInPantry: _list.alreadyInPantry,
        createdAt:       _list.createdAt,
      );
    });

    if (_list.id.isNotEmpty) {
      await MealPlanService.instance.updateShoppingListItem(
        listId:    _list.id,
        itemIndex: index,
        isChecked: value,
      );
    }
  }

  void _copyToClipboard() {
    final unchecked = _list.items.where((i) => !i.isChecked).toList();
    final sb = StringBuffer();
    sb.writeln('Shopping List — ${_list.title ?? ''}');
    sb.writeln('');
    for (final item in unchecked) {
      final amt = item.amount > 0
          ? '${item.amount % 1 == 0 ? item.amount.toInt() : item.amount.toStringAsFixed(1)} ${item.unit}'
          : '';
      sb.writeln('• ${item.name}${amt.isNotEmpty ? ' ($amt)' : ''}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shopping list copied to clipboard!'),
        backgroundColor: AppTheme.successGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final progress = _list.progress;
    final checked  = _list.checkedCount;
    final total    = _list.totalCount;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, progress, checked, total),
            Expanded(
              child: total == 0
                  ? _buildEmpty(isDark)
                  : _buildList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      bool isDark, double progress, int checked, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shopping List',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      _list.title ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy to clipboard',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: progress >= 1.0
                  ? AppTheme.accentGradient
                  : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progress >= 1.0 ? '🎉 All done!' : '$checked of $total items',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    final unchecked = _list.items.where((i) => !i.isChecked).toList();
    final checked   = _list.items.where((i) => i.isChecked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // To buy
        if (unchecked.isNotEmpty) ...[
          _ListSection(
              text: 'To Buy (${unchecked.length})',
              isDark: isDark),
          ...unchecked.map((item) {
            final idx = _list.items.indexOf(item);
            return _ShoppingItemTile(
              item:     item,
              isDark:   isDark,
              onToggle: (v) => _toggleItem(idx, v),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Checked
        if (checked.isNotEmpty) ...[
          _ListSection(
              text: 'In Cart (${checked.length})',
              isDark: isDark,
              color: AppTheme.successGreen),
          ...checked.map((item) {
            final idx = _list.items.indexOf(item);
            return _ShoppingItemTile(
              item:     item,
              isDark:   isDark,
              onToggle: (v) => _toggleItem(idx, v),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Already in pantry
        if (_list.alreadyInPantry.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() => _showHave = !_showHave),
            child: _ListSection(
              text:
                  'Already Have (${_list.alreadyInPantry.length}) ${_showHave ? '▲' : '▼'}',
              isDark: isDark,
              color: AppTheme.infoBlue,
            ),
          ),
          if (_showHave)
            ...List.generate(_list.alreadyInPantry.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.infoBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.infoBlue, size: 18),
                    const SizedBox(width: 10),
                    Text(_list.alreadyInPantry[i],
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.infoBlue,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_rounded,
                size: 52, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text('Everything in your pantry!',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('All ingredients for this meal plan\nare already in your pantry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color color;
  const _ListSection({
    required this.text,
    required this.isDark,
    this.color = AppTheme.primaryPurple,
  }) : title = text;

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color),
        ),
      );
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final bool isDark;
  final ValueChanged<bool> onToggle;

  const _ShoppingItemTile({
    required this.item,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final amtStr = item.amount > 0
        ? '${item.amount % 1 == 0 ? item.amount.toInt() : item.amount.toStringAsFixed(1)} ${item.unit}'
        : '';

    return GestureDetector(
      onTap: () => onToggle(!item.isChecked),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: item.isChecked
              ? AppTheme.successGreen.withOpacity(0.07)
              : (isDark ? AppTheme.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isChecked
                ? AppTheme.successGreen.withOpacity(0.3)
                : (isDark ? Colors.white : Colors.black).withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: item.isChecked
                    ? AppTheme.successGreen
                    : Colors.transparent,
                border: Border.all(
                  color: item.isChecked
                      ? AppTheme.successGreen
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 1.8,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: item.isChecked
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 15)
                  : null,
            ),
            const SizedBox(width: 12),
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: item.isChecked
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.isChecked
                          ? (isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight)
                          : null,
                    ),
                  ),
                  if (amtStr.isNotEmpty || item.usedInRecipes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (amtStr.isNotEmpty) amtStr,
                        if (item.usedInRecipes.isNotEmpty)
                          'for ${item.usedInRecipes.take(2).join(', ')}',
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
