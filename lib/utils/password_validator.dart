/// PasswordValidator คือ Utility Class สำหรับตรวจสอบความแข็งแรงของรหัสผ่านตามมาตรฐานความปลอดภัย
/// ใช้เกณฑ์การตรวจสอบ 5 ข้อ ได้แก่:
///   1. ความยาวขั้นต่ำ 8 ตัวอักษร
///   2. มีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)
///   3. มีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว (a-z)
///   4. มีตัวเลขอย่างน้อย 1 ตัว (0-9)
///   5. มีอักขระพิเศษอย่างน้อย 1 ตัว (!@#\$%^&*()_+-=)
///
/// คืนค่าเป็น PasswordResult ที่บอกระดับความแข็งแรง (weak/medium/strong)
/// คะแนน 0-5 และรายละเอียดเกณฑ์ที่ผ่าน/ไม่ผ่านแต่ละข้อ
library;

/// ค่าคงที่ระดับความยาวขั้นต่ำของรหัสผ่าน
const int kMinPasswordLength = 8;

/// ระดับความแข็งแรงของรหัสผ่าน
enum PasswordStrength {
  /// อ่อนมาก — ผ่านเกณฑ์ 0-2 ข้อ (สีแดง)
  weak,

  /// ปานกลาง — ผ่านเกณฑ์ 3-4 ข้อ (สีส้ม)
  medium,

  /// แข็งแรง — ผ่านเกณฑ์ครบทั้ง 5 ข้อ (สีเขียว)
  strong,
}

/// ผลลัพธ์การตรวจสอบรหัสผ่าน
class PasswordResult {
  /// ระดับความแข็งแรง (weak, medium, strong)
  final PasswordStrength strength;

  /// คะแนนรวม 0-5 (จำนวนเกณฑ์ที่ผ่าน)
  final int score;

  /// รายละเอียดเกณฑ์แต่ละข้อ (true = ผ่าน, false = ไม่ผ่าน)
  final PasswordChecks checks;

  /// ข้อความแนะนำภาษาไทยสำหรับแสดงผลบน UI
  final String message;

  const PasswordResult({
    required this.strength,
    required this.score,
    required this.checks,
    required this.message,
  });
}

/// รายละเอียดเกณฑ์รหัสผ่านแต่ละข้อ
class PasswordChecks {
  /// ผ่านเกณฑ์ความยาวขั้นต่ำ 8 ตัวอักษร
  final bool minLength;

  /// มีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว
  final bool hasUppercase;

  /// มีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว
  final bool hasLowercase;

  /// มีตัวเลขอย่างน้อย 1 ตัว
  final bool hasDigit;

  /// มีอักขระพิเศษอย่างน้อย 1 ตัว
  final bool hasSpecialChar;

  const PasswordChecks({
    required this.minLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  /// จำนวนเกณฑ์ที่ผ่านทั้งหมด (0-5)
  int get passedCount {
    int count = 0;
    if (minLength) count++;
    if (hasUppercase) count++;
    if (hasLowercase) count++;
    if (hasDigit) count++;
    if (hasSpecialChar) count++;
    return count;
  }

  /// ตรวจว่าผ่านเกณฑ์ครบทุกข้อหรือไม่
  bool get allPassed => passedCount == 5;
}

/// คลาสหลักสำหรับประเมินความแข็งแรงของรหัสผ่าน
class PasswordValidator {
  /// ประเมินความแข็งแรงของรหัสผ่านที่กรอกเข้ามา
  /// คืนค่า [PasswordResult] ที่มีระดับความแข็งแรง คะแนน และรายละเอียดแต่ละเกณฑ์
  static PasswordResult evaluate(String password) {
    // ตรวจสอบเกณฑ์แต่ละข้อ
    final checks = PasswordChecks(
      minLength: password.length >= kMinPasswordLength,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasDigit: RegExp(r'[0-9]').hasMatch(password),
      hasSpecialChar: RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"|,.<>?/\\`~]').hasMatch(password),
    );

    final score = checks.passedCount;

    // กำหนดระดับความแข็งแรงตามจำนวนเกณฑ์ที่ผ่าน
    PasswordStrength strength;
    String message;

    if (password.isEmpty) {
      strength = PasswordStrength.weak;
      message = 'กรุณากรอกรหัสผ่าน';
    } else if (score <= 2) {
      strength = PasswordStrength.weak;
      message = 'รหัสผ่านอ่อนเกินไป — กรุณาเพิ่มความซับซ้อน';
    } else if (score <= 4) {
      strength = PasswordStrength.medium;
      message = 'รหัสผ่านปานกลาง — แนะนำให้เพิ่มอักขระพิเศษ';
    } else {
      strength = PasswordStrength.strong;
      message = 'รหัสผ่านแข็งแรงมาก ✓';
    }

    return PasswordResult(
      strength: strength,
      score: score,
      checks: checks,
      message: message,
    );
  }

  /// ตรวจสอบว่ารหัสผ่านผ่านเกณฑ์ขั้นต่ำที่ยอมรับได้หรือไม่
  /// ต้องผ่านอย่างน้อย 4 ข้อจาก 5 ข้อ (medium ขึ้นไป)
  static bool isAcceptable(String password) {
    final result = evaluate(password);
    return result.score >= 4;
  }

  /// ตรวจสอบรูปแบบอีเมลว่าถูกต้องตาม RFC 5322 แบบง่าย
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}
