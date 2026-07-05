import 'dart:math';
import 'package:flutter/material.dart';
import '../models/brain_data.dart';

/// Class BrainProvider สำหรับจัดการข้อมูลและสภาวะคลื่นสมอง (State Management)
/// โดยใช้ ChangeNotifier เพื่อทำการแจ้งเตือนหน้าจอต่างๆ (notifyListeners) เมื่อข้อมูลเปลี่ยนไป
class BrainProvider extends ChangeNotifier {
  // ตัวแปรเก็บผลคะแนนแบบประเมินสุขภาพจิตล่าสุด
  TestResult? _testResult;
  
  // ตัวแปรเก็บข้อมูลสัดส่วนและคุณภาพของคลื่นสมอง (Alpha, Beta, Theta)
  BrainwaveData _brainwaveData = BrainwaveData(
    alpha: 65,
    beta: 45,
    theta: 55,
    calmState: true,
    focusLevel: FocusLevel.moderate,
    relaxation: true,
  );

  // Getter สำหรับดึงข้อมูลผลแบบประเมิน
  TestResult? get testResult => _testResult;
  
  // Getter สำหรับดึงข้อมูลสถิติคลื่นสมอง
  BrainwaveData get brainwaveData => _brainwaveData;

  /// เมธอดสำหรับอัปเดตผลการทดสอบสุขภาพจิต และสั่งอัปเดต UI ที่สังเกตการทำงานอยู่
  void setTestResult(TestResult result) {
    _testResult = result;
    notifyListeners();
  }

  /// เมธอดสำหรับจำลองสุ่มสร้างค่าความแรงของคลื่นสมอง (Alpha, Beta, Theta)
  /// ใช้ในกรณีที่ไม่พบสัญญาณจริง หรือเปิดโหมด Simulate ในการนำเสนอ
  void refreshBrainwave() {
    final random = Random();
    _brainwaveData = BrainwaveData(
      alpha: random.nextInt(40) + 50, // สุ่มคลื่น Alpha ช่วง 50-90 (เด่นตอนผ่อนคลาย)
      beta: random.nextInt(40) + 30,  // สุ่มคลื่น Beta ช่วง 30-70 (เด่นตอนทำงานใช้ความคิด)
      theta: random.nextInt(40) + 40, // สุ่มคลื่น Theta ช่วง 40-80 (เด่นตอนสมาธิลึกหรือสะลึมสะลือ)
      calmState: random.nextDouble() > 0.3,
      focusLevel: random.nextDouble() > 0.6
          ? FocusLevel.high
          : random.nextDouble() > 0.3
              ? FocusLevel.moderate
              : FocusLevel.low,
      relaxation: random.nextDouble() > 0.4,
    );
    notifyListeners(); // แจ้งเตือนวิดเจ็ตต่างๆ ให้เปลี่ยนสถานะการแสดงผล
  }

  /// ฟังก์ชันประเมินระดับความเครียด/ความเสี่ยงจากสัดส่วนคะแนนที่ได้เมื่อเทียบกับคะแนนเต็ม
  static StressLevel getLevel(int score, int maxScore) {
    final percent = (score / maxScore) * 100;
    if (percent <= 25) return StressLevel.normal;      // ปกติ (0-25%)
    if (percent <= 50) return StressLevel.mild;        // เครียดเล็กน้อย (26-50%)
    if (percent <= 75) return StressLevel.moderate;    // เครียดปานกลาง (51-75%)
    return StressLevel.high;                           // เครียดระดับสูง (>75%)
  }

  /// ดึงข้อมูลการแสดงผลของระดับความเครียด เช่น อิโมจิ ข้อความอธิบาย สีประจำระดับ และคำแนะนำเบื้องต้น
  static Map<String, dynamic> getLevelInfo(StressLevel level) {
    switch (level) {
      case StressLevel.normal:
        return {
          'emoji': '😊',
          'text': 'ปกติ',
          'color': const Color(0xFF4CAF50),
          'message': 'สุขภาพจิตของคุณอยู่ในเกณฑ์ดี!'
        };
      case StressLevel.mild:
        return {
          'emoji': '😐',
          'text': 'เล็กน้อย',
          'color': const Color(0xFF8BC34A),
          'message': 'ควรพักผ่อนและทำกิจกรรมผ่อนคลาย'
        };
      case StressLevel.moderate:
        return {
          'emoji': '😟',
          'text': 'ปานกลาง',
          'color': const Color(0xFFFFC107),
          'message': 'ควรพูดคุยกับคนใกล้ชิด'
        };
      case StressLevel.high:
        return {
          'emoji': '😢',
          'text': 'สูง',
          'color': const Color(0xFFF44336),
          'message': 'แนะนำให้ปรึกษาผู้เชี่ยวชาญ'
        };
    }
  }
}
