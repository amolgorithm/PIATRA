// lib/ui/widgets/overview_fab.dart
//
// Overview FAB — sits in the centre of the bottom FAB row.
// Tapping it reveals a compact popup with pantry count, recipe count,
// calorie target, cooking mode, and favourite cuisines.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../state/user_provider.dart';
import '../../models/user_profile_model.dart';

class OverviewFAB extends StatefulWidget {
  final int pantryCount;
  final int recipesCount;
  final bool overviewLoaded;

  const OverviewFAB({
    super.key,
    required this.pantryCount,
    required this.recipesCount,
    required this.overviewLoaded,
  });

  @override
  State<OverviewFAB> createState() => _OverviewFABState();
}

class _OverviewFABState extends State<OverviewFAB>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  void _close() {
    if (_open) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final fabBottom   = bottomInset + 16.0;
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    // IMPORTANT: Every interactive child must be Positioned so the Stack
    // itself collapses to zero size and never blocks touches on the grid
    // cards beneath it in the parent Stack.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Full-screen tap-away backdrop — only present when open
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.shrink(),
            ),
          ),

        // Popup card — conditionally shown, left/right constrained
        if (_open)
          Positioned(
            bottom: fabBottom + 62 + 10,
            left: 24,
            right: 24,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.bottomCenter,
                  child: _OverviewPopup(
                    pantryCount:    widget.pantryCount,
                    recipesCount:   widget.recipesCount,
                    overviewLoaded: widget.overviewLoaded,
                    isDark:         isDark,
                    onClose:        _close,
                  ),
                ),
              ),
            ),
          ),

        // The FAB — always present, centred horizontally
        Positioned(
          bottom: fabBottom,
          left: 0,
          right: 0,
          child: Center(
            child: _OverviewButton(open: _open, onTap: _toggle),
          ),
        ),
      ],
    );
  }
}

// ── Overview popup card ───────────────────────────────────────────────────────

class _OverviewPopup extends StatelessWidget {
  final int pantryCount;
  final int recipesCount;
  final bool overviewLoaded;
  final bool isDark;
  final VoidCallback onClose;

  const _OverviewPopup({
    required this.pantryCount,
    required this.recipesCount,
    required this.overviewLoaded,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (_, up, __) {
        final calTarget = up.profile?.calorieTarget ?? 2000;
        final mode      = up.profile?.cookingMode;
        final cuisines  = up.profile?.favoriteCuisines ?? [];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? const Color(0x22FFFFFF)
                  : const Color(0x12000000),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple
                    .withOpacity(isDark ? 0.28 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.insights_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Overview',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  if (mode != null)
                    Text(mode.emoji, style: const TextStyle(fontSize: 16)),

                ],
              ),
              const SizedBox(height: 16),

              // Stat row
              Row(
                children: [
                  _PopupStat(
                    icon: Icons.inventory_2_rounded,
                    value: overviewLoaded ? '$pantryCount' : '—',
                    label: 'Pantry',
                    color: AppTheme.primaryPurple,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _PopupStat(
                    icon: Icons.restaurant_menu_rounded,
                    value: overviewLoaded ? '$recipesCount' : '—',
                    label: 'Recipes',
                    color: AppTheme.successGreen,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _PopupStat(
                    icon: Icons.local_fire_department_rounded,
                    value: _formatCal(calTarget),
                    label: 'kcal/day',
                    color: AppTheme.accentOrange,
                    isDark: isDark,
                  ),
                ],
              ),

              // Cooking mode
              if (mode != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(mode.icon,
                          size: 14, color: AppTheme.primaryPurple),
                      const SizedBox(width: 8),
                      Text(
                        '${mode.label} mode · ${mode.tagline}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Cuisines
              if (cuisines.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: cuisines.take(4).map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.successGreen.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatCal(int cal) =>
      cal >= 1000 ? '${(cal / 1000).toStringAsFixed(1)}k' : '$cal';
}

class _PopupStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _PopupStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The FAB button itself ─────────────────────────────────────────────────────

class _OverviewButton extends StatefulWidget {
  final bool open;
  final VoidCallback onTap;
  const _OverviewButton({required this.open, required this.onTap});

  @override
  State<_OverviewButton> createState() => _OverviewButtonState();
}

class _OverviewButtonState extends State<_OverviewButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.forward(),
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, child) =>
            Transform.scale(scale: _pressCtrl.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.open
                ? const LinearGradient(
                    colors: [Color(0xFF4E9FF9), Color(0xFF2D7FD9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF4E9FF9), Color(0xFF2D7FD9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4E9FF9)
                    .withOpacity(widget.open ? 0.65 : 0.45),
                blurRadius: widget.open ? 24 : 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Icon(
              widget.open
                  ? Icons.close_rounded
                  : Icons.bar_chart_rounded,
              key: ValueKey(widget.open),
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}