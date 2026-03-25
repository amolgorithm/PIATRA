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

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  final List<PantryItem> _pantryItems = [];
  StreamSubscription<List<PantryItem>>? _syncSub;

  late AnimationController _entranceCtrl;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _entranceFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    PantrySyncManager.instance.start();
    _syncSub = PantrySyncManager.instance.localStream.listen((items) {
      setState(() {
        _pantryItems..clear()..addAll(items);
      });
    });

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    PantrySyncManager.instance.stop();
    _entranceCtrl.dispose();
    super.dispose();
  }

  List<PantryItem> get _filteredItems {
    switch (_selectedFilter) {
      case 'Expiring Soon':
        return _pantryItems.where((i) => i.isExpiringSoon).toList();
      case 'Vegetables':
      case 'Dairy':
      case 'Meat':
        return _pantryItems
            .where((i) => i.category.toLowerCase() == _selectedFilter.toLowerCase())
            .toList();
      default:
        return _pantryItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background
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
          // Ambient orb
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryPurple.withOpacity(isDark ? 0.15 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Column(
                  children: [
                    _buildAppBar(isDark),
                    _buildStats(isDark),
                    const SizedBox(height: 16),
                    _buildFilterBar(isDark),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _filteredItems.isEmpty
                          ? _buildEmptyState(isDark)
                          : _buildList(),
                    ),
                  ],
                ),
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.arrow_back_rounded,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Pantry',
                    style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  '${_pantryItems.length} items tracked',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _GradientButton(
            icon: Icons.add_rounded,
            onTap: _showAddItemDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildStats(bool isDark) {
    final expiring = _pantryItems.where((i) => i.isExpiringSoon).length;
    final expired = _pantryItems.where((i) => i.isExpired).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _MiniStat(
            label: 'Total',
            value: '${_pantryItems.length}',
            color: AppTheme.primaryPurple,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _MiniStat(
            label: 'Expiring',
            value: '$expiring',
            color: AppTheme.warningYellow,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _MiniStat(
            label: 'Expired',
            value: '$expired',
            color: AppTheme.errorRed,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final filters = ['All', 'Expiring Soon', 'Vegetables', 'Dairy', 'Meat'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _FilterChip(
          label: filters[i],
          isSelected: _selectedFilter == filters[i],
          isDark: isDark,
          onTap: () => setState(() => _selectedFilter = filters[i]),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _AnimatedListItem(
          index: index,
          child: IngredientCard(
            item: item,
            onEdit: () => _showAddEditDialog(item: item),
            onDelete: () => PantrySyncManager.instance.deleteItem(item.id),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.kitchen_outlined, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text('Your pantry is empty',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Add ingredients to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _showAddItemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() => _showAddEditDialog();

  void _showAddEditDialog({PantryItem? item}) {
    final isNew = item == null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(text: item?.quantity ?? '');
    String category = item?.category ?? 'Other';
    DateTime? expiry = item?.expiryDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isNew ? 'Add Item' : 'Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
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
                      child: Text(expiry != null
                          ? 'Expiry: ${_fmt(expiry!)}'
                          : 'No expiry date'),
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
                child: const Text('Delete',
                    style: TextStyle(color: AppTheme.errorRed)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final qty = qtyCtrl.text.trim();
                if (name.isEmpty || qty.isEmpty) return;
                if (isNew) {
                  PantrySyncManager.instance.addItem(PantryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    quantity: qty,
                    expiryDate: expiry,
                    category: category,
                  ));
                } else {
                  PantrySyncManager.instance.updateItem(PantryItem(
                    id: item!.id,
                    name: name,
                    quantity: qty,
                    expiryDate: expiry,
                    category: category,
                  ));
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
            size: 20),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GradientButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _MiniStat({
    required this.label, required this.value,
    required this.color, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Text(value,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, required this.isSelected,
    required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected
              ? null
              : isDark
                  ? AppTheme.cardDark
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                    ? const Color(0x20FFFFFF)
                    : const Color(0x14000000),
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: AppTheme.primaryPurple.withOpacity(0.35),
                  blurRadius: 8, offset: const Offset(0, 3),
                )]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
          ),
        ),
      ),
    );
  }
}

// Staggered list item animation
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}