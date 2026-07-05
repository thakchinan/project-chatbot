
/// EEGRawData เป็นคลาสโมเดลบันทึกข้อมูลคลื่นสมองระดับแพ็กเกตข้อมูลย่อย (Raw Signal Samples)
/// จัดเก็บรายละเอียดค่าเฉลี่ยคลื่นรายวินาที แยกตามย่านความถี่ (Alpha, Beta, Theta, Delta, Gamma) พร้อมตัวบ่งชี้เซสชัน
class EEGRawData {
  final int? id;
  final int userId;
  final DateTime timestamp;
  final String? channelName;
  final double? channelData;
  final double alphaWave;
  final double betaWave;
  final double thetaWave;
  final double deltaWave;
  final double gammaWave;
  final double attentionScore;
  final double meditationScore;
  final String deviceName;
  final int? sessionId;

  EEGRawData({
    this.id,
    required this.userId,
    required this.timestamp,
    this.channelName,
    this.channelData,
    this.alphaWave = 0,
    this.betaWave = 0,
    this.thetaWave = 0,
    this.deltaWave = 0,
    this.gammaWave = 0,
    this.attentionScore = 0,
    this.meditationScore = 0,
    this.deviceName = 'Muse S',
    this.sessionId,
  });

  factory EEGRawData.fromJson(Map<String, dynamic> json) {
    return EEGRawData(
      id: json['id'],
      userId: json['user_id'],
      timestamp: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'].toString())
          : DateTime.now(),
      channelName: json['channel_name'],
      channelData: json['channel_data']?.toDouble(),
      alphaWave: (json['alpha_wave'] ?? 0).toDouble(),
      betaWave: (json['beta_wave'] ?? 0).toDouble(),
      thetaWave: (json['theta_wave'] ?? 0).toDouble(),
      deltaWave: (json['delta_wave'] ?? 0).toDouble(),
      gammaWave: (json['gamma_wave'] ?? 0).toDouble(),
      attentionScore: (json['attention_score'] ?? 0).toDouble(),
      meditationScore: (json['meditation_score'] ?? 0).toDouble(),
      deviceName: json['device_name'] ?? 'Muse S',
      sessionId: json['session_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'alpha_wave': alphaWave,
      'beta_wave': betaWave,
      'theta_wave': thetaWave,
      'delta_wave': deltaWave,
      'gamma_wave': gammaWave,
      'attention_score': attentionScore,
      'meditation_score': meditationScore,
      'device_name': deviceName,
      if (channelName != null) 'channel_name': channelName,
      if (channelData != null) 'channel_data': channelData,
      if (sessionId != null) 'session_id': sessionId,
    };
  }

  bool isValid() {
    return alphaWave >= 0 &&
        betaWave >= 0 &&
        thetaWave >= 0 &&
        deltaWave >= 0 &&
        gammaWave >= 0;
  }
}
