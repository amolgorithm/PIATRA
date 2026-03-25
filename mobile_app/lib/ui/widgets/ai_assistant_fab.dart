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
  late AnimationController _fabCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _expandAnim;
  late Animation<double> _fabScaleAnim;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();

    _expandCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350),
    );
    _fabCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200),
      lowerBound: 0.9, upperBound: 1.0, value: 1.0,
    );
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
    _fabScaleAnim = _fabCtrl;
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.12), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _fabCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandCtrl.forward();
        _pulseCtrl.stop();
      } else {
        _expandCtrl.reverse();
        _pulseCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop
        if (_isExpanded)
          GestureDetector(
            onTap: _toggle,
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),

        // Floating panel
        Positioned(
          bottom: 82,
          right: 16,
          child: AnimatedBuilder(
            animation: _expandAnim,
            builder: (_, child) => Transform.scale(
              scale: _expandAnim.value,
              alignment: Alignment.bottomRight,
              child: Opacity(
                opacity: _expandAnim.value,
                child: SlideTransition(position: _panelSlide, child: child),
              ),
            ),
            child: _buildPanel(isDark),
          ),
        ),

        // FAB
        Positioned(
          bottom: 20,
          right: 20,
          child: _buildFAB(isDark),
        ),
      ],
    );
  }

  Widget _buildFAB(bool isDark) {
    return GestureDetector(
      onTapDown: (_) => _fabCtrl.reverse(),
      onTapUp: (_) { _fabCtrl.forward(); _toggle(); },
      onTapCancel: () => _fabCtrl.forward(),
      child: AnimatedBuilder(
        animation: _fabScaleAnim,
        builder: (_, child) => Transform.scale(scale: _fabScaleAnim.value, child: child),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring (only when closed)
            if (!_isExpanded)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  width: 72 + _pulseAnim.value * 10,
                  height: 72 + _pulseAnim.value * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryPurple
                        .withOpacity(0.15 * (1 - _pulseAnim.value)),
                  ),
                ),
              ),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween<double>(begin: 0.25, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  _isExpanded ? Icons.close_rounded : Icons.auto_awesome_rounded,
                  key: ValueKey(_isExpanded),
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(bool isDark) {
    final width = MediaQuery.of(context).size.width - 32;

    return Container(
      width: width,
      height: 400,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            // Panel header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
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
                        Text('PIATRA',
                            style: TextStyle(
                              color: Colors.white, fontSize: 16,
                              fontWeight: FontWeight.w700, letterSpacing: 0.5,
                            )),
                        Text('Your AI cooking companion',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AssistantBubble(
                    text: 'Hi! Ask me anything about cooking, nutrition, or what you can make with your pantry.',
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Input row
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkElevated : const Color(0xFFF7F6FF),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0x15FFFFFF) : const Color(0x10000000),
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
                            color: AppTheme.primaryPurple.withOpacity(0.4),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  const _AssistantBubble({required this.text, required this.isDark});

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
          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
        ),
      ),
    );
  }
}