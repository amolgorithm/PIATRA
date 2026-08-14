// lib/ui/widgets/energy_curve_chart.dart
//
// Line chart of the predicted glucose/energy curve. Hand-painted with
// CustomPainter rather than a charting package, consistent with the rest
// of this app (nutrient bar chart, batch-cook timeline are the same idea).

import 'package:flutter/material.dart';
import '../../core/constants/theme/app_theme.dart';
import '../../services/energy_service.dart';

class EnergyCurveChart extends StatelessWidget {
  final EnergyCurve curve;

  const EnergyCurveChart({super.key, required this.curve});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(
            painter: _EnergyChartPainter(
              curve: curve,
              lineColor: AppTheme.primaryPurple,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0 min', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryLight)),
            Text('90 min', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryLight)),
            Text('180 min', style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryLight)),
          ],
        ),
        const SizedBox(height: 14),
        if (curve.possibleEnergyDip)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.trending_down_rounded, size: 16, color: AppTheme.warningYellow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Possible energy dip after the peak, this meal might not carry you through a long study block as steadily as a lower-glycemic option.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          curve.note,
          style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryLight, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _EnergyChartPainter extends CustomPainter {
  final EnergyCurve curve;
  final Color lineColor;
  final bool isDark;

  _EnergyChartPainter({required this.curve, required this.lineColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.glucose.isEmpty) return;

    final maxG = curve.glucose.reduce((a, b) => a > b ? a : b);
    final maxVal = maxG <= 0 ? 1.0 : maxG * 1.15; // headroom so the peak isn't flush with the top
    final maxT = curve.timesMinutes.last;

    Offset toPoint(int i) {
      final x = (curve.timesMinutes[i] / maxT) * size.width;
      final y = size.height - (curve.glucose[i] / maxVal) * size.height;
      return Offset(x, y);
    }

    // baseline
    final baselinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), baselinePaint);

    final linePath = Path()..moveTo(toPoint(0).dx, toPoint(0).dy);
    for (var i = 1; i < curve.glucose.length; i++) {
      linePath.lineTo(toPoint(i).dx, toPoint(i).dy);
    }

    // filled area under the curve
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.22), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // peak marker
    final peakIdx = curve.glucose.indexOf(curve.peakGlucose >= maxG ? maxG : curve.peakGlucose);
    if (peakIdx >= 0) {
      final peakPoint = toPoint(peakIdx);
      canvas.drawCircle(peakPoint, 4, Paint()..color = lineColor);
      canvas.drawCircle(peakPoint, 7, Paint()..color = lineColor.withOpacity(0.25));
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyChartPainter oldDelegate) => oldDelegate.curve != curve;
}
