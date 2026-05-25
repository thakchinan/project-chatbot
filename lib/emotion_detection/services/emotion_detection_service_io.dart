import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/emotion_result.dart';
import '../models/emotion_type.dart';

/// Dual-Model EEG Emotion Detection Service
///
/// Runs TWO TFLite models simultaneously:
/// 1. PyTorch-converted model (eeg_mobile_model_3classes.tflite) → Positive/Neutral/Negative
///    - Input: [1, 1, 32, 5] (1 channel, 32 electrodes, 5 frequency bands)
///    - Trained on DEAP dataset
/// 2. Original TFLite model (emotion_model.tflite) → Relaxed/Neutral/Concentrating
///    - Input: [1, 988, 1] (988 PSD features)
///    - Trained on TSception architecture
class EmotionDetectionService {
  // --- Model 1: PyTorch-converted (3-class: Positive/Neutral/Negative) ---
  Interpreter? _pytorchInterpreter;

  // --- Model 2: Original TFLite (3-class: Relaxed/Neutral/Concentrating) ---
  Interpreter? _tfliteInterpreter;

  List<double>? _scalerMean;
  List<double>? _scalerScale;

  // --- PyTorch labels (Positive / Neutral / Negative) ---
  List<String>? _pytorchLabels;
  Map<String, String>? _pytorchIndexToLabel;

  // --- TFLite labels (Relaxed / Neutral / Concentrating) ---
  List<String>? _tfliteLabels;
  Map<String, String>? _tfliteIndexToLabel;

  bool _isModelLoaded = false;
  String? _lastError;

  bool get isModelLoaded => _isModelLoaded;
  String? get lastError => _lastError;

  static const int _numFeatures = 988;

  // PyTorch model input dimensions
  static const int _ptNumElectrodes = 32;
  static const int _ptNumBands = 5;

