import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/emotion_result.dart';
import '../models/emotion_type.dart';

/// Single-Model EEG Emotion Detection Service (TFLite)
///
/// Runs the TFLite model (emotion_model.tflite) → Relaxed/Neutral/Concentrating
/// - Input: [1, 988, 1] (988 PSD features)
/// - Trained on TSception architecture
class EmotionDetectionService {
  // --- Model 1: Original TFLite (3-class: Relaxed/Neutral/Concentrating) ---
  Interpreter? _tfliteInterpreter;

  List<double>? _scalerMean;
  List<double>? _scalerScale;

  // --- TFLite labels (Relaxed / Neutral / Concentrating) ---
  List<String>? _tfliteLabels;
  Map<String, String>? _tfliteIndexToLabel;

  // --- Model 2: New Tsception TFLite (4-class: Angry/Fear / Happy / Relaxed / Sad) ---
  Interpreter? _tsceptionInterpreter;

  List<double>? _tsceptionScalerMean;
  List<double>? _tsceptionScalerScale;

  List<String>? _tsceptionLabels;
  Map<String, String>? _tsceptionIndexToLabel;

  bool _isModelLoaded = false;
  String? _lastError;

  bool get isModelLoaded => _isModelLoaded;
  String? get lastError => _lastError;

  static const int _numFeatures = 988;

  Future<void> loadModel() async {
    try {
      // --- Load original TFLite model ---
      try {
        _tfliteInterpreter =
            await Interpreter.fromAsset('models/emotion_model.tflite');
        debugPrint('✅ Original TFLite model loaded successfully');
      } catch (e) {
        debugPrint('⚠️ Original TFLite model load failed: $e');
      }

      // --- Load new Tsception TFLite model ---
      try {
        _tsceptionInterpreter =
            await Interpreter.fromAsset('models/Tsception.tflite');
        debugPrint('✅ New Tsception TFLite model loaded successfully');
      } catch (e) {
        debugPrint('⚠️ New Tsception TFLite model load failed: $e');
      }

      await _loadScalerParams();
      await _loadTfliteLabels();
      await _loadTsceptionScalerParams();
      await _loadTsceptionLabels();

      _isModelLoaded = _tfliteInterpreter != null || _tsceptionInterpreter != null;
      _lastError = null;
      debugPrint(
          '✅ Emotion Detection Service ready (Original-TFLite: ${_tfliteInterpreter != null}, Tsception-TFLite: ${_tsceptionInterpreter != null})');
    } catch (e) {
      _lastError = 'โหลด model ไม่สำเร็จ: $e';
      debugPrint('❌ $_lastError');
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

      debugPrint('✅ Scaler loaded (${_scalerMean!.length} features)');
    } catch (e) {
      debugPrint('⚠️ Scaler load failed: $e');
    }
  }

