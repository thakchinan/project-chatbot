import 'dart:math' as math;
import 'package:flutter/material.dart';

/// EegRiskGauge เป็น Widget แสดงระดับความเสี่ยงหรือคะแนนแบบครึ่งวงกลม (Gauge)
/// ใช้แสดงผลระดับดัชนีคลื่นสมองหรือความเครียดสะสมแบบพรีเมียม (0-100)
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
      height: 130,
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
    final center = Offset(size.width / 2, size.height - 12);
    final radius = size.width * 0.40;
    const startAngle = math.pi;
    const sweep = math.pi;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // วาดเส้นพื้นหลังรางวัด (แถบสีเทาด้านหลัง)
    canvas.drawArc(
      rect,
      startAngle,
      sweep,
      false,
      Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round,
    );

    // วาดส่วนแบ่งสีต่างๆ บนเกจวัด พร้อมทำเอฟเฟกต์ไล่ระดับเฉดสี
    final segments = [
      (0.33, const Color(0xFF43A047), const Color(0xFF66BB6A)),
      (0.33, const Color(0xFFF57C00), const Color(0xFFFFB74D)),
      (0.34, const Color(0xFFE53935), const Color(0xFFEF5350)),
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
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweepSeg,
            colors: [seg.$2, seg.$3],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.butt,
      );
      start += sweepSeg;
    }

    // วาดแสงเรืองรอง (Glow) ด้านหลังของเข็มชี้วัด
    final needleAngle = startAngle + (value / 100) * sweep;
    final glowEnd = Offset(
      center.dx + radius * 0.75 * math.cos(needleAngle),
      center.dy + radius * 0.75 * math.sin(needleAngle),
    );
    canvas.drawCircle(
      glowEnd,
      12,
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // วาดเข็มชี้วัดของเกจ (Needle)
    final needleEnd = Offset(
      center.dx + radius * 0.78 * math.cos(needleAngle),
      center.dy + radius * 0.78 * math.sin(needleAngle),
    );
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = accent
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // วาดวงกลมตรงจุดแกนกลางเข็มวัดพร้อมขอบเส้นรอบนอก
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(center, 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.accent != accent;
}