  Future<void> loadModel() async {
    try {
      // --- Load PyTorch-converted TFLite model ---
      try {
        _pytorchInterpreter = await Interpreter.fromAsset(
            'models/eeg_mobile_model_3classes.tflite');
        debugPrint('✅ PyTorch-converted TFLite model loaded successfully');
      } catch (e) {
        debugPrint('⚠️ PyTorch-converted model load failed: $e');
      }

      // --- Load original TFLite model ---
      try {
        _tfliteInterpreter =
            await Interpreter.fromAsset('models/emotion_model.tflite');
        debugPrint('✅ Original TFLite model loaded successfully');
      } catch (e) {
        debugPrint('⚠️ Original TFLite model load failed: $e');
      }

      await _loadScalerParams();

      await _loadPytorchLabels();
      await _loadTfliteLabels();

      _isModelLoaded =
          _pytorchInterpreter != null || _tfliteInterpreter != null;
      _lastError = null;
      debugPrint(
          '✅ Emotion Detection Service ready (PyTorch-TFLite: ${_pytorchInterpreter != null}, Original-TFLite: ${_tfliteInterpreter != null})');
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

  Future<void> _loadPytorchLabels() async {
    try {
      final jsonStr =
          await rootBundle.loadString('assets/models/pytorch_labels.json');
      final data = json.decode(jsonStr);
      _pytorchLabels = List<String>.from(data['classes']);
      _pytorchIndexToLabel =
          Map<String, String>.from(data['index_to_label']);
      debugPrint('✅ PyTorch labels loaded: $_pytorchLabels');
    } catch (e) {
      debugPrint('⚠️ PyTorch labels load failed: $e');
      _pytorchLabels = ['Positive', 'Neutral', 'Negative'];
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

  // =========================================================================
  // Feature generation for the ORIGINAL TFLite model (988 PSD features)
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
  // Feature generation for the PyTorch-converted model ([1, 32, 5])
  // Maps 5 EEG bands across 32 "virtual" electrodes using spatial variation
  // =========================================================================
  List<List<double>> _generatePytorchFeatures(Map<String, double> eegData) {
    double alpha = eegData['alpha'] ?? 0;
    double beta = eegData['beta'] ?? 0;
    double theta = eegData['theta'] ?? 0;
    double delta = eegData['delta'] ?? 0;
    double gamma = eegData['gamma'] ?? 0;

    // Create [32, 5] matrix: 32 electrodes × 5 frequency bands
    // Apply spatial variation across electrodes to simulate DEAP 32-channel layout
    List<List<double>> electrodeData = List.generate(_ptNumElectrodes, (elec) {
      // Spatial variation factor: different electrodes have slightly different readings
      double spatialFactor = 1.0 + (elec - 16.0) * 0.02;
      // Regional variation: frontal (0-7), temporal (8-15), parietal (16-23), occipital (24-31)
      double regionalAlpha = alpha;
      double regionalBeta = beta;
      double regionalTheta = theta;
      double regionalDelta = delta;
      double regionalGamma = gamma;

      if (elec < 8) {
        // Frontal: higher beta/gamma (cognitive)
        regionalBeta *= 1.15;
        regionalGamma *= 1.10;
      } else if (elec < 16) {
        // Temporal: balanced
        regionalAlpha *= 1.05;
      } else if (elec < 24) {
        // Parietal: higher alpha
        regionalAlpha *= 1.20;
        regionalTheta *= 1.10;
      } else {
        // Occipital: highest alpha (visual cortex)
        regionalAlpha *= 1.30;
        regionalDelta *= 1.15;
      }

      return [
        regionalDelta * spatialFactor,
        regionalTheta * spatialFactor,
        regionalAlpha * spatialFactor,
        regionalBeta * spatialFactor,
        regionalGamma * spatialFactor,
      ];
    });

    return electrodeData;
  }

  // =========================================================================
  // Main detection: runs both models
  // =========================================================================
  Future<Map<String, EmotionResult>> detectFromEEG(
      Map<String, double> eegData) async {
    EmotionResult pytorchResult;
    EmotionResult tfliteResult;

    try {
      if (_pytorchInterpreter != null) {
        pytorchResult = _predictWithPytorchTFLite(eegData);
      } else {
        pytorchResult = _fallbackPytorchDetection(eegData);
      }
    } catch (e) {
      debugPrint('❌ PyTorch-TFLite prediction error: $e');
      pytorchResult = _fallbackPytorchDetection(eegData);
    }

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

    return {
      'pytorch': pytorchResult,
      'tflite': tfliteResult,
    };
  }

  // =========================================================================
  // PyTorch-converted TFLite prediction (Input: [1, 1, 32, 5])
  // =========================================================================
  EmotionResult _predictWithPytorchTFLite(Map<String, double> eegData) {
    List<List<double>> electrodeFeatures = _generatePytorchFeatures(eegData);

    // Shape: [1, 1, 32, 5] → batch=1, channels=1, electrodes=32, bands=5
    var input = [
      [electrodeFeatures]
    ];

    var output = List.generate(1, (_) => List.filled(3, 0.0));

    _pytorchInterpreter!.run(input, output);

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

    String emotionLabel = _pytorchIndexToLabel?[bestIdx.toString()] ??
        (_pytorchLabels != null && bestIdx < _pytorchLabels!.length
            ? _pytorchLabels![bestIdx]
            : 'neutral');

    String mappedEmotion = _mapModelLabel(emotionLabel);

    Map<String, double> allScores = {};
    for (int i = 0; i < scores.length; i++) {
      String label = _pytorchIndexToLabel?[i.toString()] ??
          (_pytorchLabels != null && i < _pytorchLabels!.length
              ? _pytorchLabels![i]
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
      // === PyTorch model classes ===
      case 'positive':
        return 'positive';
      case 'negative':
        return 'negative';
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

  // =========================================================================
  // Fallback: PyTorch-style (Positive / Neutral / Negative)
  // =========================================================================
  EmotionResult _fallbackPytorchDetection(Map<String, double> eegData) {
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
    scores['positive'] =
        (aPct * 1.5 + tPct * 0.3 + (1 - bPct) * 0.5).clamp(0.0, 1.0);

    // Neutral: สมดุลทุก band → สภาวะปกติ
    double balance = 1.0 -
        ((aPct - 0.2).abs() + (bPct - 0.2).abs() + (tPct - 0.2).abs());
    scores['neutral'] = balance.clamp(0.0, 1.0);

    // Negative: Beta/Gamma สูง (ความเครียด) หรือ Delta/Theta สูง (ซึมเศร้า/ล้า)
    scores['negative'] =
        (bPct * 1.0 + tPct * 0.8 + gPct * 0.5).clamp(0.0, 1.0);

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
    _pytorchInterpreter?.close();
    _pytorchInterpreter = null;
    _tfliteInterpreter?.close();
    _tfliteInterpreter = null;
    _isModelLoaded = false;
  }
}