  Future<void> _loadTfliteLabels() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/emotion_labels.json');
      final data = json.decode(jsonStr);
      _tfliteLabels = List<String>.from(data['classes']);
      _tfliteIndexToLabel =
          Map<String, String>.from(data['index_to_label']);
      debugPrint('✅ TFLite labels loaded: $_tfliteLabels');
    } catch (e) {
      debugPrint('⚠️ TFLite labels load failed: $e');
      _tfliteLabels = ['Relaxed', 'Neutral', 'Concentrating'];
    }
  }

  Future<void> _loadTsceptionScalerParams() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/scaler_params_tsception.json');
      final data = json.decode(jsonStr);

      _tsceptionScalerMean =
          List<double>.from(data['mean'].map((e) => (e as num).toDouble()));
      _tsceptionScalerScale =
          List<double>.from(data['scale'].map((e) => (e as num).toDouble()));

      debugPrint('✅ Tsception Scaler loaded (${_tsceptionScalerMean!.length} features)');
    } catch (e) {
      debugPrint('⚠️ Tsception Scaler load failed: $e');
      _tsceptionScalerMean = _scalerMean;
      _tsceptionScalerScale = _scalerScale;
    }
  }

  Future<void> _loadTsceptionLabels() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/emotion_labels_tsception.json');
      final data = json.decode(jsonStr);
      _tsceptionLabels = List<String>.from(data['classes']);
      _tsceptionIndexToLabel =
          Map<String, String>.from(data['index_to_label']);
      debugPrint('✅ Tsception labels loaded: $_tsceptionLabels');
    } catch (e) {
      debugPrint('⚠️ Tsception labels load failed: $e');
      _tsceptionLabels = ['Angry/Fear', 'Happy', 'Relaxed', 'Sad'];
    }
  }

  // =========================================================================
  // Feature generation for the TFLite model (988 PSD features)
  // =========================================================================
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

  // =========================================================================
  // Main detection: runs TFLite model
  // =========================================================================
  Future<Map<String, EmotionResult>> detectFromEEG(
      Map<String, double> eegData) async {
    EmotionResult tfliteResult;
    EmotionResult tsceptionResult;

    // Model 1: Original TFLite (3-class)
    try {
      if (_tfliteInterpreter != null) {
        tfliteResult = _predictWithTFLite(eegData);
      } else {
        tfliteResult = _fallbackTfliteDetection(eegData);
      }
    } catch (e) {
      debugPrint('❌ TFLite prediction error: $e');
      tfliteResult = _fallbackTfliteDetection(eegData);
    }

    // Model 2: New Tsception TFLite (4-class)
    try {
      if (_tsceptionInterpreter != null) {
        tsceptionResult = _predictWithTsception(eegData);
      } else {
        tsceptionResult = _fallbackTsceptionDetection(eegData);
      }
    } catch (e) {
      debugPrint('❌ Tsception prediction error: $e');
      tsceptionResult = _fallbackTsceptionDetection(eegData);
    }

    return {
      'tflite': tfliteResult,
      'tsception': tsceptionResult,
    };
  }

  // =========================================================================
  // Original TFLite prediction (Input: [1, 988, 1])
  // =========================================================================
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

    var output = List.generate(1, (_) => List.filled(3, 0.0));

    _tfliteInterpreter!.run(input, output);

    List<double> scores =
        output[0].map((e) => (e as num).toDouble()).toList();

    // Softmax
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

    String emotionLabel = _tfliteIndexToLabel?[bestIdx.toString()] ??
        (_tfliteLabels != null && bestIdx < _tfliteLabels!.length
            ? _tfliteLabels![bestIdx]
            : 'neutral');

    String mappedEmotion = _mapModelLabel(emotionLabel);

    Map<String, double> allScores = {};
    for (int i = 0; i < scores.length; i++) {
      String label = _tfliteIndexToLabel?[i.toString()] ??
          (_tfliteLabels != null && i < _tfliteLabels!.length
              ? _tfliteLabels![i]
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
      // === TFLite model classes ===
      case 'relaxed':
      case 'calm':
        return 'calm';
      case 'neutral':
        return 'neutral';
      case 'concentrating':
      case 'focused':
      case 'focus':
        return 'focused';
      // === Legacy / PyTorch model classes for backward compatibility ===
      case 'positive':
        return 'positive';
      case 'negative':
        return 'negative';
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

  // =========================================================================
  // Fallback: TFLite-style (Relaxed / Neutral / Concentrating)
  // =========================================================================
  EmotionResult _fallbackTfliteDetection(Map<String, double> eegData) {
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
    scores['calm'] =
        (aPct * 1.5 + tPct * 0.3 + (1 - bPct) * 0.5).clamp(0.0, 1.0);

    // Neutral: สมดุลทุก band → สภาวะปกติ
    double balance = 1.0 -
        ((aPct - 0.2).abs() +
            (bPct - 0.2).abs() +
            (tPct - 0.2).abs() +
            (dPct - 0.2).abs());
    scores['neutral'] = balance.clamp(0.0, 1.0);

    // Concentrating: Beta + Gamma สูง → มีสมาธิ/ตื่นตัว
    scores['focused'] =
        (bPct * 1.3 + gPct * 0.8 + (1 - dPct) * 0.3).clamp(0.0, 1.0);

    double maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore > 0) {
      scores = scores.map((k, v) =>
          MapEntry(k, double.parse((v / maxScore).toStringAsFixed(4))));
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

  // --- Model 2: Tsception prediction (Input shape dynamic: [1, 988, 1] or [1, 988]) ---
  List<double> _scaleTsceptionFeatures(List<double> features) {
    if (_tsceptionScalerMean == null || _tsceptionScalerScale == null) return features;

    List<double> scaled = List.filled(features.length, 0.0);
    for (int i = 0; i < features.length && i < _tsceptionScalerMean!.length; i++) {
      double scale = _tsceptionScalerScale![i];
      if (scale == 0) scale = 1.0;
      scaled[i] = (features[i] - _tsceptionScalerMean![i]) / scale;
    }
    return scaled;
  }

  EmotionResult _predictWithTsception(Map<String, double> eegData) {
    List<double> features = _generateFeatures(eegData);
    List<double> scaledFeatures = _scaleTsceptionFeatures(features);

    var inputTensor = _tsceptionInterpreter!.getInputTensors()[0];
    var inputShape = inputTensor.shape;
    var input;

    if (inputShape.length == 3) {
      input = List.generate(
        1,
        (_) => List.generate(
          _numFeatures,
          (i) => [scaledFeatures[i].isNaN ? 0.0 : scaledFeatures[i]],
        ),
      );
    } else {
      input = List.generate(
        1,
        (_) => List.generate(
          _numFeatures,
          (i) => scaledFeatures[i].isNaN ? 0.0 : scaledFeatures[i],
        ),
      );
    }

    var outputTensor = _tsceptionInterpreter!.getOutputTensors()[0];
    var numClasses = outputTensor.shape[1];
    var output = List.generate(1, (_) => List.filled(numClasses, 0.0));

    _tsceptionInterpreter!.run(input, output);

    List<double> scores =
        output[0].map((e) => (e as num).toDouble()).toList();

    // Softmax
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

    String emotionLabel = _tsceptionIndexToLabel?[bestIdx.toString()] ??
        (_tsceptionLabels != null && bestIdx < _tsceptionLabels!.length
            ? _tsceptionLabels![bestIdx]
            : 'neutral');

    String mappedEmotion = _mapModelLabel(emotionLabel);

    Map<String, double> allScores = {};
    for (int i = 0; i < scores.length; i++) {
      String label = _tsceptionIndexToLabel?[i.toString()] ??
          (_tsceptionLabels != null && i < _tsceptionLabels!.length
              ? _tsceptionLabels![i]
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

  EmotionResult _fallbackTsceptionDetection(Map<String, double> eegData) {
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

    // Angry/Fear -> Stressed
    scores['stressed'] = (bPct * 1.0 + gPct * 0.8).clamp(0.0, 1.0);
    // Happy
    scores['happy'] = (aPct * 1.2 + tPct * 0.4).clamp(0.0, 1.0);
    // Relaxed -> Calm
    scores['calm'] = (aPct * 1.5 + (1 - bPct) * 0.5).clamp(0.0, 1.0);
    // Sad
    scores['sad'] = (tPct * 1.0 + dPct * 0.8).clamp(0.0, 1.0);

    double maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    if (maxScore > 0) {
      scores = scores.map((k, v) =>
          MapEntry(k, double.parse((v / maxScore).toStringAsFixed(4))));
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
    _tfliteInterpreter?.close();
    _tfliteInterpreter = null;
    _tsceptionInterpreter?.close();
    _tsceptionInterpreter = null;
    _isModelLoaded = false;
  }
}
