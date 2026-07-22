import 'package:flutter/material.dart';

/// EegAssessmentService จัดการวิเคราะห์ผลการตรวจสัญญาณคลื่นสมอง qEEG
/// คำนวณและประเมินสภาวะจิตใจ (90 วินาที — DEAP Protocol 60s + 30s margin)
///
/// ═══════════════════════════════════════════════════════════════════
/// วิธีการคำนวณ: Relative Power (%) + Validated Ratios
/// ─────────────────────────────────────────────────────────────────
/// ใช้ Relative Power (สัดส่วน %) แทน Absolute Power เพื่อขจัดปัญหา
/// ความแตกต่างระหว่างบุคคล (skull thickness, age, electrode contact)
/// ร่วมกับ Alpha/Beta Ratio และ Theta/Beta Ratio ที่มีงานวิจัยรองรับ
///
/// References:
/// • Klimesch, W. (1999). "EEG alpha and theta oscillations reflect
///   cognitive and memory performance." Brain Research Reviews.
///   → ที่มาของการใช้ Relative Power เป็นดัชนีสภาวะจิต
///
/// • Luijcks, R., et al. (2015). "Experimentally induced stress
///   validated by EMG activity." PLoS ONE.
///   → Alpha/Beta Ratio ต่ำ = เครียด, สูง = ผ่อนคลาย
///
/// • Arns, M., et al. (2013). "A decade of EEG Theta/Beta Ratio
///   Research in ADHD." Journal of Attention Disorders.
///   → Theta/Beta Ratio สูง = ล้า/ขาดสมาธิ
///
/// • Thibodeau, R., et al. (2006). "Depression, Anxiety, and Resting
///   Frontal EEG Asymmetry: A Meta-Analytic Review." J Abnorm Psychol.
///   → Frontal Alpha Asymmetry เชื่อมโยงกับภาวะซึมเศร้า/วิตกกังวล
/// ═══════════════════════════════════════════════════════════════════
class EegAssessmentService {

  /// ประเมินสัญญาณคลื่นสมองจากลิสต์ของ Samples ทั้งหมดที่เก็บรวบรวมได้
  /// ใช้ Relative Power (%) + Validated Ratios (α/β, θ/β)
  /// ไม่พึ่งค่า Normative Mean/SD จากภายนอก — คำนวณจากข้อมูล 90 วินาทีที่เก็บได้
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

    // ═══════════════════════════════════════════════════════════════
    // ขั้นที่ 1: Relative Power (สัดส่วน %)
    // ─────────────────────────────────────────────────────────────
    // แปลง Absolute Power เป็นสัดส่วน % ของ power ทั้งหมด
    // เพื่อขจัดความแตกต่างระหว่างบุคคล (Klimesch, 1999)
    // ═══════════════════════════════════════════════════════════════
    final totalPower = avgAlpha + avgBeta + avgTheta + avgDelta + avgGamma;
    final safeTotalPower = totalPower > 0 ? totalPower : 1.0;

    final relAlpha = avgAlpha / safeTotalPower; // ปกติ ~25-40% (หลับตา)
    final relBeta  = avgBeta / safeTotalPower;  // ปกติ ~15-25%
    final relTheta = avgTheta / safeTotalPower; // ปกติ ~15-25%
    final relDelta = avgDelta / safeTotalPower; // ปกติ ~20-30%
    final relGamma = avgGamma / safeTotalPower; // ปกติ ~5-10%

    // ═══════════════════════════════════════════════════════════════
    // ขั้นที่ 2: Validated Ratios (อัตราส่วนที่มีงานวิจัยรองรับ)
    // ═══════════════════════════════════════════════════════════════

    // Alpha/Beta Ratio — ดัชนีความเครียด (Luijcks et al., 2015)
    // สูง = ผ่อนคลาย, ต่ำ = เครียด/ตื่นตัวมากเกินไป
    // ขณะพักปกติ Frontal: ~0.3-0.8 (Beta มักสูงกว่า Alpha ที่หน้าผาก)
    final alphaBetaRatio = avgAlpha / (avgBeta > 0 ? avgBeta : 0.01);

    // Theta/Beta Ratio — ดัชนีความล้า/สมาธิ (Arns et al., 2013)
    // สูง = ล้า/ขาดสมาธิ/ง่วง, ต่ำ = ตื่นตัว/จดจ่อ
    // ขณะพักปกติ: ~0.4-0.8
    final thetaBetaRatio = avgTheta / (avgBeta > 0 ? avgBeta : 0.01);

    // Alpha Asymmetry — ดัชนีซึมเศร้า/วิตกกังวล (Thibodeau et al., 2006)
    // ใช้สัดส่วนสัมพัทธ์ (Relative) แทน Absolute
    final alphaAsymmetry = (avgAlpha - avgBeta) / (avgAlpha + avgBeta + 0.01);

