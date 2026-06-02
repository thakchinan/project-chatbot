import 'dart:math';

/// ICA-based Artifact Removal สำหรับ 4-channel Muse 2
///
/// ใช้ Regression-based approach (ไม่ใช่ full FastICA)
/// เหมาะกับ Muse 2 ที่มีเพียง 4 channels:
///
/// 1. AF7/AF8 (frontal) = reference channels สำหรับ blink artifact
///    - Blink artifact มาก ใน AF7/AF8 เพราะอยู่ใกล้ตา
///    - TP9/TP10 (temporal) ได้รับ blink artifact น้อยกว่า
///
/// 2. Template Matching:
///    - สร้าง average blink template จาก AF7/AF8
///    - ใช้ matched filter ตรวจจับตำแหน่ง blink
///
/// 3. Regression Subtraction:
///    - cleaned = raw - β × blink_component
///    - β = correlation coefficient ระหว่าง raw signal กับ blink template
///
/// อ้างอิง:
/// - Gratton, Coles & Donchin (1983) "A new method for off-line removal 
///   of ocular artifact"
/// - Schlögl et al. (2007) "Regression-based removal of eye artifacts"
class IcaArtifactRemoval {
  final int samplingRate;

  /// Blink detection threshold (µV) สำหรับ frontal channels
  final double blinkThreshold;

  /// Blink template window (samples) — ±100ms @ 256 Hz
  final int blinkWindow;

  IcaArtifactRemoval({
    this.samplingRate = 256,
    this.blinkThreshold = 80.0,
    int? blinkWindow,
  }) : blinkWindow = blinkWindow ?? (samplingRate * 0.1).round();

  /// Main entry: ลบ blink artifact จากทุก channel
  ///
  /// ใช้ AF7/AF8 เป็น blink reference
  /// ลบ blink component ออกจาก TP9/TP10
  Map<String, List<double>> removeBlinkArtifact(
      Map<String, List<double>> channels) {
    final af7 = channels['AF7'];
    final af8 = channels['AF8'];
    if (af7 == null || af8 == null) return channels;

    // 1. สร้าง reference blink signal จาก frontal channels
    final n = min(af7.length, af8.length);
    final blinkRef = List<double>.generate(n, (i) {
      return (af7[i] + af8[i]) / 2.0; // Average frontal signal
    });

    // 2. ตรวจจับตำแหน่ง blink
    final blinkPositions = _detectBlinks(blinkRef);

    if (blinkPositions.isEmpty) return channels;

    // 3. สร้าง blink template
    final template = _createBlinkTemplate(blinkRef, blinkPositions);

    if (template == null) return channels;

    // 4. สร้าง blink component signal
    final blinkComponent = _createBlinkComponent(blinkRef, blinkPositions, template);

    // 5. Regression subtraction สำหรับแต่ละ channel
    final result = Map<String, List<double>>.from(channels);

    for (final channel in channels.keys) {
      final data = channels[channel]!;
      if (data.length != blinkComponent.length) continue;

      // คำนวณ regression coefficient β
      final beta = _regressionCoefficient(data, blinkComponent);

      // ลบ blink component: cleaned = raw - β × blink
      result[channel] = List<double>.generate(data.length, (i) {
        return data[i] - beta * blinkComponent[i];
      });
    }

    return result;
  }

  /// ตรวจจับตำแหน่ง blink peaks
  List<int> _detectBlinks(List<double> data) {
    final positions = <int>[];
    final n = data.length;
    if (n < blinkWindow * 2) return positions;

    // คำนวณ moving average สำหรับ baseline
    final smoothWindow = samplingRate ~/ 4; // 250ms
    final baseline = _movingAverage(data, smoothWindow);

    // หา peaks ที่สูงกว่า threshold
    for (int i = blinkWindow; i < n - blinkWindow; i++) {
      final deviation = (data[i] - baseline[i]).abs();
      if (deviation > blinkThreshold) {
        // ตรวจสอบว่าเป็น local maximum
        bool isPeak = true;
        for (int j = max(0, i - 5); j < min(n, i + 5); j++) {
          if (j != i && (data[j] - baseline[j]).abs() > deviation) {
            isPeak = false;
            break;
          }
        }

        if (isPeak) {
          // ตรวจสอบว่าไม่ใกล้ blink ตัวก่อน (minimum 200ms apart)
          final minGap = samplingRate ~/ 5; // 200ms
          if (positions.isEmpty ||
              i - positions.last > minGap) {
            positions.add(i);
          }
        }
      }
    }

    return positions;
  }

  /// สร้าง average blink template จาก detected positions
  List<double>? _createBlinkTemplate(
      List<double> data, List<int> positions) {
    if (positions.isEmpty) return null;

    final templateLen = blinkWindow * 2 + 1;
    final template = List<double>.filled(templateLen, 0.0);
    int count = 0;

    for (final pos in positions) {
      if (pos - blinkWindow < 0 ||
          pos + blinkWindow >= data.length) {
        continue;
      }

      for (int i = 0; i < templateLen; i++) {
        template[i] += data[pos - blinkWindow + i];
      }
      count++;
    }

    if (count == 0) return null;

    // Average
    for (int i = 0; i < templateLen; i++) {
      template[i] /= count;
    }

    // Remove DC from template
    double sum = 0;
    for (final v in template) sum += v;
    final mean = sum / templateLen;
    for (int i = 0; i < templateLen; i++) {
      template[i] -= mean;
    }

    return template;
  }

  /// สร้าง continuous blink component จาก template
  List<double> _createBlinkComponent(
      List<double> data, List<int> positions, List<double> template) {
    final n = data.length;
    final component = List<double>.filled(n, 0.0);
    final halfWin = blinkWindow;

    for (final pos in positions) {
      for (int i = 0; i < template.length; i++) {
        final idx = pos - halfWin + i;
        if (idx >= 0 && idx < n) {
          component[idx] += template[i];
        }
      }
    }

    return component;
  }

  /// Regression coefficient: β = Σ(x*y) / Σ(y²)
  double _regressionCoefficient(
      List<double> signal, List<double> reference) {
    final n = min(signal.length, reference.length);
    double sumXY = 0, sumYY = 0;

    for (int i = 0; i < n; i++) {
      sumXY += signal[i] * reference[i];
      sumYY += reference[i] * reference[i];
    }

    return sumYY > 0 ? sumXY / sumYY : 0;
  }

  /// Moving average filter
  List<double> _movingAverage(List<double> data, int window) {
    final n = data.length;
    final result = List<double>.filled(n, 0.0);
    final halfWin = window ~/ 2;

    double runningSum = 0;
    int count = 0;

    // Initialize
    for (int i = 0; i < min(halfWin, n); i++) {
      runningSum += data[i];
      count++;
    }

    for (int i = 0; i < n; i++) {
      // Add right edge
      final rightIdx = i + halfWin;
      if (rightIdx < n) {
        runningSum += data[rightIdx];
        count++;
      }
      // Remove left edge
      final leftIdx = i - halfWin - 1;
      if (leftIdx >= 0) {
        runningSum -= data[leftIdx];
        count--;
      }

      result[i] = count > 0 ? runningSum / count : 0;
    }

    return result;
  }
}
