class EmotionConstants {
  EmotionConstants._();

  static const String tfliteModelPath = 'assets/models/emotion_model.tflite';

  static const String scalerParamsPath = 'assets/models/scaler_params.json';

  static const String emotionLabelsPath = 'assets/models/emotion_labels.json';

  static const int numClasses = 3;

  static const double confidenceThreshold = 0.3;

  static const int maxResultsForTrend = 50;

  static const int detectionIntervalSeconds = 5;

  static const Map<String, List<double>> eegFrequencyBands = {
    'delta': [0.5, 4.0],
    'theta': [4.0, 8.0],
    'alpha': [8.0, 13.0],
    'beta': [13.0, 30.0],
    'gamma': [30.0, 100.0],
  };

  static const Map<String, String> emotionLabelsTh = {
    'calm': 'ผ่อนคลาย',
    'neutral': 'ปกติ',
    'focused': 'มีสมาธิ',
    'stressed': 'เครียด/กลัว',
    'happy': 'มีความสุข',
    'sad': 'เศร้า',
  };

  static const Map<String, String> emotionEmojis = {
    'calm': '😌',
    'neutral': '😐',
    'focused': '🧠',
    'stressed': '😰',
    'happy': '😊',
    'sad': '😢',
  };
}
