import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/theme_provider.dart';
import '../../core/constants/theme/app_theme.dart';

class ThemeToggleFAB extends StatefulWidget {
  const ThemeToggleFAB({super.key});

  @override
  State<ThemeToggleFAB> createState() => _ThemeToggleFABState();
}

class _ThemeToggleFABState extends State<ThemeToggleFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _rotateAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Positioned(
          bottom: 92,
          left: 20,
          child: GestureDetector(
            onTap: () {
              _ctrl.forward(from: 0);
              themeProvider.toggleTheme();
            },
            child: AnimatedBuilder(
              animation: _rotateAnim,
              builder: (_, child) => Transform.rotate(
                angle: _rotateAnim.value * 0.5,
                child: child,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF2A2840), Color(0xFF1A1830)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.amber.withOpacity(0.35)
                          : Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.3, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    key: ValueKey(isDark),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}