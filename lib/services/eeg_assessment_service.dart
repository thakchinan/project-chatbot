import 'package:flutter/material.dart';

/// คำนวณและจัดการข้อมูลใบสรุป qEEG (90 วินาที — DEAP Protocol 60s + 30s margin)
class EegAssessmentService {
  static Map<String, dynamic> computeFromSamples(List<Map<String, double>> samples) {
    if (samples.isEmpty) {
      return _defaultSummary();
    }

    final n = samples.length;
    double avgAlpha = 0, avgBeta = 0, avgTheta = 0, avgDelta = 0, avgGamma = 0;
    double avgAttention = 0, avgMeditation = 0;

    for (final sample in samples) {
      avgAlpha += sample['alpha']!;
      avgBeta += sample['beta']!;
      avgTheta += sample['theta']!;
      avgDelta += sample['delta']!;
      avgGamma += sample['gamma']!;
      avgAttention += sample['attention'] ?? 0;
      avgMeditation += sample['meditation'] ?? 0;
    }

    avgAlpha /= n;
    avgBeta /= n;
    avgTheta /= n;
    avgDelta /= n;
    avgGamma /= n;
    avgAttention /= n;
    avgMeditation /= n;

    const deltaMean = 22.5, deltaSd = 7.8;
    const thetaMean = 18.0, thetaSd = 6.5;
    const alphaMean = 32.0, alphaSd = 10.5;
    const betaMean = 20.0, betaSd = 7.2;
    const gammaMean = 8.5, gammaSd = 4.8;

    final deltaZScore = _zScore(avgDelta, deltaMean, deltaSd);
    final thetaZScore = _zScore(avgTheta, thetaMean, thetaSd);
    final alphaZScore = _zScore(avgAlpha, alphaMean, alphaSd);
    final betaZScore = _zScore(avgBeta, betaMean, betaSd);
    final highBetaZScore = _zScore(avgGamma, gammaMean, gammaSd);

    final alphaAsymmetry = (avgAlpha - avgBeta) / (avgAlpha + avgBeta + 0.01);
    final betaThetaRatio = avgBeta / (avgTheta + 0.01);

    double eegIndex = 50.0;
    eegIndex += (thetaZScore * 5.0).clamp(-12.5, 12.5);
    eegIndex += (deltaZScore * 4.0).clamp(-10.0, 10.0);
    eegIndex -= (alphaZScore * 5.0).clamp(-12.5, 12.5);
    eegIndex += (alphaAsymmetry * -15.0).clamp(-7.5, 7.5);
    eegIndex += ((betaThetaRatio - 1.5) * 5.0).clamp(-7.5, 7.5);
    eegIndex = eegIndex.clamp(0.0, 100.0);

    String riskLevel;
    String riskLevelEn;
    int riskColorValue;
    if (eegIndex <= 33) {
      riskLevel = 'ความเสี่ยงต่ำ';
      riskLevelEn = 'Low Risk';
      riskColorValue = 0xFF4CAF50;
    } else if (eegIndex <= 66) {
      riskLevel = 'ปานกลาง';
      riskLevelEn = 'Moderate Risk';
      riskColorValue = 0xFFFF9800;
    } else {
      riskLevel = 'ความเสี่ยงสูง';
      riskLevelEn = 'High Risk';
      riskColorValue = 0xFFF44336;
    }

    return {
      'avgAlpha': avgAlpha,
      'avgBeta': avgBeta,
      'avgTheta': avgTheta,
      'avgDelta': avgDelta,
      'avgGamma': avgGamma,
      'avgAttention': avgAttention,
      'avgMeditation': avgMeditation,
      'deltaZScore': deltaZScore,
      'thetaZScore': thetaZScore,
      'alphaZScore': alphaZScore,
      'betaZScore': betaZScore,
      'highBetaZScore': highBetaZScore,
      'alphaAsymmetry': alphaAsymmetry,
      'betaThetaRatio': betaThetaRatio,
      'eegIndex': eegIndex,
      'riskLevel': riskLevel,
      'riskLevelEn': riskLevelEn,
      'riskColorValue': riskColorValue,
      'samplesCollected': n,
      'durationSeconds': 90,
      'normRef': 'Krigolson et al. (2017), DEAP Dataset, Elderly 60+ Norms',
      'recordedAt': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _defaultSummary() {
    return {
      'avgAlpha': 0.0,
      'avgBeta': 0.0,
      'avgTheta': 0.0,
      'avgDelta': 0.0,
      'avgGamma': 0.0,
      'avgAttention': 0.0,
      'avgMeditation': 0.0,
      'deltaZScore': 0.0,
      'thetaZScore': 0.0,
      'alphaZScore': 0.0,
      'betaZScore': 0.0,
      'highBetaZScore': 0.0,
      'alphaAsymmetry': 0.0,
      'betaThetaRatio': 0.0,
      'eegIndex': 50.0,
      'riskLevel': 'ไม่มีข้อมูล',
      'riskLevelEn': 'No Data',
      'riskColorValue': 0xFF9E9E9E,
      'samplesCollected': 0,
      'durationSeconds': 90,
      'recordedAt': DateTime.now().toIso8601String(),
    };
  }

  static double _zScore(double value, double mean, double stdDev) {
    return (value - mean) / (stdDev == 0 ? 1 : stdDev);
  }

  static Color riskColor(Map<String, dynamic> s) {
    return Color(s['riskColorValue'] as int? ?? 0xFF9E9E9E);
  }

  static Map<String, dynamic> forDisplay(Map<String, dynamic> s) {
    final copy = Map<String, dynamic>.from(s);
    copy['riskColor'] = riskColor(s);
    return copy;
  }

  static Map<String, dynamic> toJson(Map<String, dynamic> s) {
    final m = Map<String, dynamic>.from(s);
    m.remove('riskColor');
    return m;
  }

  static String formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  static int? ageFromBirthDate(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  static String clinicalSummary(Map<String, dynamic> s) {
    final buf = StringBuffer();
    final mentalStateLabel = s['predictedMentalStateLabel'] as String?;
    final confidence = s['predictedMentalStateConfidence'] as double?;

    final tfliteLabel = s['tfliteMentalStateLabel'] as String?;
    final tfliteConf = s['tfliteMentalStateConfidence'] as double?;

    if (mentalStateLabel != null || tfliteLabel != null) {
      buf.write('การวิเคราะห์ด้วย AI บ่งชี้สภาวะอารมณ์: ');
      if (mentalStateLabel != null) {
        buf.write('ผลประเมินสภาวะจิตใจบ่งชี้ "$mentalStateLabel"');
        if (confidence != null) {
          buf.write(' (มั่นใจ ${(confidence * 100).toStringAsFixed(0)}%)');
        }
      }
      if (tfliteLabel != null) {
        if (mentalStateLabel != null) buf.write(' และ ');
        buf.write('ผลประเมินสภาวะอารมณ์บ่งชี้ "$tfliteLabel"');
        if (tfliteConf != null) {
          buf.write(' (มั่นใจ ${(tfliteConf * 100).toStringAsFixed(0)}%)');
        }
      }
      buf.write(' โดยจากการตรวจวิเคราะห์ค่าสถิติ ');
    } else {
      buf.write('พบความผิดปกติของคลื่นสมองในช่วง ');
    }

    final tZ = (s['thetaZScore'] as num? ?? 0.0).toDouble();
    final dZ = (s['deltaZScore'] as num? ?? 0.0).toDouble();
    final aZ = (s['alphaZScore'] as num? ?? 0.0).toDouble();
    final bZ = (s['betaZScore'] as num? ?? 0.0).toDouble();

    final abnormal = <String>[];
    if (tZ.abs() > 1.0) abnormal.add('Theta');
    if (dZ.abs() > 1.0) abnormal.add('Delta');
    if (aZ.abs() > 1.0) abnormal.add('Alpha');
    if (bZ.abs() > 1.0) abnormal.add('Beta');

    if (mentalStateLabel != null || tfliteLabel != null) {
      buf.write('พบสัญญาณสมองเบี่ยงเบนในช่วง ');
    }
    buf.write(abnormal.isEmpty ? 'ไม่มี (ปกติ)' : abnormal.join(' และ '));
    buf.write(' ');
    if (tZ > 1.0 || dZ > 1.0) buf.write('สูงกว่าค่าปกติ ร่วมกับ ');
    if (aZ < -1.0) buf.write('คลื่น Alpha ต่ำกว่าปกติ ');
    final asym = (s['alphaAsymmetry'] as num? ?? 0.0).toDouble();
    if (asym.abs() > 0.5) {
      buf.write('ความไม่สมดุลของสมองซีกซ้าย-ขวา (Alpha Asymmetry) เข้าข่ายเสี่ยง ');
    }
    final ratio = (s['betaThetaRatio'] as num? ?? 0.0).toDouble();
    if (ratio > 1.5) {
      buf.write('และอัตราส่วน Beta/Theta ที่สูงขึ้น ซึ่งสัมพันธ์กับภาวะซึมเศร้า');
    } else {
      buf.write('อัตราส่วน Beta/Theta อยู่ในเกณฑ์ปกติ');
    }
    return buf.toString();
  }

  static List<String> observations(Map<String, dynamic> s) {
    final obs = <String>[];
    final mentalStateLabel = s['predictedMentalStateLabel'] as String?;
    final confidence = s['predictedMentalStateConfidence'] as double?;
    if (mentalStateLabel != null) {
      final confStr = confidence != null ? ' (ความมั่นใจ ${(confidence * 100).toStringAsFixed(0)}%)' : '';
      obs.add('ผลประเมินสภาวะจิตใจ: $mentalStateLabel$confStr');
    }

    final tfliteLabel = s['tfliteMentalStateLabel'] as String?;
    final tfliteConf = s['tfliteMentalStateConfidence'] as double?;
    if (tfliteLabel != null) {
      final confStr = tfliteConf != null ? ' (ความมั่นใจ ${(tfliteConf * 100).toStringAsFixed(0)}%)' : '';
      obs.add('ผลประเมินสภาวะอารมณ์: $tfliteLabel$confStr');
    }

    if (((s['thetaZScore'] as num? ?? 0.0).toDouble()) > 1.0) {
      obs.add('คลื่น Theta สูงกว่าปกติ สัมพันธ์กับความคิดซ้ำซาก เหนื่อยล้า');
    }
    if (((s['deltaZScore'] as num? ?? 0.0).toDouble()) > 1.0) {
      obs.add('คลื่น Delta สูงกว่าปกติ บ่งบอกสมองล้า');
    }
    if (((s['alphaZScore'] as num? ?? 0.0).toDouble()) < -1.0) {
      obs.add('คลื่น Alpha ต่ำกว่าปกติ บ่งบอกการผ่อนคลายลดลง');
    }
    if (((s['alphaAsymmetry'] as num? ?? 0.0).toDouble()).abs() > 0.5) {
      obs.add('ความไม่สมดุลสมองซีกซ้าย-ขวา เข้าข่ายเสี่ยง');
    }
    if (((s['betaThetaRatio'] as num? ?? 0.0).toDouble()) > 1.5) {
      obs.add('Beta/Theta Ratio สูงกว่าค่าปกติ');
    }
    if (obs.isEmpty) obs.add('ไม่พบความผิดปกติที่ชัดเจน');
    return obs;
  }

  static List<String> recommendations(Map<String, dynamic> s) {
    final recs = <String>[];
    final idx = (s['eegIndex'] as num? ?? 50.0).toDouble();
    final mentalState = s['predictedMentalState'] as String?;
    final tfliteState = s['tfliteMentalState'] as String?;

    final isNegative = (mentalState != null && (mentalState.toLowerCase() == 'negative' || mentalState.toLowerCase() == 'stressed' || mentalState.toLowerCase() == 'sad' || mentalState.toLowerCase() == 'angry')) ||
                       (tfliteState != null && (tfliteState.toLowerCase() == 'negative' || tfliteState.toLowerCase() == 'stressed' || tfliteState.toLowerCase() == 'sad' || tfliteState.toLowerCase() == 'angry'));

    final isPositive = (mentalState != null && (mentalState.toLowerCase() == 'positive' || mentalState.toLowerCase() == 'happy' || mentalState.toLowerCase() == 'calm')) ||
                       (tfliteState != null && (tfliteState.toLowerCase() == 'positive' || tfliteState.toLowerCase() == 'happy' || tfliteState.toLowerCase() == 'calm' || tfliteState.toLowerCase() == 'relaxed' || tfliteState.toLowerCase() == 'focused'));

    if (isNegative) {
      recs.add('แนะนำกิจกรรมผ่อนคลายความเครียด เช่น ฝึกกำหนดลมหายใจช้าๆ หรือนั่งสมาธิ เพื่อปรับสมดุลสภาวะอารมณ์');
    } else if (isPositive) {
      recs.add('ส่งเสริมกิจกรรมที่ช่วยจรรโลงใจและสร้างความสงบสุขเพื่อรักษาจิตใจที่ดี');
    }

    recs.add('พบแพทย์/นักจิตวิทยาเพื่อประเมินอาการอย่างละเอียด');
    if (idx > 50) recs.add('ฝึกสมาธิ ผ่อนคลายความเครียด นอนหลับให้เพียงพอ');
    recs.add('ออกกำลังกายสม่ำเสมอ และดูแลโภชนาการ');
    recs.add('ประเมินซ้ำทุก 4-8 สัปดาห์');
    return recs;
  }

  /// คำอธิบายผลแบบเข้าใจง่าย (ภาษาไทย)
  static String plainInterpretation(double z) {
    if (z.abs() <= 1.0) return 'อยู่ในเกณฑ์ปกติ';
    if (z > 1.5) return 'สูงกว่าค่าปกติชัดเจน';
    if (z > 1.0) return 'สูงกว่าค่าปกติเล็กน้อย';
    if (z < -1.5) return 'ต่ำกว่าค่าปกติชัดเจน';
    return 'ต่ำกว่าค่าปกติเล็กน้อย';
  }

  static String plainRatioInterpretation(String name, double value) {
    if (name.contains('Asymmetry')) {
      if (value.abs() > 0.5) return 'ความสมดุลซีกซ้าย-ขวาเสี่ยง';
      return 'ใกล้เคียงปกติ';
    }
    if (value > 1.5) return 'สูงกว่าปกติ (สัมพันธ์ภาวะซึมเศร้า)';
    return 'อยู่ในเกณฑ์ปกติ';
  }

  static ({Color color, String label, IconData icon}) zStatus(double z) {
    if (z.abs() > 1.5) {
      return (
        color: Colors.red,
        label: z > 0 ? 'สูงกว่าปกติ' : 'ต่ำกว่าปกติ',
        icon: z > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      );
    }
    if (z.abs() > 1.0) {
      return (
        color: Colors.orange,
        label: 'เสี่ยงเล็กน้อย',
        icon: Icons.warning_amber_rounded,
      );
    }
    return (color: Colors.green, label: 'ปกติ', icon: Icons.check_circle_rounded);
  }
}
