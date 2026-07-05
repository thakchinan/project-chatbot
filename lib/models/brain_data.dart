import 'package:flutter/material.dart';

/// TestResult เก็บผลสรุปคะแนนประเมินภาวะเครียดและซึมเศร้าในโปรไฟล์
class TestResult {
  final int stressScore;
  final int depressionScore;
  final StressLevel stressLevel;
  final StressLevel depressionLevel;
  final DateTime timestamp;

  TestResult({
    required this.stressScore,
    required this.depressionScore,
    required this.stressLevel,
    required this.depressionLevel,
    required this.timestamp,
  });
}

/// ระดับความรุนแรงของภาวะความเครียด/ซึมเศร้า (ปกติ, เล็กน้อย, ปานกลาง, สูง)
enum StressLevel { normal, mild, moderate, high }

/// BrainwaveData (ดั้งเดิม) ใช้สำหรับจัดเก็บความแรงสัมพัทธ์ของคลื่นสมอง Alpha, Beta, Theta และสถานะโฟกัส/ความสงบ
class BrainwaveData {
  final int alpha;
  final int beta;
  final int theta;
  final bool calmState;
  final FocusLevel focusLevel;
  final bool relaxation;

  BrainwaveData({
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.calmState,
    required this.focusLevel,
    required this.relaxation,
  });

  BrainwaveData copyWith({
    int? alpha,
    int? beta,
    int? theta,
    bool? calmState,
    FocusLevel? focusLevel,
    bool? relaxation,
  }) {
    return BrainwaveData(
      alpha: alpha ?? this.alpha,
      beta: beta ?? this.beta,
      theta: theta ?? this.theta,
      calmState: calmState ?? this.calmState,
      focusLevel: focusLevel ?? this.focusLevel,
      relaxation: relaxation ?? this.relaxation,
    );
  }
}

enum FocusLevel { low, moderate, high }

class Activity {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final List<String> benefits;

  Activity({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.benefits,
  });
}

class TriviaQuestion {
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;
  final List<String> allAnswers;

  TriviaQuestion({
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
    required this.allAnswers,
  });

  factory TriviaQuestion.fromJson(Map<String, dynamic> json) {
    final correctAnswer = _decodeHtml(json['correct_answer']);
    final incorrectAnswers = (json['incorrect_answers'] as List)
        .map((a) => _decodeHtml(a.toString()))
        .toList();

    final allAnswers = [...incorrectAnswers, correctAnswer]..shuffle();

    return TriviaQuestion(
      question: _decodeHtml(json['question']),
      correctAnswer: correctAnswer,
      incorrectAnswers: incorrectAnswers,
      allAnswers: allAnswers,
    );
  }

  static String _decodeHtml(String html) {
    return html
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&ntilde;', 'ñ');
  }
}

class MemoryCard {
  final int id;
  final String emoji;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.emoji,
    this.isFlipped = false,
    this.isMatched = false,
  });
}
