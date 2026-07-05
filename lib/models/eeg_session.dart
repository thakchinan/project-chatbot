
/// EEGSession คือโมเดลสำหรับจัดเก็บประวัติการสแกนและสถิติคลื่นสมองรายครั้ง (Session)
/// เก็บข้อมูลเวลาเริ่มต้น/สิ้นสุด คะแนนเฉลี่ยด้านสมาธิ ความสงบ ความเครียด และบทวิเคราะห์อัตโนมัติ
class EEGSession {
  final int? sessionId;
  final int userId;
  final int? deviceId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status;
  final int attentionLevel;
  final double alphaWave;
  final String? focusRecommendation;
  final double stressScore;
  final double deltaCalculated;
  final int? durationSeconds;
  final double? avgAttentionScore;
  final double? avgRelaxationScore;
  final double? avgStressScore;
  final String? dataQualityGrade;
  final String sessionType;
  final String? notes;
  final DateTime? createdAt;

  EEGSession({
    this.sessionId,
    required this.userId,
    this.deviceId,
    this.startTime,
    this.endTime,
    this.status = 'active',
    this.attentionLevel = 0,
    this.alphaWave = 0,
    this.focusRecommendation,
    this.stressScore = 0,
    this.deltaCalculated = 0,
    this.durationSeconds,
    this.avgAttentionScore,
    this.avgRelaxationScore,
    this.avgStressScore,
    this.dataQualityGrade,
    this.sessionType = 'general',
    this.notes,
    this.createdAt,
  });

  factory EEGSession.fromJson(Map<String, dynamic> json) {
    return EEGSession(
      sessionId: json['session_id'],
      userId: json['user_id'],
      deviceId: json['device_id'],
      startTime: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      endTime: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      status: json['status'] ?? 'active',
      attentionLevel: json['attention_level'] ?? 0,
      alphaWave: (json['alpha_wave'] ?? 0).toDouble(),
      focusRecommendation: json['focus_recommendation'],
      stressScore: (json['stress_score'] ?? 0).toDouble(),
      deltaCalculated: (json['delta_calculated'] ?? 0).toDouble(),
      durationSeconds: json['duration_seconds'],
      avgAttentionScore: json['avg_attention_score']?.toDouble(),
      avgRelaxationScore: json['avg_relaxation_score']?.toDouble(),
      avgStressScore: json['avg_stress_score']?.toDouble(),
      dataQualityGrade: json['data_quality_grade'],
      sessionType: json['session_type'] ?? 'general',
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      'status': status,
      'attention_level': attentionLevel,
      'alpha_wave': alphaWave,
      if (focusRecommendation != null) 'focus_recommendation': focusRecommendation,
      'stress_score': stressScore,
      'delta_calculated': deltaCalculated,
      'session_type': sessionType,
      if (notes != null) 'notes': notes,
    };
  }

  String autoAnalysis() {
    if (stressScore > 70) {
      return 'ระดับความเครียดสูง แนะนำทำกิจกรรมผ่อนคลาย';
    } else if (attentionLevel > 70) {
      return 'สมาธิดี เหมาะสำหรับการเรียนรู้';
    } else if (alphaWave > 50) {
      return 'อยู่ในสภาวะผ่อนคลาย คลื่น Alpha สูง';
    } else {
      return 'สภาวะปกติ ทำกิจกรรมตามปกติได้';
    }
  }
}
