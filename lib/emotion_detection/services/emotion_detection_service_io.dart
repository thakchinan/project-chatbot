import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/emotion_result.dart';
import '../models/emotion_type.dart';
import '../utils/emotion_constants.dart';

class EmotionDetectionService {
  Interpreter? _interpreter;
  List<double>? _scalerMean;
  List<double>? _scalerScale;
  List<String>? _emotionLabels;
  Map<String, String>? _indexToLabel;
  bool _isModelLoaded = false;
  String? _lastError;

  bool get isModelLoaded => _isModelLoaded;
  String? get lastError => _lastError;

  static const int _numFeatures = 988;
  static const int _numClasses = 3;

  Future<void> loadModel() async {
    try {

      _interpreter = await Interpreter.fromAsset('models/emotion_model.tflite');
      debugPrint('✅ TFLite model loaded');

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('   Input shape: $inputShape');
      debugPrint('   Output shape: $outputShape');

      await _loadScalerParams();

      await _loadEmotionLabels();

      _isModelLoaded = true;
      _lastError = null;
      debugPrint('✅ Emotion Detection Service ready (on-device)');
    } catch (e) {
      _lastError = 'โหลด model ไม่สำเร็จ: $e';
      debugPrint('❌ $_lastError');
      _isModelLoaded = false;
    }
  }

  Future<void> _loadScalerParams() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/models/scaler_params.json');
      final data = json.decode(jsonStr);

      _scalerMean = List<double>.from(data['mean'].map((e) => (e as num).toDouble()));
      _scalerScale = List<double>.from(data['scale'].map((e) => (e as num).toDouble()));

