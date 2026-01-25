import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/theme_provider.dart';

class ThemeToggleFAB extends StatelessWidget {
  const ThemeToggleFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Positioned(
          bottom: 16,
          left: 16,
          child: GestureDetector(
            onTap: () {
              themeProvider.toggleTheme();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFFFFB800), const Color(0xFFFFA000)]
                      : [const Color(0xFF1A1A2E), const Color(0xFF0F0F1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.amber : Colors.black).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}