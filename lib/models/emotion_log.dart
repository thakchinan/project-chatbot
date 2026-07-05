
/// EmotionLog คือโมเดลบันทึกข้อมูลอารมณ์ความรู้สึกรายวันแบบรวดเร็ว (Self-Report/Mood Log)
/// จัดเก็บประเภทอารมณ์ (เช่น เครียด, สงบ, สุข) ความเข้มข้นอารมณ์ความรู้สึก (1-10) และกิจกรรมหรือสาเหตุที่กระตุ้น
class EmotionLog {
  final int? logId;
  final int userId;
  final String emotionType;
  final String? triggerEvent;
  final int intensity;
  final DateTime createdAt;

  EmotionLog({
    this.logId,
    required this.userId,
    required this.emotionType,
    this.triggerEvent,
    this.intensity = 5,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory EmotionLog.fromJson(Map<String, dynamic> json) {
    return EmotionLog(
      logId: json['log_id'],
      userId: json['user_id'],
      emotionType: json['emotion_type'] ?? '',
      triggerEvent: json['trigger_event'],
      intensity: json['intensity'] ?? 5,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'emotion_type': emotionType,
      if (triggerEvent != null) 'trigger_event': triggerEvent,
      'intensity': intensity,
    };
  }

  String logDetailed() {
    return '''
บันทึกอารมณ์
=============
ประเภท: $emotionType
ความรุนแรง: $intensity/10
${triggerEvent != null ? 'เหตุการณ์กระตุ้น: $triggerEvent' : ''}
เวลา: ${createdAt.toString().substring(0, 16)}
''';
  }

  String get emoji {
    switch (emotionType.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      case 'anxious':
        return '😰';
      case 'calm':
        return '😌';
      case 'excited':
        return '🤩';
      case 'tired':
        return '😴';
      case 'stressed':
        return '😫';
      case 'neutral':
        return '😐';
      default:
        return '🙂';
    }
  }

  String get emotionNameThai {
    switch (emotionType.toLowerCase()) {
      case 'happy':
        return 'มีความสุข';
      case 'sad':
        return 'เศร้า';
      case 'angry':
        return 'โกรธ';
      case 'anxious':
        return 'วิตกกังวล';
      case 'calm':
        return 'สงบ';
      case 'excited':
        return 'ตื่นเต้น';
      case 'tired':
        return 'เหนื่อย';
      case 'stressed':
        return 'เครียด';
      case 'neutral':
        return 'ปกติ';
      default:
        return emotionType;
    }
  }
}
