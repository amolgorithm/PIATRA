// lib/ui/screens/saved_recipes_screen.dart
//
// Full-screen saved recipes manager: view, search, and remove saved recipes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../services/saved_recipes_service.dart';
import '../../state/saved_recipes_provider.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedRecipesProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildSearchBar(isDark),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
            child: Consumer<SavedRecipesProvider>(
              builder: (_, p, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved Recipes',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    '${p.savedList.length} recipe${p.savedList.length == 1 ? '' : 's'} saved',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          // Clear all button
          Consumer<SavedRecipesProvider>(
            builder: (ctx, p, _) => p.savedList.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () => _confirmClearAll(ctx, p),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                      foregroundColor: AppTheme.accentOrange,
                    ),
                    tooltip: 'Clear all',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search saved recipes…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? AppTheme.cardDark : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return Consumer<SavedRecipesProvider>(
      builder: (_, p, __) {
        if (p.loading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          );
        }

        if (p.savedList.isEmpty) {
          return _buildEmptyState(isDark);
        }

        final filtered = _query.isEmpty
            ? p.savedList
            : p.savedList
                .where((r) => r.title.toLowerCase().contains(_query))
                .toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔍', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('No results for "$_query"',
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondaryLight)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _SavedRecipeCard(
            recipe: filtered[i],
            isDark: isDark,
            onRemove: () => _removeRecipe(p, filtered[i]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_border_rounded,
                  size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'No saved recipes yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the bookmark icon on any recipe to save it for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: AppTheme.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  void _removeRecipe(SavedRecipesProvider p, SavedRecipe recipe) async {
    await p.remove(recipe.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Re-save — we only have SavedRecipe not SpoonacularRecipe here,
              // so just reload from Firestore
              p.loadAll();
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _confirmClearAll(BuildContext context, SavedRecipesProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all saved recipes?'),
        content:
            const Text('This will remove all ${0} saved recipes permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange),
            onPressed: () async {
              Navigator.pop(context);
              for (final r in List.from(p.savedList)) {
                await p.remove(r.id);
              }
            },
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}

// ─── Saved recipe card ────────────────────────────────────────────────────────

class _SavedRecipeCard extends StatelessWidget {
  final SavedRecipe recipe;
  final bool isDark;
  final VoidCallback onRemove;

  const _SavedRecipeCard({
    required this.recipe,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('saved_${recipe.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onRemove(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18)),
              child: recipe.image != null
                  ? Image.network(
                      recipe.image!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _placeholder(recipe),
                    )
                  : _placeholder(recipe),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _MiniChip(
                            icon: Icons.access_time_rounded,
                            label: '${recipe.readyInMinutes}m',
                            color: AppTheme.infoBlue),
                        const SizedBox(width: 6),
                        _MiniChip(
                            icon: Icons.local_fire_department_rounded,
                            label: '${recipe.calories.round()} cal',
                            color: AppTheme.accentOrange),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (recipe.vegan)
                          _DietTag('Vegan', AppTheme.successGreen),
                        if (!recipe.vegan && recipe.vegetarian)
                          _DietTag('Vegetarian', AppTheme.successGreen),
                        if (recipe.glutenFree)
                          _DietTag('GF', AppTheme.infoBlue),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Delete button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.bookmark_remove_rounded),
                color: AppTheme.accentOrange,
                iconSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(SavedRecipe r) {
    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: Center(
        child: Text(
          r.title.isNotEmpty ? r.title[0] : '🍽',
          style: const TextStyle(fontSize: 36, color: Colors.white),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DietTag extends StatelessWidget {
  final String label;
  final Color color;
  const _DietTag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}