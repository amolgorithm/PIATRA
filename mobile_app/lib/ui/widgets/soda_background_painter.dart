// lib/ui/widgets/soda_background_painter.dart
//
// Realistic soda pour background.
//
// LIGHT MODE:
//   - Pale cream/off-white background (like looking at a glass from outside)
//   - Amber/caramel soda liquid visible through the glass — warm, translucent
//   - Light glinting through gives bright golden highlights
//   - The "glass" effect: bright background with warm amber liquid tones
//
// DARK MODE:
//   - Deep dark background (night bar / dimly lit scene)
//   - Rich amber/brown cola clearly visible
//   - Bubbles and foam catch what little light there is
//   - More dramatic contrast
//
// GPU budget:
//   - No per-pixel shader math (no fbm, no multi-octave noise in inner loops)
//   - Simple sine waves for surface + bubbles
//   - ~60 bubble dots max, drawn as simple circles
//   - ~8 foam blobs, ~12 caustic ellipses
//   - One pour stream path
//   - repaint only when t changes (driven by external AnimationController)

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Public widget ─────────────────────────────────────────────────────────────

class SodaBackground extends StatefulWidget {
  final bool isDark;
  const SodaBackground({super.key, required this.isDark});

  @override
  State<SodaBackground> createState() => _SodaBackgroundState();
}

