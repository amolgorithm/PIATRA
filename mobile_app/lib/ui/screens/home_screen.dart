// lib/ui/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../core/constants/theme/app_theme.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../widgets/overview_fab.dart';
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
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeroHeader(isDark)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _gridFade,
                      child: _buildFeatureGrid(context, isDark),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          const ThemeToggleFAB(),
          OverviewFAB(
            pantryCount: _pantryCount,
            recipesCount: _recipesCount,
            overviewLoaded: _overviewLoaded,
          ),
          const AIAssistantFAB(),
        ],
      ),
    );
  }

  // Flat gradient panel instead of the old full-screen animated background.
  // Just the header sits on color, rest of the page is plain and light,
  // reads a lot closer to a normal iOS app than a photo-background hero.
  Widget _buildHeroHeader(bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Stack(
          children: [
            // orbs go behind the header text. Positioned.fill needs a
            // sized stack to fill, _buildHeader below is the one
            // non-positioned child that actually gives the stack a size,
            // a stack made of nothing but Positioned children has no way
            // to size itself and blows up with an unbounded height here
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _orbAnim,
                builder: (_, __) {
                  final t = _orbAnim.value;
                  return Stack(
                    children: [
                      Positioned(
                        top: -40 + t * 14,
                        right: -60 + t * 10,
                        child: _Orb(size: 200, color: Colors.white.withOpacity(0.10)),
                      ),
                      Positioned(
                        bottom: -50 + t * 10,
                        left: -40 + t * 8,
                        child: _Orb(size: 160, color: Colors.white.withOpacity(0.08)),
                      ),
                    ],
                  );
                },
              ),
            ),
            _buildHeader(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                        Text(
                          'PIATRA',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'AI-Powered Smart Kitchen',
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
                        name != null ? 'Hello, $name' : "What's cooking\ntoday?",
                        style: GoogleFonts.inter(
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
    final cards = [
      _FeatureCard(
        delay: 0,
        icon: Icons.kitchen_rounded,
        title: 'My Pantry',
        description: 'Manage ingredients',
        accentColor: AppTheme.categoryIndigo,
        onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
        parentAnim: _gridCtrl,
      ),
      _FeatureCard(
        delay: 80,
        icon: Icons.camera_alt_rounded,
        title: 'Scan Items',
        description: 'Add with camera',
        accentColor: AppTheme.categoryEmerald,
        onTap: () => Navigator.pushNamed(context, AppRoutes.scan),
        parentAnim: _gridCtrl,
      ),
      _FeatureCard(
        delay: 160,
        icon: Icons.restaurant_menu_rounded,
        title: 'Recipes',
        description: 'Personalised picks',
        accentColor: AppTheme.categoryRose,
        onTap: () => Navigator.pushNamed(context, AppRoutes.recipes),
        parentAnim: _gridCtrl,
      ),
      _FeatureCard(
        delay: 240,
        icon: Icons.bar_chart_rounded,
        title: 'Analytics',
        description: 'Nutrition history',
        accentColor: AppTheme.categoryAmber,
        onTap: () => Navigator.pushNamed(context, AppRoutes.analytics),
        parentAnim: _gridCtrl,
      ),
      _FeatureCard(
        delay: 320,
        icon: Icons.calendar_month_rounded,
        title: 'Meal Planner',
        description: 'Plan your week',
        accentColor: AppTheme.categorySky,
        onTap: () => Navigator.pushNamed(context, AppRoutes.mealPlan),
        parentAnim: _gridCtrl,
      ),
      _FeatureCard(
        delay: 400,
        icon: Icons.rate_review_rounded,
        title: 'Feedback',
        description: 'Help us improve',
        accentColor: AppTheme.categoryViolet,
        onTap: () => Navigator.pushNamed(context, AppRoutes.feedback),
        parentAnim: _gridCtrl,
      ),
    ];

    return Column(
      children: [
        _CardRow(left: cards[0], right: cards[1]),
        const SizedBox(height: 14),
        _CardRow(left: cards[2], right: cards[3]),
        const SizedBox(height: 14),
        _CardRow(left: cards[4], right: cards[5]),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _CardRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
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

class _FeatureCard extends StatefulWidget {
  final int delay;
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;
  final AnimationController parentAnim;

  const _FeatureCard({
    required this.delay,
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
    required this.parentAnim,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.forward(),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: AnimatedBuilder(
            animation: _pressAnim,
            builder: (_, child) =>
                Transform.scale(scale: _pressAnim.value, child: child),
            // flat card, one accent color used only for the small icon tile,
            // no gradient blob, no saturated fill, no shadow. plain surface
            // plus a thin hairline border, same language as the rest of
            // the app now instead of six clashing accent colors
            child: Container(
              height: 132,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.description,
                        style: GoogleFonts.inter(
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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