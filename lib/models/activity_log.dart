
/// ActivityLog คือโมเดลสำหรับบันทึกข้อมูลและประวัติการเล่นเกม/กิจกรรมของคนไข้
/// บันทึกประเภทกิจกรรม ชื่อกิจกรรม คะแนนที่ได้ ระยะเวลากิจกรรม และประเภทการแทร็กอัตโนมัติ
class ActivityLog {
  final int? id;
  final int userId;
  final String activityType;
  final String activityData;
  final String? activityName;
  final DateTime timestamp;
  final bool isAutoTracked;
  final String? noteInfo;
  final int? score;
  final int? durationMinutes;

  ActivityLog({
    this.id,
    required this.userId,
    required this.activityType,
    required this.activityData,
    this.activityName,
    required this.timestamp,
    this.isAutoTracked = false,
    this.noteInfo,
    this.score,
    this.durationMinutes,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      userId: json['user_id'],
      activityType: json['activity_type'] ?? '',
      activityData: json['activity_name'] ?? '',
      activityName: json['activity_name'],
      timestamp: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'].toString())
          : DateTime.now(),
      isAutoTracked: json['is_auto_tracked'] ?? false,
      noteInfo: json['note_info'],
      score: json['score'],
      durationMinutes: json['duration_minutes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'activity_type': activityType,
      'activity_name': activityName ?? activityData,
      if (score != null) 'score': score,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      'is_auto_tracked': isAutoTracked,
      if (noteInfo != null) 'note_info': noteInfo,
    };
  }

  Map<String, dynamic> toActivityObj() {
    return {
      'type': activityType,
      'name': activityName ?? activityData,
      'score': score ?? 0,
      'duration': durationMinutes ?? 0,
      'timestamp': timestamp.toIso8601String(),
      'isAutoTracked': isAutoTracked,
    };
  }

  String exportData(int format) {
    if (format == 1) {
      return '$activityType,$activityData,$score,$durationMinutes,${timestamp.toIso8601String()}';
    }
    return toActivityObj().toString();
  }
}
