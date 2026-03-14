class EmotionResult {
  final String emotionType;
  final double confidence;
  final DateTime timestamp;
  final Map<String, double> allScores;

  EmotionResult({
    required this.emotionType,
    required this.confidence,
    required this.timestamp,
    required this.allScores,
  });

  factory EmotionResult.fromMap(Map<String, dynamic> map) {
    return EmotionResult(
      emotionType: map['emotion_type'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      allScores: Map<String, double>.from(
        (map['all_scores'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emotion_type': emotionType,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'all_scores': allScores,
    };
  }

  @override
  String toString() {
    return 'EmotionResult(type: $emotionType, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}
