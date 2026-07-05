/// BrainwaveData เป็นโมเดลสำหรับจัดเก็บข้อมูลความแรงสัมพัทธ์ของคลื่นสมองแต่ละย่านความถี่ (Frequency Bands)
/// รวมถึงคะแนนสมาธิ (Attention) ความสงบ (Meditation) และวันที่/เวลาที่ตรวจบันทึกสัญญาณ
class BrainwaveData {
  final double alpha;
  final double beta;
  final double theta;
  final double delta;
  final double gamma;
  final double attention;
  final double meditation;
  final DateTime timestamp;

  BrainwaveData({
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.delta,
    required this.gamma,
    this.attention = 0,
    this.meditation = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// แปลงข้อมูลโมเดลคลื่นสมองเป็นรูปแบบ Map/JSON เพื่อใช้จัดเก็บบันทึกลงฐานข้อมูล
  Map<String, dynamic> toJson() => {
        'alpha': alpha,
        'beta': beta,
        'theta': theta,
        'delta': delta,
        'gamma': gamma,
        'attention': attention,
        'meditation': meditation,
      };
}

/// MuseBleDevice ใช้จัดเก็บรายละเอียดโครงสร้าง Bluetooth Device ของหน้ากาก Muse
class MuseBleDevice {
  final String platformName; // ชื่ออุปกรณ์ เช่น "Muse-0123"
  final String remoteId;     // เลขรหัสประจำตัวเครื่อง (MAC Address/UUID)

  const MuseBleDevice({
    required this.platformName,
    required this.remoteId,
  });
}

/// MuseScanResult ใช้จัดเก็บผลลัพธ์ที่ได้จากการสแกนหาอุปกรณ์ Muse ในบริเวณใกล้เคียง
class MuseScanResult {
  final MuseBleDevice device;
  final int rssi;            // ค่าความแรงของสัญญาณวิทยุ (Signal Strength Indicator)

  const MuseScanResult({
    required this.device,
    required this.rssi,
  });
}
