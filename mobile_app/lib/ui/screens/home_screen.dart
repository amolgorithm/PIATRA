import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../core/constants/theme/app_theme.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../widgets/soda_background_painter.dart';
import '../../state/user_provider.dart';
import '../../state/recipe_provider.dart';
import '../../models/user_profile_model.dart';
import '../../services/pantry_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _gridCtrl;
  late AnimationController _orbCtrl;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _gridFade;
  late Animation<double> _orbAnim;

  int _pantryCount = 0;
  int _recipesCount = 0;
  bool _overviewLoaded = false;

  @override
  void initState() {
    super.initState();

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _gridFade = CurvedAnimation(parent: _gridCtrl, curve: Curves.easeOut);
    _orbAnim = CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _headerCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _gridCtrl.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOverview());
  }

  Future<void> _loadOverview() async {
    try {
      final items = await PantryService.instance.getAllItems();
      final recipes = context.read<RecipeProvider>().rankedRecipes;
      if (mounted) {
        setState(() {
          _pantryCount = items.length;
          _recipesCount = recipes.length;
          _overviewLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _overviewLoaded = true);
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _gridCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          _AmbientBackground(orbAnim: _orbAnim, isDark: isDark),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _gridFade,
                      child: _buildFeatureGrid(context, isDark),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
          const ThemeToggleFAB(),
          const AIAssistantFAB(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PIATRA',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'AI-Powered Kitchen',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.5,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                    child: Consumer<UserProvider>(
                      builder: (context, up, _) {
                        final mode = up.profile?.cookingMode;
                        final initial = (up.profile?.displayName.isNotEmpty == true
                                ? up.profile!.displayName[0]
                                : '?')
                            .toUpperCase();
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              mode?.emoji ?? initial,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Consumer<UserProvider>(
                builder: (_, up, __) {
                  final name = up.profile?.displayName;
                  final mode = up.profile?.cookingMode;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name != null ? 'Hello, $name 👋' : "What's cooking\ntoday?",
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: name != null ? 28 : 34,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.8,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      if (mode != null) ...[
                        const SizedBox(height: 10),
                        _ModeBadge(mode: mode),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context, bool isDark) {
    return Column(
      children: [
        _GridRow(children: [
          _GlassFeatureCard(
            delay: 0,
            icon: Icons.kitchen_rounded,
            title: 'My Pantry',
            description: 'Manage ingredients',
            accentColor: const Color(0xFF6C63FF),
            onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
            parentAnim: _gridCtrl,
          ),
          _GlassFeatureCard(
            delay: 80,
            icon: Icons.camera_alt_rounded,
            title: 'Scan Items',
            description: 'Add with camera',
            accentColor: const Color(0xFF00D4AA),
            onTap: () => Navigator.pushNamed(context, AppRoutes.scan),
            parentAnim: _gridCtrl,
          ),
        ]),
        const SizedBox(height: 14),
        _GridRow(children: [
          _GlassFeatureCard(
            delay: 160,
            icon: Icons.restaurant_rounded,
            title: 'Recipes',
            description: 'Find what to cook',
            accentColor: const Color(0xFFFF6B6B),
            onTap: () => Navigator.pushNamed(context, AppRoutes.recipes),
            parentAnim: _gridCtrl,
          ),
          _GlassFeatureCard(
            delay: 240,
            icon: Icons.auto_graph_rounded,
            title: 'Analytics',
            description: 'Track nutrition',
            accentColor: const Color(0xFFFFB800),
            onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
            parentAnim: _gridCtrl,
          ),
        ]),
        const SizedBox(height: 14),
        _GridRow(children: [
          _GlassFeatureCard(
            delay: 320,
            icon: Icons.feedback_rounded,
            title: 'Feedback',
            description: 'Help us improve',
            accentColor: const Color(0xFFB24BF3),
            onTap: () => Navigator.pushNamed(context, AppRoutes.feedback),
            parentAnim: _gridCtrl,
          ),
          _LiveOverviewCard(
            delay: 400,
            parentAnim: _gridCtrl,
            pantryCount: _pantryCount,
            recipesCount: _recipesCount,
            overviewLoaded: _overviewLoaded,
          ),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Combined Background
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  final Animation<double> orbAnim;
  final bool isDark;
  const _AmbientBackground({required this.orbAnim, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: SodaBackground(isDark: isDark)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.30),
                        Colors.black.withOpacity(0.55),
                      ]
                    : [
                        Colors.black.withOpacity(0.28),
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.35),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: orbAnim,
          builder: (_, __) {
            final t = orbAnim.value;
            return Stack(
              children: [
                Positioned(
                  top: -60 + t * 20,
                  right: -80 + t * 15,
                  child: _Orb(
                    size: 280,
                    color: isDark
                        ? AppTheme.primaryPurple.withOpacity(0.15)
                        : AppTheme.primaryPurple.withOpacity(0.08),
                  ),
                ),
                Positioned(
                  top: 260 + t * 30,
                  left: -100 + t * 10,
                  child: _Orb(
                    size: 220,
                    color: isDark
                        ? AppTheme.secondaryTeal.withOpacity(0.08)
                        : AppTheme.secondaryTeal.withOpacity(0.06),
                  ),
                ),
                Positioned(
                  bottom: 100 - t * 20,
                  right: -60 + t * 8,
                  child: _Orb(
                    size: 180,
                    color: isDark
                        ? AppTheme.accentOrange.withOpacity(0.06)
                        : AppTheme.accentOrange.withOpacity(0.04),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          radius: 0.75,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid row helper
// ─────────────────────────────────────────────────────────────────────────────

class _GridRow extends StatelessWidget {
  final List<Widget> children;
  const _GridRow({required this.children});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 14),
            Expanded(child: children[1]),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Frosted-glass feature card
// card bg:    0.10 → 0.22  (much more visible body)
// card border: 0.22 → 0.45  (clear, defined edge)
// icon pill:  0.25 → 0.35, border 0.4 → 0.55
// description text: 0.65 → 0.75
// ─────────────────────────────────────────────────────────────────────────────

class _GlassFeatureCard extends StatefulWidget {
  final int delay;
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;
  final AnimationController parentAnim;

  const _GlassFeatureCard({
    required this.delay,
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
    required this.parentAnim,
  });

  @override
  State<_GlassFeatureCard> createState() => _GlassFeatureCardState();
}

class _GlassFeatureCardState extends State<_GlassFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressAnim = _pressCtrl;

    final begin = (widget.delay / 1000.0).clamp(0.0, 0.8);
    final end = (begin + 0.4).clamp(0.0, 1.0);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.parentAnim,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: widget.parentAnim,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: AnimatedBuilder(
          animation: _pressAnim,
          builder: (_, child) =>
              Transform.scale(scale: _pressAnim.value, child: child),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _pressCtrl.reverse(),
              onTapUp: (_) => _pressCtrl.forward(),
              onTapCancel: () => _pressCtrl.forward(),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 148,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                widget.accentColor.withOpacity(0.40),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: widget.accentColor.withOpacity(0.55),
                                  width: 1,
                                ),
                              ),
                              child:
                                  Icon(widget.icon, color: Colors.white, size: 24),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.description,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Overview Card — matched opacity to feature cards
// ─────────────────────────────────────────────────────────────────────────────

class _LiveOverviewCard extends StatefulWidget {
  final int delay;
  final AnimationController parentAnim;
  final int pantryCount;
  final int recipesCount;
  final bool overviewLoaded;

  const _LiveOverviewCard({
    required this.delay,
    required this.parentAnim,
    required this.pantryCount,
    required this.recipesCount,
    required this.overviewLoaded,
  });

  @override
  State<_LiveOverviewCard> createState() => _LiveOverviewCardState();
}

class _LiveOverviewCardState extends State<_LiveOverviewCard> {
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final begin = (widget.delay / 1000.0).clamp(0.0, 0.8);
    final end = (begin + 0.4).clamp(0.0, 1.0);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.parentAnim,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: widget.parentAnim,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Consumer<UserProvider>(
          builder: (_, up, __) {
            final calTarget = up.profile?.calorieTarget ?? 2000;
            final mode = up.profile?.cookingMode;

            return Container(
              height: 148,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const Spacer(),
                        if (mode != null)
                          Text(
                            mode.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                    _LiveStatRow(
                      icon: Icons.inventory_2_rounded,
                      value: widget.overviewLoaded ? '${widget.pantryCount}' : '—',
                      label: 'Pantry items',
                      color: AppTheme.primaryPurple,
                    ),
                    _LiveStatRow(
                      icon: Icons.restaurant_menu_rounded,
                      value: widget.overviewLoaded ? '${widget.recipesCount}' : '—',
                      label: 'Recipes found',
                      color: AppTheme.secondaryTeal,
                    ),
                    _LiveStatRow(
                      icon: Icons.local_fire_department_rounded,
                      value: _formatCalories(calTarget),
                      label: 'kcal target',
                      color: AppTheme.accentOrange,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatCalories(int cal) {
    if (cal >= 1000) return '${(cal / 1000).toStringAsFixed(1)}k';
    return '$cal';
  }
}

class _LiveStatRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _LiveStatRow({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withOpacity(0.20),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            value,
            key: ValueKey(value),
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.60),
          ),
        ),
      ],
    );
  }
}

// ── Mode badge ────────────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final CookingMode mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mode.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            '${mode.label} Mode',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}