      debugPrint('✅ Scaler loaded (${_scalerMean!.length} features)');
    } catch (e) {
      debugPrint('⚠️ Scaler load failed: $e');
    }
  }

  Future<void> _loadEmotionLabels() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/models/emotion_labels.json');
      final data = json.decode(jsonStr);

      _emotionLabels = List<String>.from(data['classes']);
      _indexToLabel = Map<String, String>.from(data['index_to_label']);

      debugPrint('✅ Labels loaded: $_emotionLabels');
    } catch (e) {
      debugPrint('⚠️ Labels load failed: $e');
      _emotionLabels = ['Relaxed', 'Neutral', 'Concentrating'];
    }
  }

  List<double> _generateFeatures(Map<String, double> eegData) {
    double alpha = eegData['alpha'] ?? 0;
    double beta = eegData['beta'] ?? 0;
    double theta = eegData['theta'] ?? 0;
    double delta = eegData['delta'] ?? 0;
    double gamma = eegData['gamma'] ?? 0;

    const int channels = 4;
    const int binsPerChannel = _numFeatures ~/ channels;

    List<double> features = List.filled(_numFeatures, 0.0);

    const double binResolution = 128.0 / binsPerChannel;

    for (int ch = 0; ch < channels; ch++) {
      int offset = ch * binsPerChannel;

      double chFactor = 1.0 + (ch - 1.5) * 0.05;

      for (int bin = 0; bin < binsPerChannel; bin++) {
        double freq = bin * binResolution;
        double power = 0.0;

        if (freq >= 0.5 && freq < 4.0) {
          double w = 1.0 - ((freq - 0.5) / 3.5).abs();
          power = delta * w * chFactor;
        }

        else if (freq >= 4.0 && freq < 8.0) {
          double w = 1.0 - ((freq - 6.0) / 2.0).abs();
          power = theta * w * chFactor;
        }

        else if (freq >= 8.0 && freq < 13.0) {
          double w = 1.0 - ((freq - 10.5) / 2.5).abs();
          power = alpha * w * chFactor;
        }

        else if (freq >= 13.0 && freq < 30.0) {
          double w = 1.0 - ((freq - 21.5) / 8.5).abs();
          power = beta * w * chFactor;
        }

        else if (freq >= 30.0 && freq < 100.0) {
          double w = 1.0 - ((freq - 65.0) / 35.0).abs();
          power = gamma * w * chFactor;
        }

        else if (freq >= 100.0) {
          power = gamma * 0.01 * chFactor;
        }

        features[offset + bin] = power.clamp(0.0, double.infinity);
      }
    }

    return features;
  }

  List<double> _scaleFeatures(List<double> features) {
    if (_scalerMean == null || _scalerScale == null) return features;

    List<double> scaled = List.filled(features.length, 0.0);
    for (int i = 0; i < features.length && i < _scalerMean!.length; i++) {
      double scale = _scalerScale![i];
      if (scale == 0) scale = 1.0;
      scaled[i] = (features[i] - _scalerMean![i]) / scale;
    }
    return scaled;
  }

  Future<EmotionResult> detectFromEEG(Map<String, double> eegData) async {
    try {
      if (_interpreter != null) {
        return _predictWithTFLite(eegData);
      } else {
        return _fallbackDetection(eegData);
      }
    } catch (e) {
      _lastError = 'Detection error: $e';
      debugPrint('❌ $_lastError');
      return _fallbackDetection(eegData);
    }
  }

  EmotionResult _predictWithTFLite(Map<String, double> eegData) {

    List<double> features = _generateFeatures(eegData);

    List<double> scaledFeatures = _scaleFeatures(features);

    var input = List.generate(
      1,
      (_) => List.generate(
        _numFeatures,
        (i) => [scaledFeatures[i].isNaN ? 0.0 : scaledFeatures[i]],
      ),
    );

    var output = List.generate(1, (_) => List.filled(_numClasses, 0.0));

    _interpreter!.run(input, output);

    List<double> scores = output[0];

    double sumExp = 0;
    List<double> expScores = [];
    for (var s in scores) {
      double e = _exp(s);
      expScores.add(e);
      sumExp += e;
    }
    if (sumExp > 0) {
      scores = expScores.map((e) => e / sumExp).toList();
    }

    int bestIdx = 0;
    double bestScore = scores[0];
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestIdx = i;
      }
    }

    String emotionLabel = _indexToLabel?[bestIdx.toString()] ??
        (_emotionLabels != null && bestIdx < _emotionLabels!.length
            ? _emotionLabels![bestIdx]
            : 'neutral');

    String mappedEmotion = _mapModelLabel(emotionLabel);

    Map<String, double> allScores = {};
    for (int i = 0; i < scores.length; i++) {
      String label = _indexToLabel?[i.toString()] ??
          (_emotionLabels != null && i < _emotionLabels!.length
              ? _emotionLabels![i]
              : 'class_$i');
      String mapped = _mapModelLabel(label);
      allScores[mapped] = double.parse(scores[i].toStringAsFixed(4));
    }

    return EmotionResult(
      emotionType: mappedEmotion,
      confidence: bestScore,
      timestamp: DateTime.now(),
      allScores: allScores,
    );
  }

  String _mapModelLabel(String label) {
    switch (label.toLowerCase()) {
      // === New 3-class model (Bird et al., 2018) ===
      case 'relaxed':
      case 'calm':
        return 'calm';
      case 'neutral':
        return 'neutral';
      case 'concentrating':
      case 'focused':
      case 'focus':
        return 'focused';
      // === Legacy 4-class model (backward compatible) ===
      case 'angry/fear':
      case 'angry':
      case 'fear':
        return 'stressed';
      case 'happy':
        return 'happy';
      case 'sad':
        return 'sad';
      default:
        return 'neutral';
    }
  }

  double _exp(double x) {

    if (x > 80) return 5.54e34;
    if (x < -80) return 0.0;
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result > 0 ? result : 0.0;
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
    double dPct = delta / total;
    double gPct = gamma / total;

    Map<String, double> scores = {};

    // Relaxed: Alpha สูง + Beta ต่ำ → สงบผ่อนคลาย
    scores['calm'] = (aPct * 1.5 + tPct * 0.3 + (1 - bPct) * 0.5).clamp(0.0, 1.0);

    // Neutral: สมดุลทุก band → สภาวะปกติ
    double balance = 1.0 - ((aPct - 0.2).abs() + (bPct - 0.2).abs() + (tPct - 0.2).abs());
    scores['neutral'] = balance.clamp(0.0, 1.0);

    // Concentrating: Beta + Gamma สูง → มีสมาธิ/ตื่นตัว
    scores['focused'] = (bPct * 1.3 + gPct * 0.8 + (1 - dPct) * 0.3).clamp(0.0, 1.0);

    double maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore > 0) {
      scores = scores.map((k, v) => MapEntry(k, double.parse((v / maxScore).toStringAsFixed(4))));
    }

    String emotionType = scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;

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
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}
