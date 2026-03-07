// lib/ui/screens/recipe_list_screen.dart
//
// Replaces the static hardcoded list with live Spoonacular recommendations,
// ranked by the RecipeRankingEngine.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../models/recipe_filter.dart';
import '../../state/recipe_provider.dart';
import '../../state/user_provider.dart';
import '../../models/user_profile_model.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import 'spoonacular_recipe_detail_screen.dart';
import '../../services/recipe_ranking_engine.dart';
import '../../state/saved_recipes_provider.dart';
import 'saved_recipes_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final profile = context.read<UserProvider>().profile ?? UserProfileModel.defaultProfile();
    context.read<RecipeProvider>().loadRecommendations(profile: profile);
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

          SafeArea(
            child: Column(
              children: [
                _AppBarSection(onRefresh: _load),
                const _FilterBar(),
                const SizedBox(height: 8),
                const Expanded(child: _RecipeListBody()),
              ],
            ),
          ),

          const ThemeToggleFAB(),
          const AIAssistantFAB(),
        ],
      ),
    );
  }
}

// ─── App bar ─────────────────────────────────────────────────────────────────

class _AppBarSection extends StatelessWidget {
  final VoidCallback onRefresh;
  const _AppBarSection({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: Consumer<RecipeProvider>(
              builder: (_, p, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recipes',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    p.isLoading
                        ? 'Finding the best matches…'
                        : '${p.rankedRecipes.length} personalised results',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          // Saved recipes button
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SavedRecipesScreen()),
            ),
            icon: const Icon(Icons.bookmark_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          // Sort button
          Consumer<RecipeProvider>(
            builder: (ctx, p, _) => IconButton(
              onPressed: () => _showSortSheet(ctx, p),
              icon: const Icon(Icons.sort_rounded),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
              ),
            ),
          ),
          // Filter button
          Consumer<RecipeProvider>(
            builder: (ctx, p, _) => IconButton(
              onPressed: () => _showFilterSheet(ctx, p),
              icon: const Icon(Icons.tune_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context, RecipeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortBottomSheet(
        current: provider.filter.sortOrder,
        onSelected: (order) {
          provider.applyFilter(provider.filter.copyWith(sortOrder: order));
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, RecipeProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(
        current: provider.filter,
        onApply: (f) => provider.applyFilter(f),
      ),
    );
  }
}

// ─── Horizontal filter chips ─────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeProvider>(
      builder: (ctx, p, _) {
        final f = p.filter;
        final chips = <_ActiveChip>[];

        if (f.pantryOnlyMode) {
          chips.add(_ActiveChip(
              label: '🧺 Pantry only',
              onRemove: () =>
                  p.applyFilter(f.copyWith(pantryOnlyMode: false))));
        }
        if (f.maxReadyMinutes != null) {
          chips.add(_ActiveChip(
              label: '⏱ ≤${f.maxReadyMinutes}m',
              onRemove: () =>
                  p.applyFilter(f.copyWith(clearMaxReadyMinutes: true))));
        }
        if (f.maxCalories != null) {
          chips.add(_ActiveChip(
              label: '🔥 ≤${f.maxCalories} cal',
              onRemove: () => p.applyFilter(f.copyWith(maxCalories: null))));
        }
        for (final c in f.cuisines) {
          chips.add(_ActiveChip(
              label: '🍴 $c',
              onRemove: () => p.applyFilter(f.copyWith(
                  cuisines:
                      f.cuisines.where((x) => x != c).toList()))));
        }
        for (final d in f.diets) {
          chips.add(_ActiveChip(
              label: '🥗 $d',
              onRemove: () => p.applyFilter(f.copyWith(
                  diets: f.diets.where((x) => x != d).toList()))));
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => chips[i],
          ),
        );
      },
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
      backgroundColor: AppTheme.primaryPurple.withOpacity(0.12),
      labelStyle: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
      side: BorderSide(color: AppTheme.primaryPurple.withOpacity(0.3)),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─── Recipe list body ─────────────────────────────────────────────────────────

class _RecipeListBody extends StatelessWidget {
  const _RecipeListBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeProvider>(
      builder: (_, p, __) {
        if (p.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryPurple),
                SizedBox(height: 16),
                Text('Loading personalised recipes…'),
              ],
            ),
          );
        }

        if (p.loadState == RecipeLoadState.error) {
          return _ErrorState(message: p.errorMessage ?? 'Unknown error');
        }

        if (p.rankedRecipes.isEmpty) {
          return const _EmptyState();
        }

        // Build the full item list including optional banner + section header
        final items = <Widget>[];

        // Pantry match warning banner
        if (p.pantryMatchWarning) {
          items.add(const _PantryWarningBanner());
        }

        for (int i = 0; i < p.rankedRecipes.length; i++) {
          // Fallback section divider
          if (p.hasFallbackSection && i == p.fallbackStartIndex) {
            items.add(const _SectionDivider(
              label: 'Other great recipes',
              subtitle: 'Outside your selected cuisine — ranked by best overall match',
            ));
          }
          items.add(_RankedRecipeCard(
            ranked: p.rankedRecipes[i],
            rank: i + 1,
          ));
        }

        return RefreshIndicator(
          onRefresh: p.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: items,
          ),
        );
      },
    );
  }
}

