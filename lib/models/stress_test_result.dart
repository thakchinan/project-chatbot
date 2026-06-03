
class StressTestResult {
  final int? id;
  final int userId;
  final bool stressLevel;
  final bool depressionIndicator;
  final DateTime testDate;
  final String? assessment;
  final int stressScore;
  final int depressionScore;
  final String stressLevelText;

  StressTestResult({
    this.id,
    required this.userId,
    this.stressLevel = false,
    this.depressionIndicator = false,
    required this.testDate,
    this.assessment,
    this.stressScore = 0,
    this.depressionScore = 0,
    this.stressLevelText = 'normal',
  });

  factory StressTestResult.fromJson(Map<String, dynamic> json) {
    return StressTestResult(
      id: json['id'],
      userId: json['user_id'],
      stressLevel: (json['stress_score'] ?? 0) > 50,
      depressionIndicator: (json['depression_score'] ?? 0) > 50,
      testDate: json['test_date'] != null
          ? DateTime.parse(json['test_date'].toString())
          : DateTime.now(),
      assessment: json['assessment'],
      stressScore: json['stress_score'] ?? 0,
      depressionScore: json['depression_score'] ?? 0,
      stressLevelText: json['stress_level'] ?? 'normal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'stress_score': stressScore,
      'depression_score': depressionScore,
      'stress_level': stressLevelText,
      if (assessment != null) 'assessment': assessment,
    };
  }

  String evaluateStress() {
    if (stressScore >= 75) return 'ระดับความเครียดสูงมาก ควรพบแพทย์';
    if (stressScore >= 50) return 'ระดับความเครียดปานกลาง ควรพักผ่อน';
    if (stressScore >= 25) return 'ระดับความเครียดต่ำ สุขภาพจิตดี';
    return 'ระดับความเครียดปกติ';
  }

  String generateReport() {
    return '''
รายงานผลการทดสอบความเครียด
==========================
วันที่ทดสอบ: ${testDate.toString().substring(0, 16)}
คะแนนความเครียด: $stressScore/100
คะแนนความตึงเครียด: $depressionScore/100
ระดับ: $stressLevelText
การประเมิน: ${evaluateStress()}
${assessment != null ? 'หมายเหตุ: $assessment' : ''}
''';
  }
}
