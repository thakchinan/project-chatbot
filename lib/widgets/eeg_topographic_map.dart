import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// แผนที่ Topographic แบบหลายช่องสัญญาณ (Multi-channel) โดยใช้สมการ IDW
class EegTopographicMap extends StatelessWidget {
  final String title;
  final bool isZScore;

  /// รองรับการส่งค่าเซนเซอร์แบบระบุจุด หากไม่ได้ระบุ จะใช้ value กระจายแทน
  final Map<String, double>? sensorValues;
  final double value; // ค่าตั้งต้นสำหรับ backward compatibility

  /// รูปภาพโปร่งใสโครงหัว (จาก Assets ในเครื่อง หรือ URL) ครอบทับฮีตแมพและซ่อนขอบวาดมือ
  final String? overlayImagePath;

  const EegTopographicMap({
    super.key,
    required this.title,
    this.value = 0.0,
    this.sensorValues,
    this.isZScore = false,
    this.overlayImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverlay = overlayImagePath != null && overlayImagePath!.isNotEmpty;

    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF37474F),
            ),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. ภาพทับซ้อน (อยู่ด้านล่างเพื่อให้ฮีตแมพใช้ BlendMode.multiply ทับลงไป)
                if (hasOverlay)
                  overlayImagePath!.startsWith('http')
                      ? Image.network(
                          overlayImagePath!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        )
                      : Image.asset(
                          overlayImagePath!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                // 2. ฮีตแมพ (อยู่ด้านบน)
                CustomPaint(
                  painter: _TopoPainter(
                    value: value,
                    sensorValues: sensorValues,
                    isZScore: isZScore,
                    drawOutline: !hasOverlay, // ซ่อนขอบวาดมือถ้ารูปมาทับ
                    hasOverlay: hasOverlay,
                  ),
                ),
              ],
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
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
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
                height: 6,
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

  TextStyle _legendStyle() => GoogleFonts.prompt(
        fontSize: 8.5,
        color: AppColors.textGray,
        fontWeight: FontWeight.w500,
      );
}

class _TopoPainter extends CustomPainter {
  final double value;
  final Map<String, double>? sensorValues;
  final bool isZScore;
  final bool drawOutline;
  final bool hasOverlay;

  _TopoPainter({
    required this.value,
    this.sensorValues,
    required this.isZScore,
    this.drawOutline = true,
    this.hasOverlay = false,
  });

  Color _heatColor(double t) {
    t = t.clamp(0.0, 1.0);
    if (isZScore) {
      const colors = [
        Color(0xFF0D47A1),
        Color(0xFF1976D2),
        Color(0xFF4DD0E1),
        Color(0xFF66BB6A),
        Color(0xFFFFEE58),
        Color(0xFFFF9800),
        Color(0xFFD32F2F),
      ];
      final double scaledT = t * (colors.length - 1);
      final int index = scaledT.floor();
      final double localT = scaledT - index;
      if (index >= colors.length - 1) return colors.last;
      return Color.lerp(colors[index], colors[index + 1], localT)!;
    }
    const colors = [
      Color(0xFF0D47A1),
      Color(0xFF29B6F6),
      Color(0xFF66BB6A),
      Color(0xFFFFEE58),
      Color(0xFFFF9800),
      Color(0xFFD32F2F),
    ];
    final double scaledT = t * (colors.length - 1);
    final int index = scaledT.floor();
    final double localT = scaledT - index;
    if (index >= colors.length - 1) return colors.last;
    return Color.lerp(colors[index], colors[index + 1], localT)!;
  }

  double _normalize(double val) {
    if (isZScore) return ((val + 3) / 6).clamp(0.0, 1.0);
    return (val / 100).clamp(0.0, 1.0);
  }

