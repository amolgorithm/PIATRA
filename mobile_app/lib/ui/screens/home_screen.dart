import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../core/constants/theme/app_theme.dart';
import '../widgets/ai_assistant_fab.dart';
import '../widgets/theme_toggle_fab.dart';
import '../../state/user_provider.dart';
import '../../models/user_profile_model.dart';
import 'feedback_form_screen.dart';

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
          // ── Ambient background ───────────────────────────────────────────
          _AmbientBackground(orbAnim: _orbAnim, isDark: isDark),

          // ── Content ──────────────────────────────────────────────────────
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
                SliverToBoxAdapter(child: _buildQuickStats(isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          const ThemeToggleFAB(),
          const AIAssistantFAB(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

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
                  // Logo badge
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 241, 151, 42)
                              .withOpacity(0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PIATRA',
                          style: TextStyle(
                            fontFamily: 'Sora',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimaryLight,
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
                        Navigator.pushNamed(context, AppRoutes.profile),
                    child: Consumer<UserProvider>(
                      builder: (context, up, _) {
                        final mode = up.profile?.cookingMode;
                        final initial =
                            (up.profile?.displayName.isNotEmpty == true
                                    ? up.profile!.displayName[0]
                                    : '?')
                                .toUpperCase();
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 241, 151, 42)
                                    .withOpacity(0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
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

              // Greeting
              Consumer<UserProvider>(
                builder: (_, up, __) {
                  final name = up.profile?.displayName;
                  final mode = up.profile?.cookingMode;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name != null
                            ? 'Hello, $name 👋'
                            : 'What\'s cooking\ntoday?',
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

  // ── Feature grid — 2+2+wide(feedback) layout ──────────────────────────────

  Widget _buildFeatureGrid(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Row 1: Pantry + Scan
        Row(
          children: [
            Expanded(
              child: _AnimatedFeatureCard(
                delay: 0,
                icon: Icons.kitchen_rounded,
                title: 'My Pantry',
                description: 'Manage ingredients',
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5B54E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
                parentAnim: _gridCtrl,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _AnimatedFeatureCard(
                delay: 80,
                icon: Icons.camera_alt_rounded,
                title: 'Scan Items',
                description: 'Add with camera',
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.scan),
                parentAnim: _gridCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row 2: Recipes + Analytics
        Row(
          children: [
            Expanded(
              child: _AnimatedFeatureCard(
                delay: 160,
                icon: Icons.restaurant_rounded,
                title: 'Recipes',
                description: 'Find what to cook',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.recipes),
                parentAnim: _gridCtrl,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _AnimatedFeatureCard(
                delay: 240,
                icon: Icons.auto_graph_rounded,
                title: 'Analytics',
                description: 'Track nutrition',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.pantry),
                parentAnim: _gridCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Row 3: Feedback — full width, shorter
        _AnimatedFeatureCard(
          delay: 320,
          icon: Icons.feedback_rounded,
          title: 'Send Feedback',
          description: 'Help us improve PIATRA',
          gradient: const LinearGradient(
            colors: [Color(0xFFB24BF3), Color(0xFF9D3FDD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackFormScreen()),
            );
          },
          parentAnim: _gridCtrl,
          isWide: true,
        ),
      ],
    );
  }

  // ── Quick stats ────────────────────────────────────────────────────────────

  Widget _buildQuickStats(bool isDark) {
    return FadeTransition(
      opacity: _gridFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.inventory_2_rounded,
                    value: '23',
                    label: 'In Pantry',
                    color: AppTheme.primaryPurple,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.restaurant_menu_rounded,
                    value: '12',
                    label: 'Recipes Ready',
                    color: AppTheme.secondaryTeal,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    value: '1,840',
                    label: 'kcal Today',
                    color: AppTheme.accentOrange,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ambient background with floating orbs ─────────────────────────────────────

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
              // Purple orb top-right
              Positioned(
                top: -60 + t * 20,
                right: -80 + t * 15,
                child: _Orb(
                  size: 280,
                  color: isDark
                      ? AppTheme.primaryPurple.withOpacity(0.18)
                      : AppTheme.primaryPurple.withOpacity(0.09),
                ),
              ),
              // Teal orb middle-left
              Positioned(
                top: 260 + t * 30,
                left: -100 + t * 10,
                child: _Orb(
                  size: 220,
                  color: isDark
                      ? AppTheme.secondaryTeal.withOpacity(0.10)
                      : AppTheme.secondaryTeal.withOpacity(0.07),
                ),
              ),
              // Orange orb bottom-right
              Positioned(
                bottom: 100 - t * 20,
                right: -60 + t * 8,
                child: _Orb(
                  size: 180,
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

// ── Cooking mode badge ────────────────────────────────────────────────────────

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
            color: colors.first.withOpacity(0.4),
            blurRadius: 12,
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

// ── Animated feature card ─────────────────────────────────────────────────────

class _AnimatedFeatureCard extends StatefulWidget {
  final int delay;
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final VoidCallback onTap;
  final AnimationController parentAnim;
  final bool isWide;

  const _AnimatedFeatureCard({
    required this.delay,
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
    required this.parentAnim,
    this.isWide = false,
  });

  @override
  State<_AnimatedFeatureCard> createState() => _AnimatedFeatureCardState();
}

class _AnimatedFeatureCardState extends State<_AnimatedFeatureCard>
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

    // Staggered entry: slide up + fade in
    final delayFrac = widget.delay / 1000.0;
    final begin = delayFrac.clamp(0.0, 0.8);
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
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.reverse(),
          onTapUp: (_) => _pressCtrl.forward(),
          onTapCancel: () => _pressCtrl.forward(),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pressAnim,
            builder: (_, child) => Transform.scale(
              scale: _pressAnim.value,
              child: child,
            ),
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final isWide = widget.isWide;
    return Container(
      height: isWide ? 80 : 148,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (widget.gradient as LinearGradient)
                .colors
                .first
                .withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Subtle shimmer in top-right corner
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -10,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Content
            if (isWide)
              // Wide layout: horizontal
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            )),
                        Text(widget.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            )),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white.withOpacity(0.6), size: 20),
                  ],
                ),
              )
            else
              // Tall layout: vertical
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 26),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            )),
                        const SizedBox(height: 2),
                        Text(widget.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            )),
                      ],
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

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color:
                  isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
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
    );
  }
}
