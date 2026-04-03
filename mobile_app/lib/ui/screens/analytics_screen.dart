// lib/ui/screens/analytics_screen.dart
//
// Full-featured Analytics & Insights screen.
// Tabs:
//   1. Overview  — today's summary, weekly calorie chart, macro ring
//   2. History   — scrollable log of all cooked meals
//   3. Insights  — top recipes, cuisine breakdown, streak stats

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme/app_theme.dart';
import '../../models/user_profile_model.dart';
import '../../services/nutrition_history_service.dart';
import '../../services/recipe_history_service.dart';
import '../../state/user_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  List<NutritionLogEntry> _entries30d = [];
  List<CookedRecipe>      _cookHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await NutritionHistoryService.instance.loadLastDays(30);
    final history = await RecipeHistoryService.instance.loadAll();
    if (mounted) {
      setState(() {
        _entries30d  = entries;
        _cookHistory = history;
        _loading     = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverAppBar(isDark),
        ],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryPurple))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _OverviewTab(
                    entries: _entries30d,
                    cookHistory: _cookHistory,
                    onRefresh: _load,
                  ),
                  _HistoryTab(entries: _entries30d, onRefresh: _load),
                  _InsightsTab(
                    entries: _entries30d,
                    cookHistory: _cookHistory,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analytics',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8)),
            Text('Last 30 days',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight)),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primaryPurple,
          unselectedLabelColor: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
          indicatorColor: AppTheme.primaryPurple,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Overview
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final List<NutritionLogEntry> entries;
  final List<CookedRecipe>      cookHistory;
  final VoidCallback            onRefresh;

  const _OverviewTab({
    required this.entries,
    required this.cookHistory,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<UserProvider>().profile;
    final calorieTarget = profile?.calorieTarget.toDouble() ?? 2000;

    final summaries  = NutritionHistoryService.instance.groupByDay(entries);
    final todaySummary = summaries.isNotEmpty &&
            _isSameDay(summaries.first.date, DateTime.now())
        ? summaries.first
        : null;
    final todayCalories = todaySummary?.calories ?? 0;
    final todayProtein  = todaySummary?.protein  ?? 0;
    final todayCarbs    = todaySummary?.carbs    ?? 0;
    final todayFat      = todaySummary?.fat      ?? 0;

    // Last 7 days for the bar chart
    final last7 = <DailySummary>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final match = summaries.where((s) => _isSameDay(s.date, d));
      last7.add(match.isNotEmpty
          ? match.first
          : DailySummary(date: d, entries: []));
    }

    final macroTargets = MacroTargets.fromCalories(calorieTarget.round());

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Today's calorie ring
          _CalorieRingCard(
            consumed:      todayCalories,
            target:        calorieTarget,
            protein:       todayProtein,
            carbs:         todayCarbs,
            fat:           todayFat,
            proteinTarget: macroTargets.proteinG / 3,
            carbsTarget:   macroTargets.carbsG / 3,
            fatTarget:     macroTargets.fatG / 3,
            isDark:        isDark,
          ),
          const SizedBox(height: 20),

          // Weekly calorie bar chart
          _SectionHeader('This Week', Icons.bar_chart_rounded, isDark),
          const SizedBox(height: 12),
          _WeeklyBarChart(
            days:   last7,
            target: calorieTarget,
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // Quick stat cards
          _SectionHeader('30-Day Stats', Icons.insights_rounded, isDark),
          const SizedBox(height: 12),
          _QuickStatsGrid(
            entries:     entries,
            cookHistory: cookHistory,
            isDark:      isDark,
          ),
          const SizedBox(height: 20),

          // Recent meals
          if (entries.isNotEmpty) ...[
            _SectionHeader('Recent Meals', Icons.restaurant_rounded, isDark),
            const SizedBox(height: 12),
            ...entries.take(5).map((e) => _MealLogTile(entry: e, isDark: isDark)),
          ] else
            _EmptyState(isDark: isDark),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — History
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  final List<NutritionLogEntry> entries;
  final VoidCallback onRefresh;

  const _HistoryTab({required this.entries, required this.onRefresh});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaries =
        NutritionHistoryService.instance.groupByDay(widget.entries);

    if (summaries.isEmpty) {
      return _EmptyState(isDark: isDark);
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: summaries.length,
        itemBuilder: (_, i) {
          final day = summaries[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DayHeader(summary: day, isDark: isDark),
              const SizedBox(height: 8),
              ...day.entries.map((e) => _MealLogTile(
                    entry: e,
                    isDark: isDark,
                    showDelete: true,
                    onDelete: () async {
                      await NutritionHistoryService.instance
                          .deleteEntry(e.id);
                      widget.onRefresh();
                    },
                  )),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Insights
// ─────────────────────────────────────────────────────────────────────────────

class _InsightsTab extends StatelessWidget {
  final List<NutritionLogEntry> entries;
  final List<CookedRecipe>      cookHistory;

  const _InsightsTab({required this.entries, required this.cookHistory});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final svc       = NutritionHistoryService.instance;
    final topRecipes = svc.topRecipes(entries, top: 5);
    final cuisineFreq = svc.cuisineFrequency(entries);
    final topCuisines = (cuisineFreq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .toList();

    // Cook streak
    final streak = _computeStreak(entries);
    // Average macros per day
    final summaries = svc.groupByDay(entries);
    final avgCal = summaries.isEmpty
        ? 0.0
        : summaries.fold(0.0, (s, d) => s + d.calories) / summaries.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Streak + avg cal banner
        _StreakBanner(streak: streak, avgCal: avgCal, isDark: isDark),
        const SizedBox(height: 20),

        // Most cooked recipes
        if (topRecipes.isNotEmpty) ...[
          _SectionHeader('Most Cooked', Icons.repeat_rounded, isDark),
          const SizedBox(height: 12),
          ...topRecipes.asMap().entries.map((e) => _TopRecipeRow(
                rank:  e.key + 1,
                title: e.value.key,
                count: e.value.value,
                isDark: isDark,
              )),
          const SizedBox(height: 20),
        ],

        // Cuisine breakdown
        if (topCuisines.isNotEmpty) ...[
          _SectionHeader('Cuisine Breakdown', Icons.public_rounded, isDark),
          const SizedBox(height: 12),
          _CuisineChart(cuisines: topCuisines, isDark: isDark),
          const SizedBox(height: 20),
        ],

        // Recent from history (cook-again list)
        if (cookHistory.isNotEmpty) ...[
          _SectionHeader('Cook Again 🔁', Icons.history_rounded, isDark),
          const SizedBox(height: 12),
          ...cookHistory.take(5).map((r) =>
              _CookedRecipeHistoryTile(recipe: r, isDark: isDark)),
        ],

        if (entries.isEmpty && cookHistory.isEmpty)
          _EmptyState(isDark: isDark),
      ],
    );
  }

  int _computeStreak(List<NutritionLogEntry> entries) {
    if (entries.isEmpty) return 0;
    final days = <String>{};
    for (final e in entries) {
      final d = e.cookedAt;
      days.add('${d.year}-${d.month}-${d.day}');
    }
    int streak = 0;
    var current = DateTime.now();
    while (true) {
      final key = '${current.year}-${current.month}-${current.day}';
      if (!days.contains(key)) break;
      streak++;
      current = current.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isDark;
  const _SectionHeader(this.text, this.icon, this.isDark);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryPurple),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
        ],
      );
}

// ── Calorie ring ───────────────────────────────────────────────────────────────

class _CalorieRingCard extends StatelessWidget {
  final double consumed, target;
  final double protein, carbs, fat;
  final double proteinTarget, carbsTarget, fatTarget;
  final bool isDark;

  const _CalorieRingCard({
    required this.consumed,
    required this.target,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (consumed / target).clamp(0.0, 1.0);
    final isOver = consumed > target;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOver
            ? const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFEE4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isOver ? AppTheme.errorRed : AppTheme.primaryPurple)
                .withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.today_rounded, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text("Today's Nutrition",
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 20),
          // Ring + number
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _RingPainter(progress: pct, isOver: isOver),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          consumed.round().toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800),
                        ),
                        const Text('kcal',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroProgress(
                        label: 'Protein',
                        value: protein,
                        target: proteinTarget,
                        color: Colors.red.shade300),
                    const SizedBox(height: 10),
                    _MacroProgress(
                        label: 'Carbs',
                        value: carbs,
                        target: carbsTarget,
                        color: Colors.blue.shade300),
                    const SizedBox(height: 10),
                    _MacroProgress(
                        label: 'Fat',
                        value: fat,
                        target: fatTarget,
                        color: Colors.orange.shade300),
                    const SizedBox(height: 10),
                    Text(
                      isOver
                          ? '${(consumed - target).round()} kcal over'
                          : '${(target - consumed).round()} kcal left',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isOver;
  _RingPainter({required this.progress, required this.isOver});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withOpacity(0.25),
    );

    // Progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.isOver != isOver;
}

class _MacroProgress extends StatelessWidget {
  final String label;
  final double value, target;
  final Color color;
  const _MacroProgress(
      {required this.label,
      required this.value,
      required this.target,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11)),
            Text('${value.round()}g',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Weekly bar chart ───────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<DailySummary> days;
  final double target;
  final bool isDark;

  const _WeeklyBarChart(
      {required this.days, required this.target, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final maxCal = days.fold(0.0, (m, d) => math.max(m, d.calories));
    final chartMax = math.max(maxCal, target) * 1.15;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          // Chart
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final pct = chartMax > 0 ? d.calories / chartMax : 0.0;
                final isToday = _isSameDay(d.date, DateTime.now());
                final isOver  = d.calories > target && d.calories > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.calories > 0)
                          Text(
                            '${(d.calories / 1000).toStringAsFixed(1)}k',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isOver
                                    ? AppTheme.accentOrange
                                    : AppTheme.primaryPurple),
                          ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: math.max(4, pct * 110),
                          decoration: BoxDecoration(
                            gradient: isOver
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B6B),
                                      Color(0xFFFFB347)
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter)
                                : isToday
                                    ? AppTheme.primaryGradient
                                    : LinearGradient(colors: [
                                        AppTheme.primaryPurple
                                            .withOpacity(0.4),
                                        AppTheme.primaryPurple
                                            .withOpacity(0.7),
                                      ], begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shortDay(d.date),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? AppTheme.primaryPurple
                                  : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Target line legend
          Row(
            children: [
              Container(
                  width: 24, height: 2, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              Text(
                'Target: ${target.round()} kcal',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _shortDay(DateTime d) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }
}

// ── Quick stats grid ───────────────────────────────────────────────────────────

class _QuickStatsGrid extends StatelessWidget {
  final List<NutritionLogEntry> entries;
  final List<CookedRecipe>      cookHistory;
  final bool isDark;

  const _QuickStatsGrid(
      {required this.entries,
      required this.cookHistory,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final totalMeals   = entries.length;
    final avgCal       = entries.isEmpty
        ? 0.0
        : entries.fold(0.0, (s, e) => s + e.totalCalories) / entries.length;
    final totalCooks   = cookHistory.fold(0, (s, r) => s + r.cookCount);
    final uniqueRecipes = cookHistory.length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
            label: 'Meals Logged',
            value: '$totalMeals',
            icon: Icons.restaurant_rounded,
            color: AppTheme.primaryPurple,
            isDark: isDark),
        _StatCard(
            label: 'Avg. Calories',
            value: avgCal > 0 ? '${avgCal.round()}' : '—',
            icon: Icons.local_fire_department_rounded,
            color: AppTheme.accentOrange,
            isDark: isDark),
        _StatCard(
            label: 'Total Cooks',
            value: '$totalCooks',
            icon: Icons.outdoor_grill_rounded,
            color: AppTheme.successGreen,
            isDark: isDark),
        _StatCard(
            label: 'Unique Recipes',
            value: '$uniqueRecipes',
            icon: Icons.auto_awesome_rounded,
            color: AppTheme.infoBlue,
            isDark: isDark),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Meal log tile ──────────────────────────────────────────────────────────────

class _MealLogTile extends StatelessWidget {
  final NutritionLogEntry entry;
  final bool isDark;
  final bool showDelete;
  final VoidCallback? onDelete;

  const _MealLogTile({
    required this.entry,
    required this.isDark,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Image / avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: entry.recipeImage != null
                ? Image.network(
                    entry.recipeImage!,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.recipeTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniMacro(
                        label: '${entry.totalCalories.round()} cal',
                        color: AppTheme.accentOrange),
                    const SizedBox(width: 8),
                    _MiniMacro(
                        label: '${entry.totalProtein.round()}g P',
                        color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    _MiniMacro(
                        label: '${entry.totalCarbs.round()}g C',
                        color: Colors.blue.shade400),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(entry.cookedAt),
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight),
                ),
              ],
            ),
          ),
          if (showDelete && onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppTheme.errorRed.withOpacity(0.7),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Center(
          child: Text(
            entry.recipeTitle.isNotEmpty ? entry.recipeTitle[0] : '🍽',
            style: const TextStyle(fontSize: 22, color: Colors.white),
          ),
        ),
      );

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)  return '${diff.inHours}h ago';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniMacro({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      );
}

// ── Day header for history ─────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final DailySummary summary;
  final bool isDark;
  const _DayHeader({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(summary.date, DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            isToday ? 'Today' : _fmtDate(summary.date),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryPurple),
          ),
          const Spacer(),
          Text(
            '${summary.calories.round()} kcal · ${summary.mealCount} meal${summary.mealCount == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtDate(DateTime d) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

// ── Streak banner ──────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final int streak;
  final double avgCal;
  final bool isDark;
  const _StreakBanner(
      {required this.streak, required this.avgCal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cooking Streak',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                  Text('$streak day${streak == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Daily Average',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${avgCal.round()} kcal',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top recipe row ─────────────────────────────────────────────────────────────

class _TopRecipeRow extends StatelessWidget {
  final int rank;
  final String title;
  final int count;
  final bool isDark;
  const _TopRecipeRow(
      {required this.rank,
      required this.title,
      required this.count,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppTheme.warningYellow
                  : rank == 2
                      ? Colors.grey.shade400
                      : Colors.brown.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$rank',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count× cooked',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cuisine chart ──────────────────────────────────────────────────────────────

class _CuisineChart extends StatelessWidget {
  final List<MapEntry<String, int>> cuisines;
  final bool isDark;
  const _CuisineChart({required this.cuisines, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = cuisines.fold(0, (s, e) => s + e.value);
    final colors = [
      AppTheme.primaryPurple,
      AppTheme.successGreen,
      AppTheme.accentOrange,
      AppTheme.infoBlue,
      AppTheme.warningYellow,
      AppTheme.errorRed,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.07)),
      ),
      child: Column(
        children: cuisines.asMap().entries.map((entry) {
          final i    = entry.key;
          final kv   = entry.value;
          final pct  = kv.value / total;
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kv.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${(pct * 100).round()}% · ${kv.value} meal${kv.value == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Cooked recipe history tile ─────────────────────────────────────────────────

class _CookedRecipeHistoryTile extends StatelessWidget {
  final CookedRecipe recipe;
  final bool isDark;
  const _CookedRecipeHistoryTile(
      {required this.recipe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: recipe.image != null
                ? Image.network(recipe.image!,
                    width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('Cooked ${recipe.cookCount}×',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('${recipe.readyInMinutes}m · ${recipe.calories.round()} cal',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight)),
                  ],
                ),
              ],
            ),
          ),
          // Favorite star
          GestureDetector(
            onTap: () async {
              await RecipeHistoryService.instance.toggleFavorite(
                  recipe.recipeId,
                  value: !recipe.isFavorite);
            },
            child: Icon(
              recipe.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: recipe.isFavorite
                  ? AppTheme.warningYellow
                  : (isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
            gradient: AppTheme.accentGradient),
        child: Center(
          child: Text(
            recipe.title.isNotEmpty ? recipe.title[0] : '🍽',
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      );
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 52, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('No data yet',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Cook a recipe and finish cooking mode\nto start tracking your nutrition.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }
}
