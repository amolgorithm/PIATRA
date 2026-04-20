// lib/ui/widgets/backend_status_indicator.dart
//
// A compact, icon-only status chip that reflects the current backend state.
// Designed to sit inside AppBar rows or beside titles — never intrusive.
//
// States (icons only, no emoji per spec):
//   waking  → CircularProgressIndicator (tiny) + cloud_sync icon, amber tint
//   online  → cloud_done icon, green tint  (auto-hides after [hideDelay])
//   offline → cloud_off icon, red tint, tappable to retry
//   idle    → nothing shown
//
// Usage:
//   const BackendStatusIndicator()          // auto-hides when online
//   BackendStatusIndicator(autoHide: false) // always visible

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/backend_status_service.dart';
import '../../core/constants/theme/app_theme.dart';

class BackendStatusIndicator extends StatefulWidget {
  /// When true, the indicator fades out [hideDelay] after going online.
  final bool autoHide;

  /// How long to keep the "online" state visible before hiding.
  final Duration hideDelay;

  const BackendStatusIndicator({
    super.key,
    this.autoHide = true,
    this.hideDelay = const Duration(seconds: 3),
  });

  @override
  State<BackendStatusIndicator> createState() => _BackendStatusIndicatorState();
}

class _BackendStatusIndicatorState extends State<BackendStatusIndicator>
    with SingleTickerProviderStateMixin {
  late BackendStatus _status;
  StreamSubscription<BackendStatus>? _sub;
  bool _hidden = false;
  Timer? _hideTimer;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _status = BackendStatusService.instance.currentStatus;

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _sub = BackendStatusService.instance.statusStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _status = s;
        _hidden = false;
      });
      _fadeCtrl.value = 1.0;

      if (s == BackendStatus.online && widget.autoHide) {
        _hideTimer?.cancel();
        _hideTimer = Timer(widget.hideDelay, () {
          if (!mounted) return;
          _fadeCtrl.reverse().then((_) {
            if (mounted) setState(() => _hidden = true);
          });
        });
      }
    });

    // If already online and autoHide, start the timer immediately
    if (_status == BackendStatus.online && widget.autoHide) {
      _hideTimer = Timer(widget.hideDelay, () {
        if (!mounted) return;
        _fadeCtrl.reverse().then((_) {
          if (mounted) setState(() => _hidden = true);
        });
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == BackendStatus.idle || _hidden) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fade,
      child: _StatusChip(
        status: _status,
        onRetry: BackendStatusService.instance.retry,
      ),
    );
  }
}

// ─── Internal chip widget ─────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final BackendStatus status;
  final VoidCallback onRetry;

  const _StatusChip({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case BackendStatus.waking:
        return _Chip(
          color: AppTheme.warningYellow,
          isDark: isDark,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.warningYellow,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.cloud_sync_rounded,
                size: 13,
                color: AppTheme.warningYellow,
              ),
              const SizedBox(width: 4),
              Text(
                'Server waking',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningYellow,
                ),
              ),
            ],
          ),
        );

      case BackendStatus.online:
        return _Chip(
          color: AppTheme.successGreen,
          isDark: isDark,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_rounded, size: 13, color: AppTheme.successGreen),
              const SizedBox(width: 4),
              Text(
                'Server ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
        );

      case BackendStatus.offline:
        return GestureDetector(
          onTap: onRetry,
          child: _Chip(
            color: AppTheme.errorRed,
            isDark: isDark,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 13, color: AppTheme.errorRed),
                const SizedBox(width: 4),
                Text(
                  'Server offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.errorRed,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.refresh_rounded, size: 11, color: AppTheme.errorRed),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

class _Chip extends StatelessWidget {
  final Color color;
  final bool isDark;
  final Widget child;

  const _Chip({required this.color, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: child,
    );
  }
}

// ─── Compact dot-only variant for tight spaces ────────────────────────────────
// Shows just an icon, no label. Useful in AppBar trailing slots.

class BackendStatusDot extends StatefulWidget {
  const BackendStatusDot({super.key});

  @override
  State<BackendStatusDot> createState() => _BackendStatusDotState();
}

class _BackendStatusDotState extends State<BackendStatusDot>
    with SingleTickerProviderStateMixin {
  late BackendStatus _status;
  StreamSubscription<BackendStatus>? _sub;
  bool _hidden = false;
  Timer? _hideTimer;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _status = BackendStatusService.instance.currentStatus;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _sub = BackendStatusService.instance.statusStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _status = s;
        _hidden = false;
      });

      if (s == BackendStatus.online) {
        _pulseCtrl.stop();
        // Auto-hide after 4s
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _hidden = true);
        });
      } else {
        _pulseCtrl.repeat(reverse: true);
      }
    });

    if (_status == BackendStatus.waking) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == BackendStatus.idle || _hidden) return const SizedBox.shrink();

    final Color color;
    final IconData icon;

    switch (_status) {
      case BackendStatus.waking:
        color = AppTheme.warningYellow;
        icon = Icons.cloud_sync_rounded;
        break;
      case BackendStatus.online:
        color = AppTheme.successGreen;
        icon = Icons.cloud_done_rounded;
        break;
      case BackendStatus.offline:
        color = AppTheme.errorRed;
        icon = Icons.cloud_off_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _status == BackendStatus.offline
          ? BackendStatusService.instance.retry
          : null,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) => Opacity(
          opacity: _status == BackendStatus.waking
              ? 0.55 + _pulseCtrl.value * 0.45
              : 1.0,
          child: child,
        ),
        child: Tooltip(
          message: _status == BackendStatus.waking
              ? 'Server waking up…'
              : _status == BackendStatus.online
                  ? 'Server ready'
                  : 'Server offline — tap to retry',
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}