// ─── Ranked recipe card ───────────────────────────────────────────────────────

class _RankedRecipeCard extends StatelessWidget {
  final RankedRecipe ranked;
  final int rank;
  const _RankedRecipeCard({required this.ranked, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = ranked.recipe;
    final score = ranked.totalScore;

    Color matchColor;
    if (score >= 70) matchColor = AppTheme.successGreen;
    else if (score >= 45) matchColor = AppTheme.warningYellow;
    else matchColor = AppTheme.textSecondaryLight;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpoonacularRecipeDetailScreen(ranked: ranked),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / header
            _CardHeader(ranked: ranked, rank: rank, score: score, matchColor: matchColor),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(r.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),

                  // Quick stats row
                  _QuickStats(recipe: r),
                  const SizedBox(height: 10),

                  // Pantry bar
                  _PantryBar(
                      have: ranked.pantryIngredients.length,
                      total: r.ingredients.length),
                  const SizedBox(height: 10),

                  // Match reasons
                  if (ranked.matchReasons.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ranked.matchReasons
                          .take(3)
                          .map((reason) => _ReasonChip(reason))
                          .toList(),
                    ),

                  const SizedBox(height: 8),

                  // Missing ingredients note
                  if (ranked.missingIngredients.isNotEmpty)
                    Text(
                      'Missing: ${ranked.missingIngredients.take(3).join(', ')}'
                      '${ranked.missingIngredients.length > 3 ? ' +${ranked.missingIngredients.length - 3} more' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final RankedRecipe ranked;
  final int rank;
  final double score;
  final Color matchColor;
  const _CardHeader(
      {required this.ranked,
      required this.rank,
      required this.score,
      required this.matchColor});

  @override
  Widget build(BuildContext context) {
    final recipe = ranked.recipe;
    return Stack(
      children: [
        // Recipe image or placeholder gradient
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: recipe.image != null
              ? Image.network(
                  recipe.image!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderGradient(recipe),
                )
              : _placeholderGradient(recipe),
        ),

        // Rank badge
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ),

        // Score badge
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: matchColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${score.toStringAsFixed(0)} pts',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ),

        // Bookmark button
        Positioned(
          bottom: 10,
          right: 10,
          child: Consumer<SavedRecipesProvider>(
            builder: (ctx, sp, _) {
              final saved = sp.isSaved(recipe.id);
              return GestureDetector(
                onTap: () => sp.toggle(recipe),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: saved ? AppTheme.warningYellow : Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _placeholderGradient(dynamic recipe) {
    final colors = [
      [const Color(0xFF6C63FF), const Color(0xFF5B54E8)],
      [const Color(0xFF00D4AA), const Color(0xFF00B894)],
      [const Color(0xFFFF6B6B), const Color(0xFFEE5A6F)],
      [const Color(0xFFFFB800), const Color(0xFFFFA000)],
    ];
    final pair = colors[recipe.id % colors.length];
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: pair),
      ),
      child: Center(
        child: Text(
          recipe.title.isNotEmpty ? recipe.title[0] : '🍽',
          style: const TextStyle(fontSize: 64, color: Colors.white),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final dynamic recipe;
  const _QuickStats({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(
            icon: Icons.access_time_rounded,
            label: '${recipe.readyInMinutes}m',
            color: AppTheme.infoBlue),
        const SizedBox(width: 12),
        _Stat(
            icon: Icons.local_fire_department_rounded,
            label: '${recipe.nutrition.calories.round()} cal',
            color: AppTheme.accentOrange),
        const SizedBox(width: 12),
        _Stat(
            icon: Icons.people_rounded,
            label: '${recipe.servings} serv',
            color: AppTheme.successGreen),
        if (recipe.cuisines.isNotEmpty) ...[
          const SizedBox(width: 12),
          _Stat(
              icon: Icons.public_rounded,
              label: (recipe.cuisines as List).first.toString(),
              color: AppTheme.primaryPurple),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Stat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PantryBar extends StatelessWidget {
  final int have;
  final int total;
  const _PantryBar({required this.have, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 1.0 : have / total;
    final pctLabel = (pct * 100).round();

    Color barColor;
    if (pct >= 0.8) barColor = AppTheme.successGreen;
    else if (pct >= 0.5) barColor = AppTheme.warningYellow;
    else barColor = AppTheme.accentOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pantry match',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight)),
            Text('$have/$total ($pctLabel%)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: barColor)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: barColor.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String text;
  const _ReasonChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.primaryPurple.withOpacity(0.2)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primaryPurple,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Pantry warning banner ────────────────────────────────────────────────────

class _PantryWarningBanner extends StatelessWidget {
  const _PantryWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningYellow.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🧺', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Limited pantry matches',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningYellow),
                ),
                SizedBox(height: 2),
                Text(
                  'None of these recipes closely match your current pantry — showing the best overall results for your preferences.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section divider ──────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  final String subtitle;
  const _SectionDivider({required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primaryPurple),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text('No recipes found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Try adding items to your pantry first,\nor adjust your filters.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<RecipeProvider>().refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppTheme.accentOrange),
            const SizedBox(height: 16),
            const Text('Could not load recipes',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<RecipeProvider>().refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sort bottom sheet ────────────────────────────────────────────────────────

class _SortBottomSheet extends StatelessWidget {
  final RecipeSortOrder current;
  final ValueChanged<RecipeSortOrder> onSelected;
  const _SortBottomSheet(
      {required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sort by',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...RecipeSortOrder.values.map((order) => ListTile(
                title: Text(order.label),
                leading: Radio<RecipeSortOrder>(
                  value: order,
                  groupValue: current,
                  onChanged: (v) {
                    if (v != null) {
                      onSelected(v);
                      Navigator.pop(context);
                    }
                  },
                  activeColor: AppTheme.primaryPurple,
                ),
                onTap: () {
                  onSelected(order);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }
}

// ─── Filter bottom sheet ──────────────────────────────────────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final RecipeFilter current;
  final ValueChanged<RecipeFilter> onApply;
  const _FilterBottomSheet(
      {required this.current, required this.onApply});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late RecipeFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('Filters',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(
                        () => _draft = const RecipeFilter()),
                    child: const Text('Reset all'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  // Pantry only mode
                  _SwitchTile(
                    label: '🧺 Pantry-only mode',
                    subtitle: 'Show only recipes I can cook now',
                    value: _draft.pantryOnlyMode,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(pantryOnlyMode: v)),
                  ),
                  const SizedBox(height: 12),

                  // Max time
                  _SliderSection(
                    label: '⏱ Max cook time',
                    value: _draft.maxReadyMinutes?.toDouble() ?? 120,
                    min: 10,
                    max: 120,
                    divisions: 11,
                    displayValue: _draft.maxReadyMinutes != null
                        ? '${_draft.maxReadyMinutes}m'
                        : 'Any',
                    onChanged: (v) => setState(() => _draft =
                        _draft.copyWith(maxReadyMinutes: v.round())),
                    onReset: () => setState(
                        () => _draft = _draft.copyWith(clearMaxReadyMinutes: true)),
                  ),
                  const SizedBox(height: 12),

                  // Max calories
                  _SliderSection(
                    label: '🔥 Max calories',
                    value: _draft.maxCalories?.toDouble() ?? 1200,
                    min: 200,
                    max: 1200,
                    divisions: 10,
                    displayValue: _draft.maxCalories != null
                        ? '${_draft.maxCalories} cal'
                        : 'Any',
                    onChanged: (v) => setState(() =>
                        _draft = _draft.copyWith(maxCalories: v.round())),
                    onReset: () =>
                        setState(() => _draft = _draft.copyWith(maxCalories: null)),
                  ),
                  const SizedBox(height: 16),

                  // Cuisine chips
                  _ChipSection(
                    label: 'Cuisine',
                    options: const [
                      'Italian', 'Asian', 'Mexican', 'Indian', 'Mediterranean',
                      'American', 'French', 'Japanese', 'Thai', 'Chinese',
                      'Greek', 'Spanish', 'Middle Eastern',
                    ],
                    selected: _draft.cuisines,
                    onToggle: (c) {
                      final current = List<String>.from(_draft.cuisines);
                      current.contains(c)
                          ? current.remove(c)
                          : current.add(c);
                      setState(
                          () => _draft = _draft.copyWith(cuisines: current));
                    },
                  ),
                  const SizedBox(height: 16),

                  // Diet chips
                  _ChipSection(
                    label: 'Diet',
                    options: const [
                      'Vegetarian', 'Vegan', 'Gluten Free', 'Ketogenic',
                      'Paleo', 'Pescetarian', 'Whole30', 'Low FODMAP',
                    ],
                    selected: _draft.diets,
                    onToggle: (d) {
                      final current = List<String>.from(_draft.diets);
                      current.contains(d)
                          ? current.remove(d)
                          : current.add(d);
                      setState(
                          () => _draft = _draft.copyWith(diets: current));
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dish type chips
                  _ChipSection(
                    label: 'Dish type',
                    options: const [
                      'Breakfast', 'Lunch', 'Dinner', 'Main Course',
                      'Side Dish', 'Salad', 'Soup', 'Dessert', 'Snack',
                    ],
                    selected: _draft.dishTypes,
                    onToggle: (d) {
                      final current = List<String>.from(_draft.dishTypes);
                      current.contains(d)
                          ? current.remove(d)
                          : current.add(d);
                      setState(
                          () => _draft = _draft.copyWith(dishTypes: current));
                    },
                  ),
                ],
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_draft);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52)),
                  child: const Text('Apply Filters'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryPurple,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _SliderSection extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  const _SliderSection({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(displayValue,
                style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onReset,
              child: const Icon(Icons.close,
                  size: 16, color: AppTheme.textSecondaryLight),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: AppTheme.primaryPurple,
        ),
      ],
    );
  }
}

class _ChipSection extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _ChipSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLower = selected.map((s) => s.toLowerCase()).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((opt) {
            final isSelected = selectedLower.contains(opt.toLowerCase());
            return GestureDetector(
              onTap: () => onToggle(opt.toLowerCase()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryPurple
                      : AppTheme.primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.primaryPurple.withOpacity(0.2)),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.primaryPurple,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}