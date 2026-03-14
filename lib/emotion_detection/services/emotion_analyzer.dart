import '../models/emotion_result.dart';
import '../models/emotion_type.dart';

/// วิเคราะห์แนวโน้มอารมณ์จากข้อมูลหลายจุด
class EmotionAnalyzer {
  /// วิเคราะห์อารมณ์หลักจากผลลัพธ์หลายรายการ
  EmotionType getDominantEmotion(List<EmotionResult> results) {
    if (results.isEmpty) return EmotionType.neutral;

    final emotionCounts = <String, int>{};
    for (final result in results) {
      emotionCounts[result.emotionType] =
          (emotionCounts[result.emotionType] ?? 0) + 1;
    }

    final dominant = emotionCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return EmotionType.fromString(dominant);
  }

  /// คำนวณค่าเฉลี่ย confidence score
  double getAverageConfidence(List<EmotionResult> results) {
    if (results.isEmpty) return 0.0;
    final total = results.fold<double>(0, (sum, r) => sum + r.confidence);
    return total / results.length;
  }

  /// ตรวจสอบว่าอารมณ์มีแนวโน้มเปลี่ยนแปลงอย่างมากหรือไม่
  bool hasSignificantChange(List<EmotionResult> results, {double threshold = 0.3}) {
    if (results.length < 2) return false;

    for (int i = 1; i < results.length; i++) {
      if (results[i].emotionType != results[i - 1].emotionType) {
        final confidenceDiff =
            (results[i].confidence - results[i - 1].confidence).abs();
        if (confidenceDiff > threshold) return true;
      }
    }
    return false;
  }

  /// สร้างสรุปอารมณ์ในรูปแบบข้อความ
  String generateSummary(List<EmotionResult> results) {
    if (results.isEmpty) return 'ยังไม่มีข้อมูลอารมณ์';

    final dominant = getDominantEmotion(results);
    final avgConfidence = getAverageConfidence(results);
    final hasChange = hasSignificantChange(results);

    final buffer = StringBuffer();
    buffer.writeln('${dominant.emoji} อารมณ์หลัก: ${dominant.label}');
    buffer.writeln('📊 ความมั่นใจเฉลี่ย: ${(avgConfidence * 100).toStringAsFixed(1)}%');
    if (hasChange) {
      buffer.writeln('⚠️ พบการเปลี่ยนแปลงอารมณ์อย่างมีนัยสำคัญ');
    }
    return buffer.toString();
  }
}