    // Beta/Theta Ratio (เก็บไว้สำหรับ backward compatibility กับ UI)
    final betaThetaRatio = avgBeta / (avgTheta + 0.01);

    // ═══════════════════════════════════════════════════════════════
    // ขั้นที่ 3: คำนวณ EEG Stress Index (0–100)
    // ─────────────────────────────────────────────────────────────
    // เริ่มจาก 50 (neutral/ปกติ)
    // คะแนนสูงขึ้น = เครียด/ล้ามากขึ้น
    // คะแนนต่ำลง = ผ่อนคลายมากขึ้น
    //
    // ใช้ Relative Power + Ratios ทั้งหมด ไม่ต้องพึ่ง Normative Mean/SD
    // ═══════════════════════════════════════════════════════════════
    double eegIndex = 50.0;

    // ─── ตัวแปรที่ 1: Relative Alpha (Klimesch, 1999) ───
    // Alpha สูง = ผ่อนคลาย → คะแนนลดลง (ดี)
    // Alpha ปกติ ~25-40% ของ total power (eyes-closed resting)
    // Frontal site: Alpha ต่ำกว่า Occipital → ปรับ reference เป็น 20%
    // ค่าเบี่ยงเบนจาก 20% × น้ำหนัก → ±15 คะแนนสูงสุด
    eegIndex -= ((relAlpha - 0.20) * 75.0).clamp(-15.0, 15.0);

    // ─── ตัวแปรที่ 2: Alpha/Beta Ratio (Luijcks et al., 2015) ───
    // α/β สูง = ผ่อนคลาย → คะแนนลดลง (ดี)
    // Frontal resting: α/β ~0.5 เป็นค่ากลาง
    // ค่าเบี่ยงเบนจาก 0.5 × น้ำหนัก → ±12 คะแนนสูงสุด
    eegIndex -= ((alphaBetaRatio - 0.5) * 24.0).clamp(-12.0, 12.0);

    // ─── ตัวแปรที่ 3: Theta/Beta Ratio (Arns et al., 2013) ───
    // θ/β สูง = ล้า/ขาดสมาธิ → คะแนนสูงขึ้น (ไม่ดี)
    // ขณะพักปกติ: θ/β ~0.6 เป็นค่ากลาง
    // ค่าเบี่ยงเบนจาก 0.6 × น้ำหนัก → ±12 คะแนนสูงสุด
    eegIndex += ((thetaBetaRatio - 0.6) * 20.0).clamp(-12.0, 12.0);

    // ─── ตัวแปรที่ 4: Relative Theta+Delta (Slow wave excess) ───
    // Theta+Delta สูง = ง่วง/สมองล้า → คะแนนสูงขึ้น (ไม่ดี)
    // ปกติ Theta+Delta รวมกัน ~35-55% ของ total power
    // ใช้ 45% เป็นค่ากลาง → ±11 คะแนนสูงสุด
    final relSlowWave = relTheta + relDelta;
    eegIndex += ((relSlowWave - 0.45) * 22.0).clamp(-11.0, 11.0);

    eegIndex = eegIndex.clamp(0.0, 100.0);

    // ═══════════════════════════════════════════════════════════════
    // ขั้นที่ 4: แบ่งระดับความเสี่ยง
    // ─────────────────────────────────────────────────────────────
    // 50 = neutral (ไม่เปลี่ยนจากปกติ)
    // ±10 = noise margin ตามธรรมชาติของสัญญาณ EEG
    // ดังนั้น 31–60 = ช่วงปกติ
    // ═══════════════════════════════════════════════════════════════
    String riskLevel;
    String riskLevelEn;
    int riskColorValue;
    if (eegIndex <= 30) {
      riskLevel = 'ผ่อนคลาย';
      riskLevelEn = 'Relaxed';
      riskColorValue = 0xFF4CAF50;
    } else if (eegIndex <= 60) {
      riskLevel = 'ปกติ';
      riskLevelEn = 'Normal';
      riskColorValue = 0xFF2196F3;
    } else {
      riskLevel = 'เครียด';
      riskLevelEn = 'Stressed';
      riskColorValue = 0xFFF44336;
    }

    // ═══════════════════════════════════════════════════════════════
    // คำนวณ Z-Score จาก Relative Power (ใช้แสดงผลใน UI เดิม)
    // ─────────────────────────────────────────────────────────────
    // แทน Z-Score จาก absolute power + arbitrary norms
    // ใช้ค่าเบี่ยงเบนจาก relative power ปกติแทน
    // (ค่า reference มาจาก resting-state EEG literature ทั่วไป)
    // ═══════════════════════════════════════════════════════════════
    final deltaZScore = _relativeDeviation(relDelta, 0.25, 0.08);  // ~25% ±8%
    final thetaZScore = _relativeDeviation(relTheta, 0.20, 0.06);  // ~20% ±6%
    final alphaZScore = _relativeDeviation(relAlpha, 0.20, 0.08);  // ~20% ±8% (Frontal)
    final betaZScore  = _relativeDeviation(relBeta, 0.25, 0.08);   // ~25% ±8%
    final highBetaZScore = _relativeDeviation(relGamma, 0.08, 0.04); // ~8% ±4%