class _SodaBackgroundState extends State<SodaBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 16s cycle — smooth, not frenetic
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _SodaPainter(t: _ctrl.value, isDark: widget.isDark),
        size: Size.infinite,
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _SodaPainter extends CustomPainter {
  final double t;   // 0..1
  final bool isDark;

  _SodaPainter({required this.t, required this.isDark});

  // ── Light mode palette: backlit glass of cola ──────────────────────────────
  // Background = very light cream, liquid = warm amber seen through glass
  static const Color _lBg1        = Color(0xFFFBF7F0); // top — cream white
  static const Color _lBg2        = Color(0xFFF5EDD8); // bottom — warm cream
  static const Color _lLiquidTop  = Color(0xFFE8A84A); // amber surface, backlit
  static const Color _lLiquidMid  = Color(0xFFB86820); // mid amber
  static const Color _lLiquidDeep = Color(0xFF7A3A0A); // deep cola brown
  static const Color _lGlare      = Color(0xFFFFF5E0); // light glare through glass
  static const Color _lFoam       = Color(0xFFFFF0C8); // cream foam
  static const Color _lBubble     = Color(0xFFE8A84A); // amber bubble rings
  static const Color _lStream     = Color(0xFFD4861C); // pour stream

  // ── Dark mode palette: dimly lit bar, glass of cola ───────────────────────
  static const Color _dBg1        = Color(0xFF0A0806); // near black warm
  static const Color _dBg2        = Color(0xFF150E06); // very dark brown-black
  static const Color _dLiquidTop  = Color(0xFF7A3A0A); // dark amber surface
  static const Color _dLiquidMid  = Color(0xFF4A2005); // deep brown mid
  static const Color _dLiquidDeep = Color(0xFF1A0A02); // almost black cola bottom
  static const Color _dGlare      = Color(0xFFD4861C); // amber highlight rim
  static const Color _dFoam       = Color(0xFF8B5C1A); // dark foam
  static const Color _dBubble     = Color(0xFFA06828); // dim amber bubbles
  static const Color _dStream     = Color(0xFFB07030); // pour stream

  Color get bg1        => isDark ? _dBg1        : _lBg1;
  Color get bg2        => isDark ? _dBg2        : _lBg2;
  Color get liquidTop  => isDark ? _dLiquidTop  : _lLiquidTop;
  Color get liquidMid  => isDark ? _dLiquidMid  : _lLiquidMid;
  Color get liquidDeep => isDark ? _dLiquidDeep : _lLiquidDeep;
  Color get glareColor => isDark ? _dGlare      : _lGlare;
  Color get foamColor  => isDark ? _dFoam       : _lFoam;
  Color get bubbleColor=> isDark ? _dBubble     : _lBubble;
  Color get streamColor=> isDark ? _dStream     : _lStream;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pi2 = math.pi * 2;
    final slow = t * pi2;
    final med  = t * pi2 * 2.5;

    // 1. Background gradient
    _paintBackground(canvas, w, h);

    // 2. Liquid body — fills lower ~62% of screen
    final surfaceY = h * 0.40;
    final surface  = _buildSurface(w, h, surfaceY, slow, med);
    _paintLiquid(canvas, w, h, surface);

    // 3. Light glare through liquid (light mode: strong; dark mode: subtle rim)
    _paintGlare(canvas, w, h, surface);

    // 4. Rising bubbles (cheap — just circles)
    _paintBubbles(canvas, w, h, surface, slow, med);

    // 5. Pour stream from top
    _paintPourStream(canvas, w, h, surface, slow, med);

    // 6. Foam at surface
    _paintFoam(canvas, w, h, surface, slow);

    // 7. Top vignette to blend into UI
    _paintTopFade(canvas, w, h);
  }

  // ── Background ─────────────────────────────────────────────────────────────

  void _paintBackground(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [bg1, bg2],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
  }

  // ── Surface path ───────────────────────────────────────────────────────────

  List<double> _buildSurface(double w, double h, double base, double slow, double med) {
    const steps = 60;
    final pts = List<double>.filled(steps + 1, 0);
    for (int i = 0; i <= steps; i++) {
      final nx = i / steps;
      // Two simple overlapping sine waves — cheap and good-looking
      final wave1 = math.sin(nx * math.pi * 2.2 + slow)       * h * 0.022;
      final wave2 = math.sin(nx * math.pi * 4.8 - med * 0.55) * h * 0.010;
      pts[i] = base + wave1 + wave2;
    }
    return pts;
  }

  // ── Liquid body ────────────────────────────────────────────────────────────

  void _paintLiquid(Canvas canvas, double w, double h, List<double> surface) {
    final steps = surface.length - 1;
    final path = Path();
    path.moveTo(0, surface[0]);

    for (int i = 1; i <= steps; i++) {
      // Smooth cubic bezier segments
      final x0 = (i - 1) / steps * w;
      final x1 = i / steps * w;
      final y0 = surface[i - 1];
      final y1 = surface[i];
      path.cubicTo(
        x0 + (x1 - x0) * 0.45, y0,
        x0 + (x1 - x0) * 0.55, y1,
        x1, y1,
      );
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Main liquid gradient — surface is brightest (backlit), deep is darkest
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [liquidDeep, liquidMid, liquidTop],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, paint);

    // In light mode, add a secondary horizontal shimmer
    // (light passing through the glass sideways)
    if (!isDark) {
      final shimmerPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            _lGlare.withOpacity(0.0),
            _lGlare.withOpacity(0.18),
            _lGlare.withOpacity(0.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(path, shimmerPaint);
    }
  }

  // ── Glare ──────────────────────────────────────────────────────────────────

  void _paintGlare(Canvas canvas, double w, double h, List<double> surface) {
    // Light mode: bright band near surface = light passing through liquid top
    // Dark mode: just a thin bright edge line on the surface itself
    final surfYAvg = surface.fold(0.0, (a, b) => a + b) / surface.length;

    if (!isDark) {
      // Soft bright band just below surface — like backlit amber
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            glareColor.withOpacity(0.50),
            glareColor.withOpacity(0.10),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, surfYAvg, w, h * 0.18));
      // Clip to liquid area only
      canvas.save();
      final clipPath = Path()
        ..moveTo(0, surfYAvg - 20)
        ..lineTo(w, surfYAvg - 20)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.clipPath(clipPath);
      canvas.drawRect(Rect.fromLTWH(0, surfYAvg, w, h * 0.18), paint);
      canvas.restore();
    } else {
      // Dark mode: thin amber rim highlight along the surface
      final steps = surface.length - 1;
      final rimPath = Path();
      rimPath.moveTo(0, surface[0]);
      for (int i = 1; i <= steps; i++) {
        final x1 = i / steps * w;
        rimPath.lineTo(x1, surface[i]);
      }
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = glareColor.withOpacity(0.55);
      canvas.drawPath(rimPath, rimPaint);
    }
  }

  // ── Bubbles ────────────────────────────────────────────────────────────────
  // Simple rising circles — no per-bubble shader, just Paint with alpha

  void _paintBubbles(Canvas canvas, double w, double h, List<double> surface,
      double slow, double med) {
    // 5 columns × 12 bubbles = 60 draw calls max
    const cols = 5;
    const bubblesPerCol = 12;
    final rng = math.Random(42);

    final colXs = List.generate(cols, (i) {
      return (i + 0.5 + (rng.nextDouble() - 0.5) * 0.3) / cols * w;
    });
    final colSpeeds = List.generate(cols, (i) => 0.14 + rng.nextDouble() * 0.10);

    for (int col = 0; col < cols; col++) {
      final cx = colXs[col];
      final speed = colSpeeds[col];

      for (int b = 0; b < bubblesPerCol; b++) {
        final phase = b / bubblesPerCol;
        // yFrac: 0=surface, 1=bottom. Bubble rises from 1→0
        final yRaw  = 1.0 - _frac(phase + t * speed);
        final by    = h * 0.42 + yRaw * (h * 0.55);

        // Surface clip
        final si = ((cx / w) * (surface.length - 1)).clamp(0, surface.length - 2).toInt();
        if (by < surface[si]) continue;

        // Gentle horizontal drift
        final drift = math.sin(slow * 0.7 + b * 1.9 + col * 0.8) * 3.5;
        final bx = cx + drift;

        // Bubbles get slightly larger as they rise (decompression)
        final r = (1.2 + yRaw * 2.8) * (w / 400).clamp(0.5, 2.5);

        // Fade near surface
        final distToSurf = (by - surface[si]).clamp(0.0, 50.0);
        final alpha = (0.20 + yRaw * 0.30) * (distToSurf / 50.0);

        // Draw as ring (stroke only — realistic bubble look)
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.45
          ..color = bubbleColor.withOpacity(alpha.clamp(0.0, 0.7));
        canvas.drawCircle(Offset(bx, by), r, paint);

        // Tiny specular dot on bubble
        if (r > 1.8 && alpha > 0.15) {
          final specPaint = Paint()
            ..color = glareColor.withOpacity(alpha * 0.5);
          canvas.drawCircle(
            Offset(bx - r * 0.28, by - r * 0.28),
            r * 0.20,
            specPaint,
          );
        }
      }
    }
  }

  // ── Pour stream ────────────────────────────────────────────────────────────

  void _paintPourStream(Canvas canvas, double w, double h, List<double> surface,
      double slow, double med) {
    // Stream enters from top-right area
    final landX = w * 0.58 + math.sin(slow * 0.35) * w * 0.025;
    final topX  = landX + math.sin(slow * 0.55) * w * 0.015 + w * 0.04;
    final topY  = -h * 0.03;

    const steps = 30;

    // Stream left and right edges
    double lx(int i) {
      final f = i / steps.toDouble();
      final taper = 7.0 * (1.0 - f * 0.5) * (w / 400).clamp(0.5, 2.0);
      final wob = math.sin(med * 0.4 + f * math.pi * 1.8) * 2.5 * f;
      return topX + (landX - topX) * f + wob - taper;
    }

    double rx(int i) {
      final f = i / steps.toDouble();
      final taper = 7.0 * (1.0 - f * 0.5) * (w / 400).clamp(0.5, 2.0);
      final wob = math.sin(med * 0.4 + f * math.pi * 1.8) * 2.5 * f;
      return topX + (landX - topX) * f + wob + taper;
    }

    double sy(int i) {
      final f = i / steps.toDouble();
      // Parabolic drop: starts slow, accelerates
      return topY + (h * 0.48 - topY) * (f * f * 0.55 + f * 0.45);
    }

    // Only draw stream above the surface
    final landSI = ((landX / w) * (surface.length - 1)).clamp(0, surface.length - 2).toInt();
    final landSurfY = surface[landSI];
    final endStep = steps; // we let it clip naturally

    final path = Path();
    path.moveTo(lx(0), sy(0));
    for (int i = 1; i <= endStep; i++) {
      path.lineTo(lx(i), sy(i));
    }
    for (int i = endStep; i >= 0; i--) {
      path.lineTo(rx(i), sy(i));
    }
    path.close();

    final streamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          streamColor.withOpacity(0.9),
          streamColor.withOpacity(0.75),
          liquidTop.withOpacity(0.8),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(landX - 20, topY, 40, h * 0.52));
    canvas.drawPath(path, streamPaint);

    // Left-edge specular line on stream
    final specPath = Path();
    specPath.moveTo(lx(0) + 1.5, sy(0));
    for (int i = 1; i <= endStep; i++) {
      specPath.lineTo(lx(i) + 1.5, sy(i));
    }
    final specPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          glareColor.withOpacity(isDark ? 0.35 : 0.75),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(landX - 20, topY, 40, h * 0.48));
    canvas.drawPath(specPath, specPaint);

    // Impact rings at landing point
    for (int ring = 0; ring < 3; ring++) {
      final phase = _frac(t * 2.2 + ring * 0.33);
      final r  = phase * 36 * (w / 400).clamp(0.6, 1.8);
      final al = (1.0 - phase) * 0.30;
      final rPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = liquidTop.withOpacity(al);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(landX, landSurfY), width: r * 2.4, height: r * 0.55),
        rPaint,
      );
    }
  }

  // ── Foam ───────────────────────────────────────────────────────────────────

  void _paintFoam(Canvas canvas, double w, double h, List<double> surface, double slow) {
    final steps = surface.length - 1;
    final rng = math.Random(7);

    // ~50 foam blobs scattered along surface
    for (int i = 0; i < 50; i++) {
      final frac = i / 50.0;
      final x  = frac * w + math.sin(slow * 0.3 + i) * 3.0;
      final si = (frac * steps).clamp(0, steps - 1).toInt();
      final y  = surface[si];
      final oy = rng.nextDouble() * 10 - 7;
      final r  = 3.5 + rng.nextDouble() * 7.0;
      final al = isDark ? 0.08 + rng.nextDouble() * 0.12 : 0.18 + rng.nextDouble() * 0.20;
      final paint = Paint()..color = foamColor.withOpacity(al);
      canvas.drawCircle(Offset(x + rng.nextDouble() * 8 - 4, y + oy), r, paint);
    }

    // Dense foam band right at the surface line
    final foamPath = Path();
    foamPath.moveTo(0, surface[0] - 4);
    for (int i = 1; i <= steps; i++) {
      foamPath.lineTo(i / steps * w, surface[i] - 4 + rng.nextDouble() * 6);
    }
    for (int i = steps; i >= 0; i--) {
      foamPath.lineTo(i / steps * w, surface[i] + 8);
    }
    foamPath.close();

    final foamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          foamColor.withOpacity(isDark ? 0.22 : 0.35),
          foamColor.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(foamPath, foamPaint);
  }

  // ── Top fade ───────────────────────────────────────────────────────────────
  // Soft gradient at top so UI elements above blend cleanly

  void _paintTopFade(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          bg1,
          bg1.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.22));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.22), paint);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static double _frac(double x) => x - x.floorToDouble();

  @override
  bool shouldRepaint(_SodaPainter old) => old.t != t || old.isDark != isDark;
}