import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';

class AIAssistantFAB extends StatefulWidget {
  const AIAssistantFAB({super.key});

  @override
  State<AIAssistantFAB> createState() => _AIAssistantFABState();
}

class _AIAssistantFABState extends State<AIAssistantFAB>
    with TickerProviderStateMixin {
  bool _isExpanded = false;

  late AnimationController _expandCtrl;
  late AnimationController _fabPressCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _closeSpinCtrl;

  late Animation<double> _expandScale;
  late Animation<double> _expandFade;
  late Animation<Offset>  _expandSlide;
  late Animation<double> _fabPress;
  late Animation<double> _pulse1;
  late Animation<double> _pulse2;
  late Animation<double> _shimmer;
  late Animation<double> _closeSpin;

  @override
  void initState() {
    super.initState();

    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _fabPressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    // Two staggered pulse rings
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    // Header shimmer sweep
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    // Close icon spin
    _closeSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _expandScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic),
    );
    _expandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOut),
    );
    _expandSlide = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic));

    _fabPress = _fabPressCtrl;

    _pulse1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulse2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );

    _closeSpin = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _closeSpinCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _fabPressCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _closeSpinCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandCtrl.forward();
      _closeSpinCtrl.forward(from: 0);
      _pulseCtrl.stop();
    } else {
      _expandCtrl.reverse();
      _closeSpinCtrl.reverse();
      _pulseCtrl.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Respect the system nav bar so FABs are never hidden behind it.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final fabBottom = bottomInset + 16.0;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Dim backdrop when panel open
        if (_isExpanded)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Container(color: Colors.black.withOpacity(0.40)),
          ),

        // Floating panel — sits above the FAB with a fixed gap
        Positioned(
          bottom: fabBottom + 72, // FAB height (62) + 10px gap
          right: 16,
          child: FadeTransition(
            opacity: _expandFade,
            child: SlideTransition(
              position: _expandSlide,
              child: ScaleTransition(
                scale: _expandScale,
                alignment: Alignment.bottomRight,
                child: _buildPanel(isDark),
              ),
            ),
          ),
        ),

        // FAB
        Positioned(
          bottom: fabBottom,
          right: 20,
          child: _buildFAB(isDark),
        ),
      ],
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB(bool isDark) {
    return GestureDetector(
      onTapDown: (_) => _fabPressCtrl.reverse(),
      onTapUp: (_) { _fabPressCtrl.forward(); _toggle(); },
      onTapCancel: () => _fabPressCtrl.forward(),
      child: AnimatedBuilder(
        animation: _fabPress,
        builder: (_, child) =>
            Transform.scale(scale: _fabPress.value, child: child),
        child: SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring 1
              if (!_isExpanded)
                AnimatedBuilder(
                  animation: _pulse1,
                  builder: (_, __) {
                    final v = _pulse1.value;
                    return Container(
                      width: 62 + v * 28,
                      height: 62 + v * 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryPurple
                            .withOpacity((1 - v) * 0.18),
                      ),
                    );
                  },
                ),
              // Outer pulse ring 2 (delayed)
              if (!_isExpanded)
                AnimatedBuilder(
                  animation: _pulse2,
                  builder: (_, __) {
                    final v = _pulse2.value;
                    return Container(
                      width: 62 + v * 22,
                      height: 62 + v * 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryPurple
                            .withOpacity((1 - v) * 0.12),
                      ),
                    );
                  },
                ),
              // Core button
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: _isExpanded
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFEE4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isExpanded
                              ? AppTheme.errorRed
                              : AppTheme.primaryPurple)
                          .withOpacity(0.55),
                      blurRadius: 22,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _closeSpin,
                  builder: (_, __) => Transform.rotate(
                    angle: _closeSpin.value * math.pi * 0.5,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: Icon(
                        _isExpanded
                            ? Icons.close_rounded
                            : Icons.auto_awesome_rounded,
                        key: ValueKey(_isExpanded),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Panel ─────────────────────────────────────────────────────────────────

  Widget _buildPanel(bool isDark) {
    final width = MediaQuery.of(context).size.width - 32;

    return Container(
      width: width,
      height: 400,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? const Color(0x22FFFFFF)
              : const Color(0x10000000),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple
                .withOpacity(isDark ? 0.30 : 0.12),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessages(isDark)),
            _buildInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Stack(
            children: [
              // Shimmer sweep
              Positioned.fill(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  child: FractionalTranslation(
                    translation: Offset(_shimmer.value, 0),
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.09),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PIATRA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Your AI cooking companion',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Bubble(
          text:
              'Hi! Ask me anything about cooking, nutrition, or what you can make with your pantry.',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF7F6FF),
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0x15FFFFFF)
                : const Color(0x0E000000),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0x18FFFFFF)
                      : const Color(0x10000000),
                ),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ask anything…',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) {
                  _toggle();
                  Navigator.pushNamed(context, '/assistant');
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              _toggle();
              Navigator.pushNamed(context, '/assistant');
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Bubble({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.cardDarkElevated
            : const Color(0xFFF4F3FF),
        borderRadius: BorderRadius.circular(16).copyWith(
          topLeft: const Radius.circular(4),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.55,
          color: isDark
              ? AppTheme.textPrimaryDark
              : AppTheme.textPrimaryLight,
        ),
      ),
    );
  }
}