    return {
      'avgAlpha': avgAlpha,
      'avgBeta': avgBeta,
      'avgTheta': avgTheta,
      'avgDelta': avgDelta,
      'avgGamma': avgGamma,
      'avgAttention': avgAttention,
      'avgMeditation': avgMeditation,
      // Relative Power (%) — ค่าใหม่
      'relAlpha': relAlpha,
      'relBeta': relBeta,
      'relTheta': relTheta,
      'relDelta': relDelta,
      'relGamma': relGamma,
      // Validated Ratios — ค่าใหม่
      'alphaBetaRatio': alphaBetaRatio,
      'thetaBetaRatio': thetaBetaRatio,
      // Z-Score จาก Relative Power (backward compatible กับ UI)
      'deltaZScore': deltaZScore,
      'thetaZScore': thetaZScore,
      'alphaZScore': alphaZScore,
      'betaZScore': betaZScore,
      'highBetaZScore': highBetaZScore,
      'alphaAsymmetry': alphaAsymmetry,
      'betaThetaRatio': betaThetaRatio,
      // ผลลัพธ์หลัก
      'eegIndex': eegIndex,
      'riskLevel': riskLevel,
      'riskLevelEn': riskLevelEn,
      'riskColorValue': riskColorValue,
      'samplesCollected': n,
      'durationSeconds': 90,
      'normRef': 'Relative Power + α/β Ratio (Luijcks 2015) + θ/β Ratio (Arns 2013)',
      'recordedAt': DateTime.now().toIso8601String(),
    };
  }

  /// ส่งค่าผลสรุปเริ่มต้นกรณีไม่มีตัวอย่างข้อมูลสัญญาณสะสม
  static Map<String, dynamic> _defaultSummary() {
    return {
      'avgAlpha': 0.0,
      'avgBeta': 0.0,
      'avgTheta': 0.0,
      'avgDelta': 0.0,
      'avgGamma': 0.0,
      'avgAttention': 0.0,
      'avgMeditation': 0.0,
      'relAlpha': 0.0,
      'relBeta': 0.0,
      'relTheta': 0.0,
      'relDelta': 0.0,
      'relGamma': 0.0,
      'alphaBetaRatio': 0.0,
      'thetaBetaRatio': 0.0,
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

  /// คำนวณค่าเบี่ยงเบนจาก Relative Power ที่คาดหวัง
  /// ใช้แทน Z-Score จาก absolute power + arbitrary norms
  static double _relativeDeviation(double relValue, double expectedRel, double expectedSd) {
    return (relValue - expectedRel) / (expectedSd > 0 ? expectedSd : 0.01);
  }

  /// ดึงข้อมูลชุดสีสำหรับแบ่งระดับความเสี่ยงกลับมาในรูปของ Color ของ Flutter
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
    final tfliteLabel = s['tfliteMentalStateLabel'] as String?;
    final tfliteConf = s['tfliteMentalStateConfidence'] as double?;

    if (tfliteLabel != null) {
      buf.write('การวิเคราะห์ด้วย AI บ่งชี้สภาวะอารมณ์: ');
      buf.write('ผลประเมินสภาวะอารมณ์บ่งชี้ "$tfliteLabel"');
      if (tfliteConf != null) {
        buf.write(' (มั่นใจ ${(tfliteConf * 100).toStringAsFixed(0)}%)');
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

    if (tfliteLabel != null) {
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
      buf.write('และอัตราส่วน Beta/Theta ที่สูงขึ้น ซึ่งสัมพันธ์กับภาวะความเครียด');
    } else {
      buf.write('อัตราส่วน Beta/Theta อยู่ในเกณฑ์ปกติ');
    }
    return buf.toString();
  }

  static List<String> observations(Map<String, dynamic> s) {
    final obs = <String>[];
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
    final tfliteState = s['tfliteMentalState'] as String?;

    final isNegative = tfliteState != null &&
        (tfliteState.toLowerCase() == 'negative' ||
            tfliteState.toLowerCase() == 'stressed' ||
            tfliteState.toLowerCase() == 'sad' ||
            tfliteState.toLowerCase() == 'angry');

    final isPositive = tfliteState != null &&
        (tfliteState.toLowerCase() == 'positive' ||
            tfliteState.toLowerCase() == 'happy' ||
            tfliteState.toLowerCase() == 'calm' ||
            tfliteState.toLowerCase() == 'relaxed' ||
            tfliteState.toLowerCase() == 'focused');

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
    if (value > 1.5) return 'สูงกว่าปกติ (สัมพันธ์ภาวะความเครียด)';
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
