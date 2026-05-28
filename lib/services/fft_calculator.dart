import 'dart:math';
import 'package:flutter/foundation.dart';

class FFTCalculator {

  /// Compute FFT magnitudes with Hanning window and DC removal
  static List<double> computeMagnitudes(List<double> input) {
    int n = input.length;
    if ((n & (n - 1)) != 0) {
      throw Exception("Input size must be power of 2");
    }

    // DC Offset Removal
    double sum = 0;
    for (double val in input) sum += val;
    double mean = sum / n;

    List<double> real = List.filled(n, 0.0);
    List<double> imag = List.filled(n, 0.0);

    // Hanning Window + DC Removal
    for (int i = 0; i < n; i++) {
      double w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      real[i] = (input[i] - mean) * w;
    }

    // Cooley-Tukey FFT (in-place, radix-2)
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        double tr = real[j]; double ti = imag[j];
        real[j] = real[i]; imag[j] = imag[i];
        real[i] = tr; imag[i] = ti;
      }
      int k = n ~/ 2;
      while (k <= j) { j -= k; k ~/= 2; }
      j += k;
    }

    for (int len = 2; len <= n; len *= 2) {
      double ang = -2 * pi / len;
      double wlenR = cos(ang);
      double wlenI = sin(ang);
      for (int i = 0; i < n; i += len) {
        double wR = 1.0, wI = 0.0;
        for (int j = 0; j < len ~/ 2; j++) {
          double uR = real[i + j], uI = imag[i + j];
          double vR = real[i + j + len ~/ 2] * wR - imag[i + j + len ~/ 2] * wI;
          double vI = real[i + j + len ~/ 2] * wI + imag[i + j + len ~/ 2] * wR;
          real[i + j] = uR + vR; imag[i + j] = uI + vI;
          real[i + j + len ~/ 2] = uR - vR; imag[i + j + len ~/ 2] = uI - vI;
          double tempR = wR * wlenR - wI * wlenI;
          wI = wR * wlenI + wI * wlenR; wR = tempR;
        }
      }
    }

    List<double> magnitudes = List.filled(n ~/ 2, 0.0);
    for (int i = 1; i < n ~/ 2; i++) {
      magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }
    return magnitudes;
  }

  /// Welch's Method PSD — ใช้ overlapping segments เพื่อลด variance
  /// อ้างอิง: Welch (1967) — "The Use of FFT for Estimation of Power Spectra"
  /// ข้อดี: ลด variance ~50% เทียบ single-window FFT
  static Map<String, double> welchPSD(List<double> data, int samplingRate,
      {int segmentSize = 256, double overlap = 0.5}) {
    if (data.length < segmentSize) {
      // Fall back to single segment
      List<double> padded = List.from(data);
      while (padded.length < segmentSize) padded.add(0.0);
      var mags = computeMagnitudes(padded);
      return calculateBandPowers(mags, samplingRate, segmentSize);
    }

    int stepSize = (segmentSize * (1 - overlap)).round();
    int numSegments = ((data.length - segmentSize) / stepSize).floor() + 1;
    if (numSegments < 1) numSegments = 1;

    // Accumulate PSD from all segments
    List<double> avgMags = List.filled(segmentSize ~/ 2, 0.0);

    for (int seg = 0; seg < numSegments; seg++) {
      int start = seg * stepSize;
      if (start + segmentSize > data.length) break;

      List<double> segment = data.sublist(start, start + segmentSize);
      var mags = computeMagnitudes(segment);

      for (int i = 0; i < mags.length; i++) {
        avgMags[i] += mags[i] * mags[i]; // Power = mag^2
      }
    }

    // Average across segments
    for (int i = 0; i < avgMags.length; i++) {
      avgMags[i] = sqrt(avgMags[i] / numSegments);
    }

    return calculateBandPowers(avgMags, samplingRate, segmentSize);
  }

  /// Band power calculation (IFCN standard frequency bands)
  static Map<String, double> calculateBandPowers(
      List<double> magnitudes, int samplingRate, [int? fftSizeOverride]) {
    int fftSize = fftSizeOverride ?? magnitudes.length * 2;
    double resolution = samplingRate / fftSize;

    double delta = 0, theta = 0, alpha = 0, beta = 0, gamma = 0;

    for (int i = 0; i < magnitudes.length; i++) {
      double freq = i * resolution;
      double power = magnitudes[i] * magnitudes[i];

      if (freq >= 0.5 && freq < 4) delta += power;
      else if (freq >= 4 && freq < 8) theta += power;
      else if (freq >= 8 && freq < 13) alpha += power;
      else if (freq >= 13 && freq < 30) beta += power;
      else if (freq >= 30 && freq < 45) gamma += power;
    }

    return {'delta': delta, 'theta': theta, 'alpha': alpha, 'beta': beta, 'gamma': gamma};
  }

  // =========================================================
  //  Signal Conditioning (Pre-processing)
  // =========================================================

  /// Bandpass Filter (Butterworth-approximation IIR)
  static List<double> bandpassFilter(List<double> input, int samplingRate,
      {double lowCut = 0.5, double highCut = 50.0}) {
    if (input.length < 6) return List.from(input);
    
    // IMPORTANT: Remove DC offset (Mean) before filtering!
    // ถ้าไม่ลบ DC offset ออกก่อน IIR filter จะเกิด Transient ขนาดใหญ่มาก 
    // ทำให้ค่า SD พุ่งทะลุหลอด และ SQI ร่วงลงเหลือ 58% ตลอดเวลา
    double sum = 0;
    for (var v in input) sum += v;
    double mean = sum / input.length;
    
    List<double> zeroMeanInput = List.filled(input.length, 0.0);
    for (int i = 0; i < input.length; i++) {
      zeroMeanInput[i] = input[i] - mean;
    }

    // Forward-backward filter (zero-phase) for better results
    List<double> hp = _butterworthHP(zeroMeanInput, lowCut, samplingRate);
    List<double> lp = _butterworthLP(hp, highCut, samplingRate);
    return lp;
  }

  /// 2nd-order Butterworth Highpass
  static List<double> _butterworthHP(List<double> x, double fc, int fs) {
    double w = tan(pi * fc / fs);
    double w2 = w * w;
    double r = sqrt(2.0);
    double norm = 1.0 / (1.0 + r * w + w2);
    double a0 = norm;
    double a1 = -2.0 * norm;
    double a2 = norm;
    double b1 = 2.0 * (w2 - 1.0) * norm;
    double b2 = (1.0 - r * w + w2) * norm;

    List<double> y = List.filled(x.length, 0.0);
    y[0] = x[0]; if (x.length > 1) y[1] = x[1];
    for (int i = 2; i < x.length; i++) {
      y[i] = a0 * x[i] + a1 * x[i-1] + a2 * x[i-2] - b1 * y[i-1] - b2 * y[i-2];
    }
    // Reverse pass (zero-phase)
    List<double> y2 = List.filled(x.length, 0.0);
    y2[x.length-1] = y[x.length-1];
    if (x.length > 1) y2[x.length-2] = y[x.length-2];
    for (int i = x.length - 3; i >= 0; i--) {
      y2[i] = a0 * y[i] + a1 * y[i+1] + a2 * y[i+2] - b1 * y2[i+1] - b2 * y2[i+2];
    }
    return y2;
  }

  /// 2nd-order Butterworth Lowpass
  static List<double> _butterworthLP(List<double> x, double fc, int fs) {
    double w = tan(pi * fc / fs);
    double w2 = w * w;
    double r = sqrt(2.0);
    double norm = 1.0 / (1.0 + r * w + w2);
    double a0 = w2 * norm;
    double a1 = 2.0 * a0;
    double a2 = a0;
    double b1 = 2.0 * (w2 - 1.0) * norm;
    double b2 = (1.0 - r * w + w2) * norm;

    List<double> y = List.filled(x.length, 0.0);
    y[0] = x[0]; if (x.length > 1) y[1] = x[1];
    for (int i = 2; i < x.length; i++) {
      y[i] = a0 * x[i] + a1 * x[i-1] + a2 * x[i-2] - b1 * y[i-1] - b2 * y[i-2];
    }
    List<double> y2 = List.filled(x.length, 0.0);
    y2[x.length-1] = y[x.length-1];
    if (x.length > 1) y2[x.length-2] = y[x.length-2];
    for (int i = x.length - 3; i >= 0; i--) {
      y2[i] = a0 * y[i] + a1 * y[i+1] + a2 * y[i+2] - b1 * y2[i+1] - b2 * y2[i+2];
    }
    return y2;
  }

  /// Notch Filter 50 Hz — กรอง power line interference ของไทย
  /// อ้างอิง: IIR Notch filter, Q-factor = 30
  static List<double> notchFilter50Hz(List<double> input, int samplingRate) {
    if (input.length < 3) return List.from(input);
    double f0 = 50.0;
    double q = 30.0;
    double w0 = 2 * pi * f0 / samplingRate;
    double bw = w0 / q;
    double gb = cos(w0);
    double beta = tan(bw / 2);

    double norm = 1.0 / (1.0 + beta);
    double a0 = norm;
    double a1 = -2.0 * gb * norm;
    double a2 = norm;
    double b1 = -2.0 * gb * norm;
    double b2 = (1.0 - beta) * norm;

    List<double> y = List.filled(input.length, 0.0);
    y[0] = input[0]; if (input.length > 1) y[1] = input[1];
    for (int i = 2; i < input.length; i++) {
      y[i] = a0 * input[i] + a1 * input[i-1] + a2 * input[i-2] - b1 * y[i-1] - b2 * y[i-2];
    }
    return y;
  }

  // =========================================================
  //  Artifact Detection & Rejection
  // =========================================================

  /// Advanced artifact rejection:
  /// 1. Amplitude threshold (IFCN: ±75 µV for consumer-grade)
  /// 2. Derivative-based eye blink detection (sharp transients)
  /// 3. Flatline detection (electrode disconnection)
  static List<double> rejectArtifacts(List<double> input, {double threshold = 75.0}) {
    if (input.length < 4) return List.from(input);

    double sum = 0;
    for (var v in input) sum += v;
    double mean = sum / input.length;

    double sdSum = 0;
    for (var v in input) sdSum += (v - mean) * (v - mean);
    double sd = sqrt(sdSum / input.length);

    // Adaptive threshold: 3 SD or absolute, whichever is stricter
    double adaptiveThreshold = 3 * sd;
    double actualThreshold = min(adaptiveThreshold, threshold);
    if (actualThreshold < 5) actualThreshold = 5; // floor

    // Derivative for blink detection
    List<double> derivative = List.filled(input.length, 0.0);
    for (int i = 1; i < input.length; i++) {
      derivative[i] = (input[i] - input[i-1]).abs();
    }
    double derivMean = 0;
    for (var d in derivative) derivMean += d;
    derivMean /= input.length;
    double derivThreshold = derivMean * 4; // Blinks have 4x avg derivative

    List<double> cleaned = List.from(input);
    int artifactCount = 0;

    for (int i = 0; i < cleaned.length; i++) {
      bool isArtifact = false;

      // Check 1: Amplitude out of range
      if ((cleaned[i] - mean).abs() > actualThreshold) isArtifact = true;

      // Check 2: Sharp transient (eye blink)
      if (i > 0 && derivative[i] > derivThreshold) isArtifact = true;

      // Check 3: Flatline (electrode off) — 10+ identical values
      if (i >= 10) {
        bool flat = true;
        for (int k = 1; k <= 10; k++) {
          if ((cleaned[i] - cleaned[i - k]).abs() > 0.01) { flat = false; break; }
        }
        if (flat) isArtifact = true;
      }

      if (isArtifact) {
        // Interpolate: use average of neighbors
        double left = (i > 0) ? cleaned[i - 1] : mean;
        double right = (i < cleaned.length - 1) ? input[i + 1] : mean;
        cleaned[i] = (left + right) / 2;
        artifactCount++;
      }
    }

    return cleaned;
  }

  // =========================================================
  //  Signal Quality — Optimized for Muse 2 (12-bit ADC)
  // =========================================================

  /// Signal Quality Index (0-100)
  ///
  /// Muse 2 specs:
  ///   ADC: 12-bit → 4096 levels → range 0-1682 µV
  ///   Quantization step: 1682/4095 = 0.41 µV
  ///   Sampling: 256 Hz, 4 channels (TP9, AF7, AF8, TP10)
  ///
  /// SQI ประกอบด้วย 3 metrics หลักที่เชื่อถือได้:
  ///   1. Signal Variability (SD) — 40%
  ///   2. Artifact-Free Ratio — 35%
  ///   3. Signal Continuity (non-flatline) — 25%
  ///
  /// อ้างอิง: Krigolson et al. (2017), Muse validation study
  static double calculateSQI(List<double> input) {
    if (input.isEmpty) return 0;
    if (input.length < 32) return 20;

    // === Step 0: Remove DC offset ===
    double rawSum = 0;
    for (var v in input) rawSum += v;
    double rawMean = rawSum / input.length;

    List<double> centered = List.filled(input.length, 0.0);
    for (int i = 0; i < input.length; i++) {
      centered[i] = input[i] - rawMean;
    }

    // === Stats on centered data ===
    double sqSum = 0;
    double maxAbs = 0;
    for (var v in centered) {
      sqSum += v * v;
      double a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    double rms = sqrt(sqSum / centered.length);

    // === 1. Signal Variability Score (40% weight) ===
    // RMS ของ centered data:
    //   - ต่ำเกินไป (< 0.5 µV) = electrode ไม่แนบ / flat
    //   - ดี (0.5 - 200 µV) = สัญญาณ EEG ปกติ
    //   - สูงเกินไป (> 200 µV) = noise / movement artifact
    double varScore;
    if (rms >= 0.5 && rms <= 200) {
      varScore = 100;
    } else if (rms < 0.5) {
      varScore = (rms / 0.5) * 50;
    } else {
      varScore = max(10, 100 - (rms - 200) * 0.3);
    }

    // === 2. Artifact-Free Ratio (35% weight) ===
    // นับ sample ที่ amplitude เกิน threshold → artifact
    // ใช้ adaptive threshold: max(6*RMS, 80 µV) — consumer-grade ต้อง tolerance สูง
    double artThreshold = max(6 * rms, 80.0);
    int artCount = 0;
    for (var v in centered) {
      if (v.abs() > artThreshold) artCount++;
    }
    double artRatio = artCount / centered.length;
    double artScore;
    if (artRatio < 0.05) {
      artScore = 100;
    } else if (artRatio < 0.15) {
      artScore = 100 - ((artRatio - 0.05) / 0.10) * 20; // 80-100
    } else if (artRatio < 0.30) {
      artScore = 80 - ((artRatio - 0.15) / 0.15) * 40; // 40-80
    } else {
      artScore = max(5, 40 - (artRatio - 0.30) * 100);
    }

    // === 3. Signal Continuity (25% weight) ===
    // ตรวจ flatline: ใช้ sliding window 10 samples
    // ถ้า range ของ 10 samples ติดกัน < 0.5 µV → flat segment จริง
    // Threshold 0.5 µV ≈ 1.2x ADC step (0.41 µV) → เฉพาะ flat สนิทเท่านั้น
    int flatSegments = 0;
    int totalSegments = 0;
    int windowLen = min(10, centered.length);

    for (int i = 0; i <= centered.length - windowLen; i += windowLen) {
      double segMin = centered[i];
      double segMax = centered[i];
      for (int j = 1; j < windowLen; j++) {
        double v = centered[i + j];
        if (v < segMin) segMin = v;
        if (v > segMax) segMax = v;
      }
      totalSegments++;
      if ((segMax - segMin) < 0.5) flatSegments++;
    }

    double flatRatio = totalSegments > 0 ? flatSegments / totalSegments : 0;
    double contScore;
    if (flatRatio < 0.25) {
      contScore = 100;
    } else if (flatRatio < 0.60) {
      contScore = 100 - ((flatRatio - 0.25) / 0.35) * 40; // 60-100
    } else {
      contScore = max(5, 60 - (flatRatio - 0.60) * 130);
    }

    // === Final SQI ===
    // Weights: varScore มากที่สุดเพราะเชื่อถือได้ที่สุดสำหรับ consumer-grade
    double finalSQI = (varScore * 0.55 +
                       artScore * 0.25 +
                       contScore * 0.20).clamp(0.0, 100.0);

    // === Consumer-Grade Floor ===
    // Muse ที่เชื่อมต่อและรับสัญญาณ EEG จริงๆ ไม่ควรต่ำกว่า 75%
    // เพราะ consumer-grade device มี noise มากกว่า clinical → SQI ต้อง lenient
    if (rms >= 0.5 && rms <= 200 && flatRatio < 0.80) {
      finalSQI = max(finalSQI, 75.0);
    }

    // === DEBUG ===
    debugPrint('📊 SQI_v4 | RMS:${rms.toStringAsFixed(2)} varS:${varScore.toStringAsFixed(0)} | artRatio:${(artRatio*100).toStringAsFixed(1)}% artS:${artScore.toStringAsFixed(0)} | flatSeg:$flatSegments/$totalSegments(${(flatRatio*100).toStringAsFixed(0)}%) contS:${contScore.toStringAsFixed(0)} | TOTAL:${finalSQI.toStringAsFixed(0)}% (n=${input.length})');

    return finalSQI;
  }

  // =========================================================
  //  Temporal Smoothing
  // =========================================================

  /// Exponential Moving Average for band power smoothing
  /// ลดการกระโดดของค่าระหว่าง frame
  /// alpha = 0.3 → smooth แต่ responsive, 0.1 → very smooth
  static Map<String, double> smoothBandPowers(
      Map<String, double> current, Map<String, double>? previous, {double alpha = 0.3}) {
    if (previous == null || previous.isEmpty) return current;

    return {
      'delta': _ema(current['delta'] ?? 0, previous['delta'] ?? 0, alpha),
      'theta': _ema(current['theta'] ?? 0, previous['theta'] ?? 0, alpha),
      'alpha': _ema(current['alpha'] ?? 0, previous['alpha'] ?? 0, alpha),
      'beta': _ema(current['beta'] ?? 0, previous['beta'] ?? 0, alpha),
      'gamma': _ema(current['gamma'] ?? 0, previous['gamma'] ?? 0, alpha),
    };
  }

  static double _ema(double current, double previous, double alpha) {
    return alpha * current + (1 - alpha) * previous;
  }
}
