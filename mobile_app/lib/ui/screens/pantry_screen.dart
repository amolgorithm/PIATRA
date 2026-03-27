import 'dart:async';
import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  String _selectedFilter = 'All';
  String _searchQuery    = '';
  bool   _showSearch     = false;
  final List<PantryItem>          _pantryItems   = [];
  StreamSubscription<List<PantryItem>>? _syncSub;
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late AnimationController _searchBarCtrl;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;
  late Animation<double> _searchBarSize;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _searchBarCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280),
    );

    _entranceFade  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    _searchBarSize = CurvedAnimation(
        parent: _searchBarCtrl, curve: Curves.easeOutCubic);

    PantrySyncManager.instance.start();
    _syncSub = PantrySyncManager.instance.localStream.listen((items) {
      if (mounted) setState(() { _pantryItems..clear()..addAll(items); });
    });

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    // Do NOT call stop() here — other screens may share the manager
    _entranceCtrl.dispose();
    _searchBarCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<PantryItem> get _filtered {
    List<PantryItem> base;
    switch (_selectedFilter) {
      case 'Expiring Soon':
        base = _pantryItems.where((i) => i.isExpiringSoon).toList();
        break;
      case 'Vegetables':
      case 'Dairy':
      case 'Meat':
      case 'Fruits':
        base = _pantryItems
            .where((i) =>
                i.category.toLowerCase() ==
                _selectedFilter.toLowerCase())
            .toList();
        break;
      default:
        base = List.of(_pantryItems);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    return base;
  }

  // ── Search toggle ─────────────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (_showSearch) {
      _searchBarCtrl.forward();
    } else {
      _searchBarCtrl.reverse();
      _searchCtrl.clear();
      setState(() => _searchQuery = '');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items  = _filtered;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(isDark),
          SafeArea(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: Column(
                  children: [
                    _buildAppBar(isDark),
                    // Animated search bar
                    SizeTransition(
                      sizeFactor: _searchBarSize,
                      axisAlignment: -1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: _SearchField(
                          controller: _searchCtrl,
                          isDark: isDark,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                        ),
                      ),
                    ),
                    _buildStats(isDark),
                    const SizedBox(height: 14),
                    _buildFilterBar(isDark),
                    const SizedBox(height: 10),
                    Expanded(
                      child: items.isEmpty
                          ? _buildEmpty(isDark)
                          : _buildList(items),
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

  Widget _buildBackground(bool isDark) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
                : [AppTheme.backgroundLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60, right: -80,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.primaryPurple
                        .withOpacity(isDark ? 0.15 : 0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _GlassBtn(
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '${_pantryItems.length} item${_pantryItems.length == 1 ? '' : 's'} tracked',
                    key: ValueKey(_pantryItems.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          _GlassBtn(
            icon: _showSearch
                ? Icons.search_off_rounded
                : Icons.search_rounded,
            isDark: isDark,
            onTap: _toggleSearch,
          ),
          const SizedBox(width: 8),
          _GradientBtn(icon: Icons.add_rounded, onTap: _showAddDialog),
        ],
      ),
    );
  }

  Widget _buildStats(bool isDark) {
    final expiring = _pantryItems.where((i) => i.isExpiringSoon).length;
    final expired  = _pantryItems.where((i) => i.isExpired).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _MiniStat(label: 'Total',    value: '${_pantryItems.length}', color: AppTheme.primaryPurple,  isDark: isDark),
          const SizedBox(width: 10),
          _MiniStat(label: 'Expiring', value: '$expiring',             color: AppTheme.warningYellow,  isDark: isDark),
          const SizedBox(width: 10),
          _MiniStat(label: 'Expired',  value: '$expired',              color: AppTheme.errorRed,       isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    const filters = ['All', 'Expiring Soon', 'Vegetables', 'Dairy', 'Meat', 'Fruits'];
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

  Widget _buildList(List<PantryItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      // Key on id so Flutter can reuse tiles efficiently
      itemBuilder: (ctx, i) {
        final item = items[i];
        return _StaggeredTile(
          // Cap stagger at index 12 to avoid long delays on large lists
          delayMs: math.min(i, 12) * 38,
          key: ValueKey(item.id),
          child: IngredientCard(
            item: item,
            onEdit: () => _showAddEditDialog(item: item),
            onDelete: () => PantrySyncManager.instance.deleteItem(item.id),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(bool isDark) {
    final isSearching = _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: isSearching
                  ? const LinearGradient(
                      colors: [Color(0xFFFFB347), Color(0xFFFF8C00)])
                  : AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isSearching
                          ? AppTheme.accentOrange
                          : AppTheme.primaryPurple)
                      .withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.kitchen_outlined,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'No results found' : 'Your pantry is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'Try a different search term'
                : 'Add ingredients to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddDialog() => _showAddEditDialog();

  void _showAddEditDialog({PantryItem? item}) {
    final isNew  = item == null;
    final namCtrl = TextEditingController(text: item?.name ?? '');
    final qtyCtrl = TextEditingController(text: item?.quantity ?? '');
    String    cat    = item?.category ?? 'Other';
    DateTime? expiry = item?.expiryDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isNew ? 'Add Item' : 'Edit Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'Vegetables',      child: Text('🥦 Vegetables')),
                    DropdownMenuItem(value: 'Fruits',          child: Text('🍎 Fruits')),
                    DropdownMenuItem(value: 'Dairy',           child: Text('🥛 Dairy')),
                    DropdownMenuItem(value: 'Meat',            child: Text('🥩 Meat')),
                    DropdownMenuItem(value: 'Grains & Legumes',child: Text('🌾 Grains & Legumes')),
                    DropdownMenuItem(value: 'Beverages',       child: Text('🧃 Beverages')),
                    DropdownMenuItem(value: 'Bakery',          child: Text('🍞 Bakery')),
                    DropdownMenuItem(value: 'Other',           child: Text('📦 Other')),
                  ],
                  onChanged: (v) => setS(() => cat = v ?? 'Other'),
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
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: expiry ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setS(() => expiry = d);
                      },
                      child: const Text('Pick date'),
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
                  Navigator.pop(ctx);
                  PantrySyncManager.instance.deleteItem(item!.id);
                },
                child: const Text('Delete',
                    style: TextStyle(color: AppTheme.errorRed)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = namCtrl.text.trim();
                final qty  = qtyCtrl.text.trim();
                if (name.isEmpty || qty.isEmpty) return;
                if (isNew) {
                  PantrySyncManager.instance.addItem(PantryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name, quantity: qty,
                    expiryDate: expiry, category: cat,
                  ));
                } else {
                  PantrySyncManager.instance.updateItem(PantryItem(
                    id: item!.id, name: name, quantity: qty,
                    expiryDate: expiry, category: cat,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  const _SearchField({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.28),
          width: 1.4,
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search pantry…',
          border: InputBorder.none,
          filled: false,
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.primaryPurple, size: 20),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _GlassBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0x18FFFFFF)
                  : const Color(0x10000000),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(isDark ? 0.24 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon,
              color: isDark
                  ? AppTheme.textPrimaryDark
                  : AppTheme.textPrimaryLight,
              size: 20),
        ),
      );
}

class _GradientBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GradientBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.42),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
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
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
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
                ? [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.36),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
            ),
          ),
        ),
      );
}

/// Staggered entrance tile — uses a one-shot AnimationController
class _StaggeredTile extends StatefulWidget {
  final int delayMs;
  final Widget child;
  const _StaggeredTile(
      {required this.delayMs, required this.child, super.key});

  @override
  State<_StaggeredTile> createState() => _StaggeredTileState();
}

class _StaggeredTileState extends State<_StaggeredTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.14), end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
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