import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/emotion_result.dart';
import '../models/emotion_type.dart';

/// Web build: EEG-based heuristic detection (no on-device TFLite).
class EmotionDetectionService {
  List<double>? _scalerMean;
  List<double>? _scalerScale;
  List<String>? _emotionLabels;
  bool _isModelLoaded = false;
  String? _lastError;

  bool get isModelLoaded => _isModelLoaded;
  String? get lastError => _lastError;

  Future<void> loadModel() async {
    try {
      await _loadScalerParams();
      await _loadEmotionLabels();
      _isModelLoaded = true;
      _lastError = null;
      debugPrint('✅ Emotion Detection (web heuristic mode)');
    } catch (e) {
      _lastError = 'โหลด model ไม่สำเร็จ: $e';
      _isModelLoaded = false;
    }
  }

  Future<void> _loadScalerParams() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/scaler_params.json');
      final data = json.decode(jsonStr);
      _scalerMean =
          List<double>.from(data['mean'].map((e) => (e as num).toDouble()));
      _scalerScale =
          List<double>.from(data['scale'].map((e) => (e as num).toDouble()));
    } catch (e) {
      debugPrint('⚠️ Scaler load failed: $e');
    }
  }

  Future<void> _loadEmotionLabels() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/emotion_labels.json');
      final data = json.decode(jsonStr);
      _emotionLabels = List<String>.from(data['classes']);
    } catch (e) {
      _emotionLabels = ['Positive', 'Neutral', 'Negative'];
    }
  }

  Future<Map<String, EmotionResult>> detectFromEEG(Map<String, double> eegData) async {
    final fallback = _fallbackDetection(eegData);
    return {
      'pytorch': fallback,
      'tflite': fallback,
    };
  }

  EmotionResult _fallbackDetection(Map<String, double> eegData) {
    double alpha = eegData['alpha'] ?? 0;
    double beta = eegData['beta'] ?? 0;
    double theta = eegData['theta'] ?? 0;
    double delta = eegData['delta'] ?? 0;
    double gamma = eegData['gamma'] ?? 0;

    double total = alpha + beta + theta + delta + gamma;
    if (total == 0) total = 1;

    double aPct = alpha / total;
    double bPct = beta / total;
    double tPct = theta / total;
    double gPct = gamma / total;

    Map<String, double> scores = {};
    // Positive: Alpha สูง + Beta ต่ำ → ผ่อนคลาย/คิดบวก
    scores['positive'] = (aPct * 1.5 + tPct * 0.3 + (1 - bPct) * 0.5).clamp(0.0, 1.0);

    // Neutral: สมดุลทุก band → สภาวะปกติ
    double balance = 1.0 - ((aPct - 0.2).abs() + (bPct - 0.2).abs() + (tPct - 0.2).abs());
    scores['neutral'] = balance.clamp(0.0, 1.0);

    // Negative: Beta/Gamma สูง (ความเครียด) หรือ Delta/Theta สูง (ซึมเศร้า/ล้า)
    scores['negative'] = (bPct * 1.0 + tPct * 0.8 + gPct * 0.5).clamp(0.0, 1.0);

    double maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore > 0) {
      scores = scores.map(
        (k, v) => MapEntry(k, double.parse((v / maxScore).toStringAsFixed(4))),
      );
    }

    String emotionType =
        scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return EmotionResult(
      emotionType: emotionType,
      confidence: scores[emotionType] ?? 0.0,
      timestamp: DateTime.now(),
      allScores: scores,
    );
  }

  Future<EmotionResult> detectFromFace(dynamic imageData) async {
    return EmotionResult(
      emotionType: EmotionType.neutral.name,
      confidence: 0.0,
      timestamp: DateTime.now(),
      allScores: {},
    );
  }

  Future<EmotionResult> detectFromVoice(List<double> audioFeatures) async {
    return EmotionResult(
      emotionType: EmotionType.neutral.name,
      confidence: 0.0,
      timestamp: DateTime.now(),
      allScores: {},
    );
  }

  void dispose() {
    _isModelLoaded = false;
  }
}
