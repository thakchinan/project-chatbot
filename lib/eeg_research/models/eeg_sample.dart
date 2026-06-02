/// Enhanced raw EEG sample — เก็บ per-channel data พร้อม metadata
///
/// แตกต่างจาก BrainwaveData เดิม:
/// - เก็บ raw µV values แยกแต่ละช่อง (ไม่ใช่ relative power)
/// - มี sequence number สำหรับ packet loss detection
/// - มี per-channel quality metadata
class EegSample {
  /// Raw voltage TP9 (behind left ear) in µV
  final double tp9;

  /// Raw voltage AF7 (left forehead) in µV
  final double af7;

  /// Raw voltage AF8 (right forehead) in µV
  final double af8;

  /// Raw voltage TP10 (behind right ear) in µV
  final double tp10;

  /// Timestamp ที่ sample นี้ถูกเก็บ
  final DateTime timestamp;

  /// BLE packet sequence number สำหรับ gap detection
  final int sequenceNumber;

  /// ถ้า sample นี้ถูก interpolate (เพราะ packet loss)
  final bool isInterpolated;

  const EegSample({
    required this.tp9,
    required this.af7,
    required this.af8,
    required this.tp10,
    required this.timestamp,
    this.sequenceNumber = 0,
    this.isInterpolated = false,
  });

  /// สร้าง zero sample สำหรับ padding
  factory EegSample.zero() => EegSample(
        tp9: 0,
        af7: 0,
        af8: 0,
        tp10: 0,
        timestamp: DateTime.now(),
      );

  /// สร้าง interpolated sample ระหว่าง 2 samples
  factory EegSample.interpolate(EegSample a, EegSample b, double t) {
    return EegSample(
      tp9: a.tp9 + (b.tp9 - a.tp9) * t,
      af7: a.af7 + (b.af7 - a.af7) * t,
      af8: a.af8 + (b.af8 - a.af8) * t,
      tp10: a.tp10 + (b.tp10 - a.tp10) * t,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (a.timestamp.millisecondsSinceEpoch +
                (b.timestamp.millisecondsSinceEpoch -
                        a.timestamp.millisecondsSinceEpoch) *
                    t)
            .round(),
      ),
      sequenceNumber: a.sequenceNumber,
      isInterpolated: true,
    );
  }

  /// ดึงค่าช่องตาม channel name
  double channel(String name) {
    switch (name) {
      case 'TP9':
        return tp9;
      case 'AF7':
        return af7;
      case 'AF8':
        return af8;
      case 'TP10':
        return tp10;
      default:
        return 0;
    }
  }

  /// ค่าเฉลี่ยทั้ง 4 ช่อง
  double get mean => (tp9 + af7 + af8 + tp10) / 4.0;

  /// List ของทุกช่อง [TP9, AF7, AF8, TP10]
  List<double> get channels => [tp9, af7, af8, tp10];

  /// Channel names ตามลำดับ
  static const List<String> channelNames = ['TP9', 'AF7', 'AF8', 'TP10'];

  Map<String, dynamic> toJson() => {
        'tp9': tp9,
        'af7': af7,
        'af8': af8,
        'tp10': tp10,
        'timestamp': timestamp.toIso8601String(),
        'seq': sequenceNumber,
        'interpolated': isInterpolated,
      };
}

/// Preprocessed EEG frame — ข้อมูลหลัง preprocessing สมบูรณ์
class EegFrame {
  /// Channel data arrays หลัง preprocessing (clean)
  final Map<String, List<double>> channels;

  /// Frame size (จำนวน samples)
  final int frameSize;

  /// Sampling rate (Hz)
  final int samplingRate;

  /// Timestamp ของ sample แรกใน frame
  final DateTime startTime;

  /// Artifact mask: true = artifact ที่ตำแหน่งนั้น
  final Map<String, List<bool>> artifactMask;

  /// Artifact rate แยกแต่ละช่อง (0.0-1.0)
  final Map<String, double> artifactRate;

  const EegFrame({
    required this.channels,
    required this.frameSize,
    required this.samplingRate,
    required this.startTime,
    this.artifactMask = const {},
    this.artifactRate = const {},
  });

  /// ดึง channel data
  List<double> operator [](String channel) => channels[channel] ?? [];

  /// Duration ของ frame เป็นวินาที
  double get durationSeconds => frameSize / samplingRate;
}
