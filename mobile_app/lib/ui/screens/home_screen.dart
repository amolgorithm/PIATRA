import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../core/constants/theme/app_theme.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../../state/user_provider.dart';
import '../../state/recipe_provider.dart';
import '../../models/user_profile_model.dart';
import '../../services/pantry_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _orbCtrl;      // slow ambient float
  late AnimationController _headerCtrl;   // header fade+slide in
  late AnimationController _gridCtrl;     // staggered card entrance
  late AnimationController _statsCtrl;    // stats count-up

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _gridFade;
  late Animation<double> _orbAnim;
  late Animation<double> _statsProgress;  // 0→1 drives count-up numbers

  // ── Real overview data ────────────────────────────────────────────────────
  int _pantryCount     = 0;
  int _recipesReady    = 0;
  int _calorieTarget   = 2000;
  bool _statsLoading   = true;

  @override
  void initState() {
    super.initState();

    // Ambient orb drift — loops forever
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    // Header enters after 100 ms
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Cards stagger after 300 ms
    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Stats count-up — starts once data is loaded
    _statsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.12), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _gridFade    = CurvedAnimation(parent: _gridCtrl,  curve: Curves.easeOut);
    _orbAnim     = CurvedAnimation(parent: _orbCtrl,   curve: Curves.easeInOut);
    _statsProgress = CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOutCubic);

    // Staggered entrance
    Future.delayed(const Duration(milliseconds: 80),  _startHeader);
    Future.delayed(const Duration(milliseconds: 300), _startGrid);
    Future.delayed(const Duration(milliseconds: 150), _loadRealStats);
  }

  // ── Stats loading ─────────────────────────────────────────────────────────

  Future<void> _loadRealStats() async {
    try {
      // 1. Pantry count — reads the local SQLite DB directly
      final items = await PantryService.instance.getAllItems();
      final pantryCount = items.length;

      // 2. Calorie target — from UserProvider profile (already in memory)
      final profile = context.read<UserProvider>().profile;
      final calorieTarget = profile?.calorieTarget ?? 2000;

      // 3. Recipe count — from RecipeProvider if already fetched,
      //    otherwise kick off a load in background and update when done
      final recipeProvider = context.read<RecipeProvider>();
      int recipesReady = recipeProvider.rankedRecipes
          .where((r) => r.pantryMatchPercent >= 70)
          .length;

      if (mounted) {
        setState(() {
          _pantryCount   = pantryCount;
          _calorieTarget = calorieTarget;
          _recipesReady  = recipesReady;
          _statsLoading  = false;
        });
        _statsCtrl.forward();
      }

      // Kick off recipe fetch in background if not yet done
      if (recipeProvider.loadState == RecipeLoadState.idle) {
        final p = profile ?? UserProfileModel.defaultProfile();
        recipeProvider.loadRecommendations(profile: p).then((_) {
          if (!mounted) return;
          final ready = recipeProvider.rankedRecipes
              .where((r) => r.pantryMatchPercent >= 70)
              .length;
          setState(() => _recipesReady = ready);
          // Re-run count-up for updated number
          _statsCtrl.forward(from: 0.0);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _statsLoading = false);
        _statsCtrl.forward();
      }
    }
  }

  void _startHeader() { if (mounted) _headerCtrl.forward(); }
  void _startGrid()   { if (mounted) _gridCtrl.forward(); }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _headerCtrl.dispose();
    _gridCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Animated ambient background
          _AmbientBackground(orbAnim: _orbAnim, isDark: isDark),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
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
                SliverToBoxAdapter(child: _buildOverview(isDark)),
                // Extra bottom padding so content clears the two FABs
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // FABs — ThemeToggle left, AI right, both at bottom:20
          const ThemeToggleFAB(),
          const AIAssistantFAB(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

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
                  // Pulsing logo chip
                  _PulsingLogo(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppTheme.primaryGradient.createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'PIATRA',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.5,
                              color: Colors.white, // masked by ShaderMask
                            ),
                          ),
                        ),
                        Text(
                          'AI-Powered Kitchen',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.5,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile avatar
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.profile)
                            .then((_) => _loadRealStats()),
                    child: Consumer<UserProvider>(
                      builder: (_, up, __) {
                        final mode = up.profile?.cookingMode;
                        final initial =
                            (up.profile?.displayName.isNotEmpty == true
                                    ? up.profile!.displayName[0]
                                    : '?')
                                .toUpperCase();
                        return _SpringAvatar(
                            label: mode?.emoji ?? initial);
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: anim, curve: Curves.easeOut)),
                            child: child,
                          ),
                        ),
                        child: Text(
                          name != null
                              ? 'Hello, $name 👋'
                              : 'What\'s cooking\ntoday?',
                          key: ValueKey(name),
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: name != null ? 28 : 34,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.8,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimaryLight,
                          ),
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

  // ── Feature grid ──────────────────────────────────────────────────────────

  Widget _buildFeatureGrid(BuildContext context, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                index: 0,
                icon: Icons.kitchen_rounded,
                title: 'My Pantry',
                description: 'Manage ingredients',
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C6EFA), Color(0xFF5B4FD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.pantry)
                    .then((_) => _loadRealStats()),
                parentCtrl: _gridCtrl,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _FeatureCard(
                index: 1,
                icon: Icons.camera_alt_rounded,
                title: 'Scan Items',
                description: 'Add with camera',
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF009E7F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.scan)
                    .then((_) => _loadRealStats()),
                parentCtrl: _gridCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                index: 2,
                icon: Icons.restaurant_rounded,
                title: 'Recipes',
                description: 'Find what to cook',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEE4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.recipes)
                    .then((_) => _loadRealStats()),
                parentCtrl: _gridCtrl,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _FeatureCard(
                index: 3,
                icon: Icons.auto_graph_rounded,
                title: 'Analytics',
                description: 'Track nutrition',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
                parentCtrl: _gridCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FeatureCard(
          index: 4,
          icon: Icons.feedback_rounded,
          title: 'Send Feedback',
          description: 'Help us improve PIATRA',
          gradient: const LinearGradient(
            colors: [Color(0xFFB24BF3), Color(0xFF8B3FCF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => Navigator.pushNamed(context, AppRoutes.feedback),
          parentCtrl: _gridCtrl,
          isWide: true,
        ),
      ],
    );
  }

  // ── Overview (real stats) ─────────────────────────────────────────────────

  Widget _buildOverview(bool isDark) {
    return FadeTransition(
      opacity: _gridFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Overview',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                  ),
                ),
                if (_statsLoading) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryPurple.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _statsProgress,
              builder: (_, __) {
                final t = _statsProgress.value;
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.inventory_2_rounded,
                        value: (_pantryCount * t).round().toString(),
                        label: 'In Pantry',
                        color: AppTheme.primaryPurple,
                        isDark: isDark,
                        isEmpty: _pantryCount == 0 && !_statsLoading,
                        emptyLabel: 'Add items',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.restaurant_menu_rounded,
                        value: (_recipesReady * t).round().toString(),
                        label: 'Recipes Ready',
                        color: AppTheme.secondaryTeal,
                        isDark: isDark,
                        isEmpty: _recipesReady == 0 && !_statsLoading,
                        emptyLabel: 'Add pantry',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department_rounded,
                        value: _formatCalories((_calorieTarget * t).round()),
                        label: 'kcal Target',
                        color: AppTheme.accentOrange,
                        isDark: isDark,
                        isEmpty: false,
                        emptyLabel: '',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCalories(int val) {
    if (val >= 1000) {
      // e.g. 2000 → "2k", 1840 → "1.8k"
      final k = val / 1000;
      return k == k.roundToDouble()
          ? '${k.round()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return val.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient background
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  final Animation<double> orbAnim;
  final bool isDark;
  const _AmbientBackground({required this.orbAnim, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbAnim,
      builder: (_, __) {
        final t = orbAnim.value;
        return Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF0D0C14), Color(0xFF13121C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFF4F3FF), Color(0xFFFFFFFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60 + t * 22,
                right: -80 + t * 16,
                child: _Orb(
                  size: 290,
                  color: isDark
                      ? AppTheme.primaryPurple.withOpacity(0.18)
                      : AppTheme.primaryPurple.withOpacity(0.09),
                ),
              ),
              Positioned(
                top: 260 + t * 32,
                left: -100 + t * 12,
                child: _Orb(
                  size: 230,
                  color: isDark
                      ? AppTheme.secondaryTeal.withOpacity(0.10)
                      : AppTheme.secondaryTeal.withOpacity(0.07),
                ),
              ),
              Positioned(
                bottom: 100 - t * 22,
                right: -60 + t * 10,
                child: _Orb(
                  size: 190,
                  color: isDark
                      ? AppTheme.accentOrange.withOpacity(0.07)
                      : AppTheme.accentOrange.withOpacity(0.05),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
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

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing logo
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingLogo extends StatefulWidget {
  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        padding: EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple
                  .withOpacity(0.28 + _glow.value * 0.30),
              blurRadius: 14 + _glow.value * 10,
              spreadRadius: _glow.value * 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
      child: const Icon(
        Icons.restaurant_menu_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spring-press avatar
// ─────────────────────────────────────────────────────────────────────────────

class _SpringAvatar extends StatefulWidget {
  final String label;
  const _SpringAvatar({required this.label});

  @override
  State<_SpringAvatar> createState() => _SpringAvatarState();
}

class _SpringAvatarState extends State<_SpringAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.animateTo(0.88,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 100)),
      onTapUp: (_) => _ctrl.animateTo(1.0,
          curve: Curves.elasticOut,
          duration: const Duration(milliseconds: 400)),
      onTapCancel: () => _ctrl.animateTo(1.0,
          curve: Curves.elasticOut,
          duration: const Duration(milliseconds: 400)),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: _ctrl.value, child: child),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(widget.label, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode badge
// ─────────────────────────────────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final CookingMode mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final colors = mode.gradientColors.map((c) => Color(c)).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.42),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mode.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            '${mode.label} Mode',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature card with staggered entrance + spring press
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureCard extends StatefulWidget {
  final int index;
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final VoidCallback onTap;
  final AnimationController parentCtrl;
  final bool isWide;

  const _FeatureCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
    required this.parentCtrl,
    this.isWide = false,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    // Spring press controller
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale = _pressCtrl;

    // Staggered entrance driven by parent
    final stagger = widget.index * 0.08;
    final start  = stagger.clamp(0.0, 0.75);
    final end    = (stagger + 0.38).clamp(0.0, 1.0);

    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.parentCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.parentCtrl,
        curve: Interval(start, end, curve: Curves.easeOut),
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
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.reverse(),
          onTapUp: (_) { _pressCtrl.forward(); widget.onTap(); },
          onTapCancel: () => _pressCtrl.forward(),
          child: AnimatedBuilder(
            animation: _pressScale,
            builder: (_, child) =>
                Transform.scale(scale: _pressScale.value, child: child),
            child: _CardBody(
              icon: widget.icon,
              title: widget.title,
              description: widget.description,
              gradient: widget.gradient,
              isWide: widget.isWide,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final bool isWide;

  const _CardBody({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        (gradient as LinearGradient).colors.first;

    return Container(
      height: isWide ? 80 : 148,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -20, right: -20,
              child: _circle(80, 0.08),
            ),
            Positioned(
              top: -40, right: -10,
              child: _circle(120, 0.05),
            ),
            if (isWide)
              _wideContent()
            else
              _tallContent(),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _wideContent() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            _iconChip(),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_titleText(), const SizedBox(height: 2), _descText()],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.65), size: 20),
          ],
        ),
      );

  Widget _tallContent() => Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _iconChip(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_titleText(), const SizedBox(height: 2), _descText()],
            ),
          ],
        ),
      );

  Widget _iconChip() => Container(
        padding: EdgeInsets.all(isWide ? 10 : 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: isWide ? 22 : 26),
      );

  Widget _titleText() => Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );

  Widget _descText() => Text(
        description,
        style: TextStyle(
          color: Colors.white.withOpacity(0.76),
          fontSize: 12,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Real stat card with count-up (driven by parent AnimatedBuilder)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;
  final bool isEmpty;
  final String emptyLabel;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
    required this.isEmpty,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0x18FFFFFF)
              : const Color(0x10000000),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withOpacity(0.09),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.25),
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
                fontSize: value.length > 4 ? 16 : 20,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppTheme.textPrimaryDark
                    : AppTheme.textPrimaryLight,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isEmpty ? emptyLabel : label,
            style: TextStyle(
              fontSize: 11,
              color: isEmpty
                  ? color.withOpacity(0.7)
                  : (isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }
}