// lib/ui/widgets/soda_background_painter.dart
//
// Cinematic, physically-based soda pour simulation.
// Light mode: golden amber cola pour (Coca-Cola / craft soda aesthetic)
// Dark mode:  deep indigo/violet dark cola pour (night-bar aesthetic)
//
// Technique:
//  • Multiple metaball "blobs" that merge into a realistic fluid body
//  • Layered Perlin-style noise for surface shimmer / caustics
//  • Volumetric bubble columns rising with turbulence
//  • Pour stream from top with taper + oscillation
//  • Foam collar at the liquid surface (layered alpha circles)
//  • Carbonation sparkle layer (tiny bright flecks)
//  • All driven by a single [animation] value (0→1 repeating)

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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
  final double t; // 0..1 animation progress
  final bool isDark;

  _SodaPainter({required this.t, required this.isDark});

  // ── Palette ────────────────────────────────────────────────────────────────

  // Light: rich amber cola
  static const _lightLiquidDeep   = Color(0xFFB05A0A);
  static const _lightLiquidMid    = Color(0xFFD4770F);
  static const _lightLiquidBright = Color(0xFFF5A623);
  static const _lightFoam         = Color(0xFFFFF3DC);
  static const _lightBubble       = Color(0xFFFFD580);
  static const _lightSparkle      = Color(0xFFFFFFFF);
  static const _lightBg           = Color(0xFF5C2A00);

  // Dark: deep indigo / violet dark soda
  static const _darkLiquidDeep    = Color(0xFF0A0820);
  static const _darkLiquidMid     = Color(0xFF1A1040);
  static const _darkLiquidBright  = Color(0xFF3D1F8C);
  static const _darkFoam          = Color(0xFF6B4FCC);
  static const _darkBubble        = Color(0xFF9B79FF);
  static const _darkSparkle       = Color(0xFFD4BBFF);
  static const _darkBg            = Color(0xFF05040F);

  Color get _deep   => isDark ? _darkLiquidDeep   : _lightLiquidDeep;
  Color get _mid    => isDark ? _darkLiquidMid    : _lightLiquidMid;
  Color get _bright => isDark ? _darkLiquidBright : _lightLiquidBright;
  Color get _foam   => isDark ? _darkFoam         : _lightFoam;
  Color get _bubble => isDark ? _darkBubble       : _lightBubble;
  Color get _spark  => isDark ? _darkSparkle      : _lightSparkle;
  Color get _bg     => isDark ? _darkBg           : _lightBg;

  // ── Math helpers ───────────────────────────────────────────────────────────

  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);
  double _frac(double x) => x - x.floorToDouble();

  // Simple hash-noise (deterministic pseudo-random)
  double _hash(double x, double y) {
    final v = _sin(x * 127.1 + y * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  // Smooth value noise
  double _noise(double x, double y) {
    final ix = x.floorToDouble();
    final iy = y.floorToDouble();
    final fx = _frac(x);
    final fy = _frac(y);
    final ux = fx * fx * (3 - 2 * fx);
    final uy = fy * fy * (3 - 2 * fy);
    final a = _hash(ix,     iy    );
    final b = _hash(ix+1.0, iy    );
    final c = _hash(ix,     iy+1.0);
    final d = _hash(ix+1.0, iy+1.0);
    return a + (b-a)*ux + (c-a)*uy + (d-c+a-b)*ux*uy;
  }

  // Fractional Brownian Motion — stacks noise octaves for realistic texture
  double _fbm(double x, double y, int octaves) {
    double v = 0, amp = 0.5, freq = 1.0, maxV = 0;
    for (int i = 0; i < octaves; i++) {
      v    += _noise(x * freq, y * freq) * amp;
      maxV += amp;
      amp  *= 0.5;
      freq *= 2.0;
    }
    return v / maxV;
  }

  // ── Draw ───────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pi2 = math.pi * 2;

    // --- 1. Background fill -------------------------------------------------
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [_bg, _deep],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Animated time scalars
    final slow  = t * pi2;
    final med   = t * pi2 * 2.3;
    final fast  = t * pi2 * 4.7;

    // ── 2. Liquid body (large fluid mass) -----------------------------------
    // The liquid fills the lower ~65% of the screen with a wavy top surface.

    final liquidTop = h * 0.38; // base surface height
    final surfaceWave = _buildSurface(w, h, liquidTop, slow, med);
    _drawLiquidBody(canvas, size, surfaceWave, liquidTop);

    // ── 3. Caustic / shimmer layer inside liquid ----------------------------
    _drawCaustics(canvas, size, surfaceWave, slow, med, fast);

    // ── 4. Rising bubble columns --------------------------------------------
    _drawBubbleColumns(canvas, size, surfaceWave, slow, fast);

    // ── 5. Pour stream from top ---------------------------------------------
    _drawPourStream(canvas, size, slow, med);

    // ── 6. Foam collar at liquid surface ------------------------------------
    _drawFoamCollar(canvas, size, surfaceWave);

    // ── 7. Carbonation sparkles (surface) -----------------------------------
    _drawSparkles(canvas, size, surfaceWave, fast);

    // ── 8. Vignette overlay -------------------------------------------------
    final vigPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, _bg.withOpacity(0.7)],
        radius: 0.85,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vigPaint);

    // ── 9. Light caustic overlay (top bright reflection) -------------------
    if (!isDark) {
      final topGlow = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFE08A).withOpacity(0.18),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.center,
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.5), topGlow);
    } else {
      // dark: deep purple glow from bottom
      final botGlow = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF6B2FCC).withOpacity(0.12),
          ],
          begin: Alignment.center,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.5), botGlow);
    }
  }

  // ── Surface path ──────────────────────────────────────────────────────────

  List<double> _buildSurface(double w, double h, double base,
      double slow, double med) {
    final steps = 80;
    final pts = <double>[];
    for (int i = 0; i <= steps; i++) {
      final nx = i / steps;
      // Layered waves: long swell + ripple + micro
      final swell  = _sin(nx * math.pi * 1.8 + slow)       * h * 0.025;
      final ripple = _sin(nx * math.pi * 4.3 - med * 0.7)  * h * 0.012;
      final micro  = _sin(nx * math.pi * 9.1 + slow * 1.3) * h * 0.006;
      // fbm turbulence
      final fbmV   = _fbm(nx * 3.0 + slow * 0.1, slow * 0.05, 3) - 0.5;
      pts.add(base + swell + ripple + micro + fbmV * h * 0.018);
    }
    return pts;
  }

  // ── Liquid body ───────────────────────────────────────────────────────────

  void _drawLiquidBody(Canvas canvas, Size size, List<double> surface,
      double liquidTop) {
    final w = size.width;
    final h = size.height;
    final steps = surface.length - 1;

    final path = Path();
    path.moveTo(0, surface[0]);
    for (int i = 1; i <= steps; i++) {
      final x0 = (i - 1) / steps * w;
      final x1 = i / steps * w;
      final y0 = surface[i - 1];
      final y1 = surface[i];
      // Cubic bezier for smooth wave
      path.cubicTo(x0 + (x1-x0)*0.4, y0, x0 + (x1-x0)*0.6, y1, x1, y1);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Main liquid gradient — deep to bright bottom-to-surface
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [_deep, _mid, _bright.withOpacity(0.85)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, paint);

    // Inner light refraction — diagonal highlight
    final refractPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _bright.withOpacity(0.22),
          Colors.transparent,
          _bright.withOpacity(0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, liquidTop, w, h - liquidTop));
    canvas.drawPath(path, refractPaint);
  }

  // ── Caustics ──────────────────────────────────────────────────────────────

  void _drawCaustics(Canvas canvas, Size size, List<double> surface,
      double slow, double med, double fast) {
    final w = size.width;
    final h = size.height;
    final rng = math.Random(42);

    // Draw ~14 caustic blobs
    for (int i = 0; i < 14; i++) {
      final bx = rng.nextDouble() * w;
      final by = rng.nextDouble() * h * 0.5 + h * 0.4;
      // Animate position
      final ax = _sin(slow * 0.7 + i * 2.3) * w * 0.08;
      final ay = _sin(med  * 0.5 + i * 1.7) * h * 0.04;
      final cx = bx + ax;
      final cy = by + ay;

      // Size pulse
      final r = (20 + _sin(fast * 0.3 + i) * 8) * (w / 400);
      final opacity = 0.04 + _sin(slow + i * 0.9).abs() * 0.06;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _bright.withOpacity(opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  // ── Bubble columns ────────────────────────────────────────────────────────

  void _drawBubbleColumns(Canvas canvas, Size size, List<double> surface,
      double slow, double fast) {
    final w = size.width;
    final h = size.height;
    // 7 independent bubble columns
    const cols = 7;
    final seededRng = math.Random(77);

    for (int col = 0; col < cols; col++) {
      final colX = (col + 0.5 + seededRng.nextDouble() * 0.3) / cols * w;
      // Each column has ~18 bubbles at different phases
      const bubblesPerCol = 18;

      for (int b = 0; b < bubblesPerCol; b++) {
        final phase = b / bubblesPerCol; // 0..1
        // Bubble travels from bottom to surface
        final rawY = _frac(phase + t * (0.18 + seededRng.nextDouble() * 0.14));
        final yFrac = 1.0 - rawY; // 1=bottom, 0=top
        final by = h * 0.42 + yFrac * (h * 0.55);

        // Surface index
        final si = ((colX / w) * (surface.length - 1)).clamp(0, surface.length - 2).toInt();
        final surfY = surface[si];
        if (by < surfY) continue; // above surface, skip

        // Horizontal wobble
        final wobble = _sin(fast * 0.8 + b * 2.1 + col * 0.7) * 4.0;
        final bx = colX + wobble;

        // Bubble size grows as it rises
        final r = (1.5 + yFrac * 3.5) * (w / 400);
        // Fade near surface
        final distToSurface = (by - surfY).clamp(0.0, 60.0);
        final alpha = (0.25 + yFrac * 0.35) * (distToSurface / 60.0);

        // Draw bubble: ring + highlight
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.4
          ..color = _bubble.withOpacity(alpha.clamp(0, 1));
        canvas.drawCircle(Offset(bx, by), r, paint);

        // Tiny specular on bubble
        if (r > 2.5) {
          final hPaint = Paint()
            ..color = _spark.withOpacity(alpha * 0.6);
          canvas.drawCircle(
            Offset(bx - r * 0.3, by - r * 0.3),
            r * 0.22,
            hPaint,
          );
        }
      }
    }
  }

  // ── Pour stream ───────────────────────────────────────────────────────────

  void _drawPourStream(Canvas canvas, Size size, double slow, double med) {
    final w = size.width;
    final h = size.height;

    // Stream lands slightly left of center, wiggles
    final landX = w * 0.52 + _sin(slow * 0.4) * w * 0.04;
    // Stream top (off screen slightly)
    final streamTopX = landX + _sin(slow * 0.6) * w * 0.02;
    final streamTopY = -h * 0.04;

    // Build stream path — tapers as it falls (accelerates, narrows)
    const steps = 40;
    final path = Path();

    double leftX(int i) {
      final frac = i / steps.toDouble();
      final taper = 8.0 * (1 - frac * 0.6) * (w / 400);
      final wobble = _sin(med * 0.5 + frac * math.pi * 2) * 3 * frac;
      final x = streamTopX + (landX - streamTopX) * frac + wobble;
      return x - taper;
    }
    double rightX(int i) {
      final frac = i / steps.toDouble();
      final taper = 8.0 * (1 - frac * 0.6) * (w / 400);
      final wobble = _sin(med * 0.5 + frac * math.pi * 2) * 3 * frac;
      final x = streamTopX + (landX - streamTopX) * frac + wobble;
      return x + taper;
    }
    double streamY(int i) {
      // Parabolic fall
      final frac = i / steps.toDouble();
      return streamTopY + (h * 0.5 - streamTopY) * (frac * frac * 0.6 + frac * 0.4);
    }

    // Left edge
    path.moveTo(leftX(0), streamY(0));
    for (int i = 1; i <= steps; i++) {
      path.lineTo(leftX(i), streamY(i));
    }
    // Right edge (reversed)
    for (int i = steps; i >= 0; i--) {
      path.lineTo(rightX(i), streamY(i));
    }
    path.close();

    final streamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _bright.withOpacity(0.9),
          _mid.withOpacity(0.85),
          _mid.withOpacity(0.7),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(landX - 20, streamTopY, 40, h * 0.55));
    canvas.drawPath(path, streamPaint);

    // Specular highlight on stream (left edge glow)
    final specPath = Path();
    specPath.moveTo(leftX(0) + 2, streamY(0));
    for (int i = 1; i <= steps; i++) {
      specPath.lineTo(leftX(i) + 2, streamY(i));
    }
    final specPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = LinearGradient(
        colors: [
          _spark.withOpacity(0.7),
          _spark.withOpacity(0.2),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(landX - 20, streamTopY, 40, h * 0.5));
    canvas.drawPath(specPath, specPaint);

    // Impact splash at bottom of stream
    _drawImpactSplash(canvas, size, landX, slow, med);
  }

  // ── Impact splash ─────────────────────────────────────────────────────────

  void _drawImpactSplash(Canvas canvas, Size size, double landX,
      double slow, double med) {
    final h = size.height;
    // Find surface Y at landX
    final surfY = h * 0.38 + _sin(slow) * h * 0.025;

    // Concentric rings expanding from impact
    for (int ring = 0; ring < 4; ring++) {
      final phase = _frac(t * 2.0 + ring * 0.25);
      final r = phase * 40 * (size.width / 400);
      final alpha = (1.0 - phase) * 0.35;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _bright.withOpacity(alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(landX, surfY),
          width: r * 2.5,
          height: r * 0.6,
        ),
        paint,
      );
    }

    // Upward splash droplets
    const drops = 8;
    for (int d = 0; d < drops; d++) {
      final angle = (d / drops) * math.pi - math.pi * 0.1;
      final phase = _frac(t * 3.0 + d * 0.125);
      final vel = 0.5 + (d % 3) * 0.2;
      final dx = math.cos(angle) * phase * 30 * vel;
      final dy = -(math.sin(angle) * phase * 25 * vel - phase * phase * 30);
      final alpha = (1.0 - phase) * 0.55;
      final r = (2.0 + d % 2) * (size.width / 400);
      final paint = Paint()
        ..color = _bright.withOpacity(alpha);
      canvas.drawCircle(Offset(landX + dx, surfY + dy), r, paint);
    }
  }

  // ── Foam collar ───────────────────────────────────────────────────────────

  void _drawFoamCollar(Canvas canvas, Size size, List<double> surface) {
    final w = size.width;
    final steps = surface.length - 1;

    // Draw foam as overlapping circles along the surface
    final rng = math.Random(13);
    const foamDots = 90;

    for (int i = 0; i < foamDots; i++) {
      final frac = i / foamDots.toDouble();
      final x = frac * w;
      final si = (frac * steps).clamp(0, steps - 1).toInt();
      final y = surface[si];

      // Cluster foam dots around surface
      final oy = rng.nextDouble() * 12 - 8;
      final r  = 4.0 + rng.nextDouble() * 8.0;
      final alpha = 0.15 + rng.nextDouble() * 0.25;

      final paint = Paint()
        ..color = _foam.withOpacity(alpha);
      canvas.drawCircle(Offset(x + rng.nextDouble() * 12 - 6, y + oy), r, paint);
    }

    // Dense bright foam band right at the surface
    final surfacePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _foam.withOpacity(0.35),
          _foam.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, size.height));

    final foamPath = Path();
    foamPath.moveTo(0, surface[0] - 6);
    for (int i = 1; i <= steps; i++) {
      final x = i / steps * w;
      foamPath.lineTo(x, surface[i] - 6 + rng.nextDouble() * 8);
    }
    for (int i = steps; i >= 0; i--) {
      final x = i / steps * w;
      foamPath.lineTo(x, surface[i] + 10);
    }
    foamPath.close();
    canvas.drawPath(foamPath, surfacePaint);
  }

  // ── Sparkles ──────────────────────────────────────────────────────────────

  void _drawSparkles(Canvas canvas, Size size, List<double> surface,
      double fast) {
    final w = size.width;
    final h = size.height;
    final rng = math.Random(99);
    const count = 55;

    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * w;
      final baseY = rng.nextDouble() * h * 0.5 + h * 0.38;
      // Twinkle
      final phase = _frac(t * 1.8 + i * 0.057);
      final alpha = (_sin(phase * math.pi * 2) * 0.5 + 0.5) * 0.7;
      final r = 1.0 + rng.nextDouble() * 1.5;

      final si = ((x / w) * (surface.length - 1)).clamp(0, surface.length - 2).toInt();
      if (baseY < surface[si]) continue;

      final paint = Paint()..color = _spark.withOpacity(alpha);
      canvas.drawCircle(Offset(x, baseY), r, paint);

      // Cross flare for some
      if (i % 5 == 0 && alpha > 0.5) {
        final flarePaint = Paint()
          ..color = _spark.withOpacity(alpha * 0.4)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        final fl = r * 3;
        canvas.drawLine(Offset(x - fl, baseY), Offset(x + fl, baseY), flarePaint);
        canvas.drawLine(Offset(x, baseY - fl), Offset(x, baseY + fl), flarePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SodaPainter old) =>
      old.t != t || old.isDark != isDark;
}