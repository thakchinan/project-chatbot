import 'dart:math' as math;
import 'package:flutter/material.dart';

/// เกจครึ่งวงกลมสรุประดับความเสี่ยง (0–100)
class EegRiskGauge extends StatelessWidget {
  final double value;
  final Color accentColor;

  const EegRiskGauge({
    super.key,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: CustomPaint(
        painter: _GaugePainter(value.clamp(0, 100), accentColor),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color accent;

  _GaugePainter(this.value, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final radius = size.width * 0.42;
    const startAngle = math.pi;
    const sweep = math.pi;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final segments = [
      (0.33, const Color(0xFF4CAF50)),
      (0.33, const Color(0xFFFF9800)),
      (0.34, const Color(0xFFF44336)),
    ];
    var start = startAngle;
    for (final seg in segments) {
      final sweepSeg = sweep * seg.$1;
      canvas.drawArc(
        rect,
        start,
        sweepSeg,
        false,
        Paint()
          ..color = seg.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
      start += sweepSeg;
    }

    final needleAngle = startAngle + (value / 100) * sweep;
    final needleEnd = Offset(
      center.dx + radius * 0.85 * math.cos(needleAngle),
      center.dy + radius * 0.85 * math.sin(needleAngle),
    );
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.accent != accent;
}
