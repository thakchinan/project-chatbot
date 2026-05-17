import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// แผนที่ Topographic ตามแบบฟอร์ม (Absolute Power / Z-Score)
class EegTopographicMap extends StatelessWidget {
  final String title;
  final bool isZScore;
  /// ค่า 0–100 สำหรับ power, หรือ z-score -3 ถึง +3
  final double value;

  const EegTopographicMap({
    super.key,
    required this.title,
    required this.value,
    this.isZScore = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansThai(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF37474F),
            ),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _TopoPainter(value: value, isZScore: isZScore),
            ),
          ),
          const SizedBox(height: 6),
          if (isZScore) _zLegend() else _powerLegend(),
        ],
      ),
    );
  }

  Widget _powerLegend() {
    return Column(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF29B6F6),
                Color(0xFF66BB6A),
                Color(0xFFFFEE58),
                Color(0xFFFF9800),
                Color(0xFFD32F2F),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ต่ำ', style: _legendStyle()),
            Text('สูง', style: _legendStyle()),
          ],
        ),
      ],
    );
  }

  Widget _zLegend() {
    const colors = [
      Color(0xFF0D47A1),
      Color(0xFF1976D2),
      Color(0xFF4DD0E1),
      Color(0xFF66BB6A),
      Color(0xFFFFEE58),
      Color(0xFFFF9800),
      Color(0xFFD32F2F),
    ];
    return Column(
      children: [
        Row(
          children: List.generate(7, (i) {
            return Expanded(
              child: Container(
                height: 10,
                color: colors[i],
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['-3', '-2', '-1', '0', '+1', '+2', '+3']
              .map((l) => Text(l, style: _legendStyle()))
              .toList(),
        ),
      ],
    );
  }

  TextStyle _legendStyle() => GoogleFonts.notoSansThai(
        fontSize: 7,
        color: Colors.grey[800],
        fontWeight: FontWeight.w500,
      );
}

class _TopoPainter extends CustomPainter {
  final double value;
  final bool isZScore;

  _TopoPainter({required this.value, required this.isZScore});

  Color _heatColor(double t) {
    t = t.clamp(0.0, 1.0);
    if (isZScore) {
      if (t < 0.17) return const Color(0xFF0D47A1);
      if (t < 0.33) return const Color(0xFF1976D2);
      if (t < 0.5) return const Color(0xFF4DD0E1);
      if (t < 0.67) return const Color(0xFF66BB6A);
      if (t < 0.83) return const Color(0xFFFFEE58);
      if (t < 0.92) return const Color(0xFFFF9800);
      return const Color(0xFFD32F2F);
    }
    if (t < 0.2) return const Color(0xFF0D47A1);
    if (t < 0.4) return const Color(0xFF29B6F6);
    if (t < 0.55) return const Color(0xFF66BB6A);
    if (t < 0.7) return const Color(0xFFFFEE58);
    if (t < 0.85) return const Color(0xFFFF9800);
    return const Color(0xFFD32F2F);
  }

  double get _normalized {
    if (isZScore) return ((value + 3) / 6).clamp(0.0, 1.0);
    return (value / 100).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final headR = size.width * 0.38;

    final headPath = Path();
    headPath.addOval(Rect.fromCircle(center: center, radius: headR));

    canvas.save();
    canvas.clipPath(headPath);

    final hotspotY = isZScore ? 0.0 : 0.25;
    final hotspot = Offset(center.dx, center.dy + headR * hotspotY);
    final base = _heatColor(_normalized * 0.55);
    final hot = _heatColor(_normalized);

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, hotspotY),
        radius: 0.95,
        colors: [
          hot,
          Color.lerp(hot, base, 0.4)!,
          Color.lerp(base, const Color(0xFF29B6F6), 0.5)!,
          const Color(0xFF1565C0),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: hotspot, radius: headR * 1.2));

    canvas.drawCircle(hotspot, headR * 1.15, paint);

    if (isZScore && value.abs() > 0.8) {
      final spot = value > 0
          ? Offset(center.dx + headR * 0.35, center.dy - headR * 0.2)
          : Offset(center.dx - headR * 0.3, center.dy + headR * 0.25);
      canvas.drawCircle(
        spot,
        headR * 0.22,
        Paint()..color = value > 0 ? const Color(0xFFD32F2F) : const Color(0xFF0D47A1),
      );
    }

    canvas.restore();

    canvas.drawOval(
      Rect.fromCircle(center: center, radius: headR),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey.shade600
        ..strokeWidth = 1.2,
    );

    final nose = Path()
      ..moveTo(center.dx, center.dy - headR - 2)
      ..lineTo(center.dx - 6, center.dy - headR + 10)
      ..lineTo(center.dx + 6, center.dy - headR + 10)
      ..close();
    canvas.drawPath(
      nose,
      Paint()
        ..color = Colors.grey.shade700
        ..style = PaintingStyle.fill,
    );

    for (final side in [-1.0, 1.0]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx + side * headR * 1.05, center.dy),
          width: headR * 0.35,
          height: headR * 0.5,
        ),
        side > 0 ? math.pi * 0.5 : -math.pi * 0.5,
        math.pi,
        false,
        Paint()
          ..color = Colors.grey.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final electrodes = [
      Offset(0, -0.55),
      Offset(-0.35, -0.2),
      Offset(0.35, -0.2),
      Offset(-0.55, 0.15),
      Offset(0.55, 0.15),
      Offset(-0.25, 0.45),
      Offset(0.25, 0.45),
      Offset(0, 0.15),
    ];
    for (final rel in electrodes) {
      final p = Offset(
        center.dx + rel.dx * headR,
        center.dy + rel.dy * headR,
      );
      canvas.drawCircle(
        p,
        2.2,
        Paint()..color = Colors.black87,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPainter old) =>
      old.value != value || old.isZScore != isZScore;
}