  // คำนวณสีพิกเซลด้วย Inverse Distance Weighting (IDW)
  Color _idwColor(Offset pt, List<Map<String, dynamic>> sensors, double headR) {
    double num = 0.0;
    double den = 0.0;
    const power = 3.0; // ค่าความเรียบของการกระจายตัว

    for (var s in sensors) {
      double dist = (pt - s['pos'] as Offset).distance;
      if (dist < 1.0) dist = 1.0; // ป้องกันหารด้วยศูนย์
      double w = 1.0 / math.pow(dist / headR, power);
      num += w * s['val'];
      den += w;
    }

    double interpVal = den == 0 ? value : num / den;
    return _heatColor(_normalize(interpVal));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hasOverlay) {
      canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.multiply);
    }

    final center = Offset(size.width / 2, size.height * 0.52);
    final headR = size.width * 0.38;

    final headPath = Path();
    headPath.addOval(Rect.fromCircle(center: center, radius: headR));

    canvas.save();
    canvas.clipPath(headPath);

    // ตำแหน่งเซนเซอร์อ้างอิงของอุปกรณ์ Muse บนหัวพิกัด (X, Y เทียบกับรัศมีหัว)
    final musePoints = {
      'AF7': Offset(-0.35, -0.35),
      'AF8': Offset(0.35, -0.35),
      'TP9': Offset(-0.65, 0.25),
      'TP10': Offset(0.65, 0.25),
    };

    List<Map<String, dynamic>> sensors = [];

    if (sensorValues != null && sensorValues!.isNotEmpty) {
      sensorValues!.forEach((k, v) {
        if (musePoints.containsKey(k)) {
          sensors.add({
            'pos': Offset(center.dx + musePoints[k]!.dx * headR,
                          center.dy + musePoints[k]!.dy * headR),
            'val': v,
          });
        }
      });
    }

    if (sensors.isEmpty) {
       // โหมดเดิม (Global Value Radial Gradient)
       final hotspotY = isZScore ? 0.0 : 0.25;
       final hotspot = Offset(center.dx, center.dy + headR * hotspotY);
       final base = _heatColor(_normalize(value) * 0.55);
       final hot = _heatColor(_normalize(value));

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
    } else {
       // โหมดใหม่ (IDW Interpolation Map)
       // สร้างเป็นตารางพิกเซลเพื่อวาดแผนที่ความร้อนด้วยความละเอียดสูงขึ้น (120)
       const int resolution = 120;
       final double step = (headR * 2) / resolution;
       
       for (int y = 0; y < resolution; y++) {
         for (int x = 0; x < resolution; x++) {
           double px = center.dx - headR + (x * step);
           double py = center.dy - headR + (y * step);
           Offset pt = Offset(px, py);
           
           // ให้ clipPath เป็นตัวตัดขอบวงกลมที่สมบูรณ์แบบโดยตรง
           final color = _idwColor(pt, sensors, headR);
           final paint = Paint()
             ..color = color
             ..style = PaintingStyle.fill;
           canvas.drawRect(Rect.fromLTWH(px - 0.5, py - 0.5, step + 1.0, step + 1.0), paint);
         }
       }
    }

    // วาดจุดเน้นสำหรับ Z-Score ในกรณีใช้ Global Value แบบเก่า
    if (sensors.isEmpty && isZScore && value.abs() > 0.8) {
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

    // ถ้ารูปทับมาบัง เราก็ไม่จำเป็นต้องวาดเส้นขอบหัว จมูก หรือหู
    if (drawOutline) {
      // ขอบหัว
      canvas.drawOval(
        Rect.fromCircle(center: center, radius: headR),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.blueGrey.shade300
          ..strokeWidth = 1.5,
      );

      // จมูก (แบบเส้นเวกเตอร์เรียบหรูสไตล์เครื่องมือแพทย์)
      final nosePath = Path()
        ..moveTo(center.dx - 6, center.dy - headR + 4)
        ..quadraticBezierTo(center.dx, center.dy - headR - 10, center.dx, center.dy - headR - 10)
        ..quadraticBezierTo(center.dx, center.dy - headR - 10, center.dx + 6, center.dy - headR + 4);
      canvas.drawPath(
        nosePath,
        Paint()
          ..color = Colors.blueGrey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );

      // หูซ้ายขวา
      for (final side in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx + side * headR * 1.04, center.dy),
            width: headR * 0.3,
            height: headR * 0.45,
          ),
          side > 0 ? math.pi * 0.5 : -math.pi * 0.5,
          math.pi,
          false,
          Paint()
            ..color = Colors.blueGrey.shade300
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    // จุดเซนเซอร์แบบ Glowing Nodes ดูสวยงามและล้ำสมัยขึ้น
    if (sensors.isNotEmpty) {
      for (var s in sensors) {
        // วงรัศมีเรืองแสงภายนอก
        canvas.drawCircle(
          s['pos'] as Offset,
          6.0,
          Paint()..color = Colors.white.withValues(alpha: 0.8)..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          s['pos'] as Offset,
          6.0,
          Paint()
            ..color = AppColors.primaryBlue.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        // แกนเซนเซอร์จริงสีเข้ม/น้ำเงิน
        canvas.drawCircle(
          s['pos'] as Offset,
          2.5,
          Paint()..color = AppColors.primaryBlue..style = PaintingStyle.fill,
        );
      }
    } else if (drawOutline) {
      // โหมดเก่า (จุดเซนเซอร์หลอก)
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

    if (hasOverlay) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TopoPainter old) =>
      old.value != value || 
      old.isZScore != isZScore || 
      old.sensorValues != sensorValues ||
      old.drawOutline != drawOutline;
}
