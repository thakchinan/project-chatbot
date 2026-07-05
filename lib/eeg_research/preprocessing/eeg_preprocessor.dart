import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/eeg_sample.dart';
import 'ica_artifact_removal.dart';

/// Research-Grade EEG Preprocessor
///
/// Pipeline สมบูรณ์สำหรับ preprocessing สัญญาณ EEG:
/// 1. DC offset removal / detrend
/// 2. Band-pass filter: 1-45 Hz (4th-order Butterworth, zero-phase)
/// 3. Notch filter: 50/60 Hz (configurable per country)
/// 4. Artifact detection & rejection:
///    - Eye blink (AF7/AF8 amplitude threshold)
///    - Jaw clench (high-frequency power >30 Hz)
///    - Movement (sudden RMS change across all channels)
///    - Bad electrode (flatline detection)
/// 5. ICA-based artifact removal (regression-based)
/// 6. Clean segment extraction
///
/// อ้างอิง:
/// - IFCN Standards for EEG Recording (2017)
/// - Krigolson et al. (2017) Muse validation study
/// - Fatourechi et al. (2007) EMG artifacts in EEG
class EegPreprocessor {
  /// Sampling rate (Hz)
  final int samplingRate;

  /// Bandpass filter low cutoff (Hz) — 1 Hz ดีกว่า 0.5 Hz สำหรับ movement rejection
  final double bandpassLow;

  /// Bandpass filter high cutoff (Hz)
  final double bandpassHigh;

  /// Notch filter frequency (Hz) — 50 Hz (Asia/Europe) or 60 Hz (US/Japan)
  final double notchFrequency;

  /// Artifact amplitude threshold (µV)
  final double artifactThreshold;

  /// Enable ICA-based artifact removal
  final bool enableICA;

  /// ICA artifact remover instance
  late final IcaArtifactRemoval _ica;

  EegPreprocessor({
    this.samplingRate = 256,
    this.bandpassLow = 1.0,
    this.bandpassHigh = 45.0,
    this.notchFrequency = 50.0,
    this.artifactThreshold = 100.0,
    this.enableICA = true,
  }) {
    _ica = IcaArtifactRemoval(samplingRate: samplingRate);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Full Pipeline
  // ═══════════════════════════════════════════════════════════════

  /// ประมวลผล preprocessing ทั้ง pipeline สำหรับ 4 ช่อง
  ///
  /// Input: raw per-channel data {TP9: [...], AF7: [...], AF8: [...], TP10: [...]}
  /// Output: EegFrame ที่ clean พร้อมใช้ FFT
  EegFrame process(Map<String, List<double>> rawChannels) {
    final result = <String, List<double>>{};
    final artifactMask = <String, List<bool>>{};
    final artifactRate = <String, double>{};

    for (final entry in rawChannels.entries) {
      final channel = entry.key;
      var data = List<double>.from(entry.value);

      if (data.length < 6) {
        result[channel] = data;
        artifactMask[channel] = List.filled(data.length, false);
        artifactRate[channel] = 0;
        continue;
      }

      // Step 1: DC offset removal (detrend)
      data = removeDCOffset(data);

      // Step 2: 4th-order Butterworth band-pass (1-45 Hz)
      data = bandpassFilter(data);

      // Step 3: Notch filter (50/60 Hz)
      data = notchFilter(data);

      // Step 4: Detect artifacts
      final mask = detectArtifacts(data, channel);
      artifactMask[channel] = mask;
      artifactRate[channel] =
          mask.where((m) => m).length / mask.length;

      // Step 5: Interpolate artifact regions
      data = interpolateArtifacts(data, mask);

      result[channel] = data;
    }

    // Step 6: ICA-based blink removal (cross-channel)
    if (enableICA &&
        result.containsKey('AF7') &&
        result.containsKey('AF8') &&
        result.containsKey('TP9') &&
        result.containsKey('TP10')) {
      try {
        final icaResult = _ica.removeBlinkArtifact(result);
        for (final key in icaResult.keys) {
          result[key] = icaResult[key]!;
        }
      } catch (e) {
        debugPrint('⚠️ ICA artifact removal skipped: $e');
      }
    }

    return EegFrame(
      channels: result,
      frameSize: result.values.first.length,
      samplingRate: samplingRate,
      startTime: DateTime.now(),
      artifactMask: artifactMask,
      artifactRate: artifactRate,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. DC Offset Removal / Detrend
  // ═══════════════════════════════════════════════════════════════

  /// ลบ DC offset (mean subtraction) + optional linear detrend
  ///
  /// สำคัญ: ต้องทำ BEFORE filtering เพื่อลด IIR transient
  /// ถ้าไม่ลบ DC → filter จะ ring อย่างหนักใน samples แรก
  List<double> removeDCOffset(List<double> data,
      {bool linearDetrend = true}) {
    final n = data.length;
    if (n < 2) return List.from(data);

    if (!linearDetrend) {
      // Simple mean subtraction
      double sum = 0;
      for (final v in data) {
        sum += v;
      }
      final mean = sum / n;
      return List.generate(n, (i) => data[i] - mean);
    }

    // Linear detrend: fit y = ax + b, then subtract
    // Using least-squares: a = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    double sx = 0, sy = 0, sxy = 0, sx2 = 0;
    for (int i = 0; i < n; i++) {
      sx += i;
      sy += data[i];
      sxy += i * data[i];
      sx2 += i * i;
    }

    final denom = n * sx2 - sx * sx;
    if (denom.abs() < 1e-10) {
      // Degenerate case: just subtract mean
      final mean = sy / n;
      return List.generate(n, (i) => data[i] - mean);
    }

    final a = (n * sxy - sx * sy) / denom;
    final b = (sy - a * sx) / n;

    return List.generate(n, (i) => data[i] - (a * i + b));
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. Band-pass Filter (4th-order Butterworth)
  // ═══════════════════════════════════════════════════════════════

  /// 4th-order Butterworth band-pass filter (zero-phase)
  ///
  /// Implemented as cascade of two 2nd-order sections (SOS)
  /// → 4th-order total → -24 dB/octave rolloff
  /// → ดีกว่า 2nd-order (-12 dB/octave) ของเดิมมาก
  ///
  /// Zero-phase: forward + backward pass ทำให้ไม่เกิด phase distortion
  List<double> bandpassFilter(List<double> data) {
    if (data.length < 8) return List.from(data);

    // High-pass (remove <1 Hz)
    var filtered = _butterworth2ndHP(data, bandpassLow, samplingRate);
    filtered = _butterworth2ndHP(filtered, bandpassLow, samplingRate); // 2x = 4th order

    // Low-pass (remove >45 Hz)
    filtered = _butterworth2ndLP(filtered, bandpassHigh, samplingRate);
    filtered = _butterworth2ndLP(filtered, bandpassHigh, samplingRate); // 2x = 4th order

    return filtered;
  }

  /// 2nd-order Butterworth High-pass (zero-phase forward-backward)
  static List<double> _butterworth2ndHP(
      List<double> x, double fc, int fs) {
    final w = tan(pi * fc / fs);
    final w2 = w * w;
    final r = sqrt(2.0);
    final norm = 1.0 / (1.0 + r * w + w2);
    final a0 = norm;
    final a1 = -2.0 * norm;
    final a2 = norm;
    final b1 = 2.0 * (w2 - 1.0) * norm;
    final b2 = (1.0 - r * w + w2) * norm;

    return _filtfilt(x, a0, a1, a2, b1, b2);
  }

  /// 2nd-order Butterworth Low-pass (zero-phase forward-backward)
  static List<double> _butterworth2ndLP(
      List<double> x, double fc, int fs) {
    final w = tan(pi * fc / fs);
    final w2 = w * w;
    final r = sqrt(2.0);
    final norm = 1.0 / (1.0 + r * w + w2);
    final a0 = w2 * norm;
    final a1 = 2.0 * a0;
    final a2 = a0;
    final b1 = 2.0 * (w2 - 1.0) * norm;
    final b2 = (1.0 - r * w + w2) * norm;

    return _filtfilt(x, a0, a1, a2, b1, b2);
  }

  /// Zero-phase filtering: forward pass + backward pass
  /// → eliminates phase distortion from IIR filter
  static List<double> _filtfilt(
      List<double> x, double a0, double a1, double a2,
      double b1, double b2) {
    final n = x.length;
    if (n < 3) return List.from(x);

    // Forward pass
    final y = List<double>.filled(n, 0.0);
    y[0] = a0 * x[0];
    y[1] = a0 * x[1] + a1 * x[0] - b1 * y[0];
    for (int i = 2; i < n; i++) {
      y[i] = a0 * x[i] + a1 * x[i - 1] + a2 * x[i - 2] -
          b1 * y[i - 1] - b2 * y[i - 2];
    }

    // Backward pass (zero-phase)
    final y2 = List<double>.filled(n, 0.0);
    y2[n - 1] = a0 * y[n - 1];
    if (n > 1) {
      y2[n - 2] = a0 * y[n - 2] + a1 * y[n - 1] - b1 * y2[n - 1];
    }
    for (int i = n - 3; i >= 0; i--) {
      y2[i] = a0 * y[i] + a1 * y[i + 1] + a2 * y[i + 2] -
          b1 * y2[i + 1] - b2 * y2[i + 2];
    }

    return y2;
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. Notch Filter (50/60 Hz)
  // ═══════════════════════════════════════════════════════════════

  /// IIR Notch filter สำหรับกรอง power line interference
  ///
  /// Q = 30 → narrow notch ที่ notchFrequency ± ~1.7 Hz
  /// ไม่กระทบ EEG band ข้างเคียง (45 Hz gamma)
  List<double> notchFilter(List<double> data) {
    if (data.length < 3) return List.from(data);
    final f0 = notchFrequency;
    final q = 30.0;
    final w0 = 2 * pi * f0 / samplingRate;
    final bw = w0 / q;
    final gb = cos(w0);
    final beta = tan(bw / 2);

    final norm = 1.0 / (1.0 + beta);
    final a0 = norm;
    final a1 = -2.0 * gb * norm;
    final a2 = norm;
    final b1 = -2.0 * gb * norm;
    final b2 = (1.0 - beta) * norm;

    // Forward-backward for zero-phase
    return _filtfilt(data, a0, a1, a2, b1, b2);
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. Artifact Detection
  // ═══════════════════════════════════════════════════════════════

  /// ตรวจจับ artifact ใน single channel
  ///
  /// Returns: boolean mask (true = artifact at that index)
  List<bool> detectArtifacts(List<double> data, String channel) {
    final n = data.length;
    final mask = List<bool>.filled(n, false);
    if (n < 10) return mask;

    // Stats
    double sum = 0, sqSum = 0;
    for (final v in data) {
      sum += v;
      sqSum += v * v;
    }
    final mean = sum / n;
    final sd = sqrt(sqSum / n - mean * mean);

    // Adaptive threshold: min(3*SD, artifactThreshold)
    final ampThreshold = min(3 * sd, artifactThreshold);
    final safeThreshold = max(ampThreshold, 5.0); // floor 5 µV

    // === Check 1: Amplitude threshold ===
    for (int i = 0; i < n; i++) {
      if ((data[i] - mean).abs() > safeThreshold) {
        mask[i] = true;
      }
    }

    // === Check 2: Eye blink (AF7/AF8 sharp transient) ===
    if (channel == 'AF7' || channel == 'AF8') {
      // Derivative-based blink detection
      final derivThreshold = sd * 4;
      for (int i = 1; i < n; i++) {
        final deriv = (data[i] - data[i - 1]).abs();
        if (deriv > derivThreshold) {
          // Mark blink region ±50ms (13 samples @ 256 Hz)
          final blinkRadius = (samplingRate * 0.05).round();
          for (int j = max(0, i - blinkRadius);
              j < min(n, i + blinkRadius);
              j++) {
            mask[j] = true;
          }
        }
      }
    }

    // === Check 3: Jaw clench (high-frequency power spike) ===
    // High-frequency content (>30 Hz) that is unusually strong
    // indicates EMG contamination from jaw muscles
    if (n >= 64) {
      final windowSize = 64;
      for (int start = 0; start + windowSize <= n;
          start += windowSize ~/ 2) {
        double hfPower = 0;
        double totalPower = 0;
        // Simple high-frequency estimate: sum of abs(diff)
        for (int i = start + 1;
            i < start + windowSize && i < n;
            i++) {
          final diff = (data[i] - data[i - 1]).abs();
          hfPower += diff * diff;
          totalPower += data[i] * data[i];
        }
        // If high-frequency ratio > 0.5, likely jaw clench
        if (totalPower > 0 && hfPower / totalPower > 0.5) {
          for (int i = start;
              i < start + windowSize && i < n;
              i++) {
            mask[i] = true;
          }
        }
      }
    }

    // === Check 4: Flatline (electrode disconnection) ===
    // 10+ consecutive identical values
    int flatCount = 0;
    for (int i = 1; i < n; i++) {
      if ((data[i] - data[i - 1]).abs() < 0.01) {
        flatCount++;
        if (flatCount >= 10) {
          for (int j = i - flatCount; j <= i; j++) {
            if (j >= 0) mask[j] = true;
          }
        }
      } else {
        flatCount = 0;
      }
    }

    // === Check 5: Movement artifact (sudden global RMS change) ===
    // ตรวจจับโดยเปรียบเทียบ RMS ของ window ที่ติดกัน
    final rmsWindow = 32; // 125ms @ 256 Hz
    if (n >= rmsWindow * 2) {
      double prevRms = 0;
      for (int i = 0; i < rmsWindow; i++) {
        prevRms += data[i] * data[i];
      }
      prevRms = sqrt(prevRms / rmsWindow);

      for (int start = rmsWindow;
          start + rmsWindow <= n;
          start += rmsWindow) {
        double curRms = 0;
        for (int i = start; i < start + rmsWindow; i++) {
          curRms += data[i] * data[i];
        }
        curRms = sqrt(curRms / rmsWindow);

        // RMS change > 3x → movement artifact
        if (prevRms > 0 && curRms / prevRms > 3.0) {
          for (int i = start; i < start + rmsWindow; i++) {
            mask[i] = true;
          }
        }
        prevRms = curRms;
      }
    }

    return mask;
  }

  // ═══════════════════════════════════════════════════════════════
  //  5. Artifact Interpolation
  // ═══════════════════════════════════════════════════════════════

  /// แทนที่จุด artifact ด้วย linear interpolation จากจุดข้างเคียงที่ดี
  List<double> interpolateArtifacts(
      List<double> data, List<bool> mask) {
    final cleaned = List<double>.from(data);
    final n = data.length;

    for (int i = 0; i < n; i++) {
      if (!mask[i]) continue;

      // Find nearest clean samples on both sides
      int left = i - 1;
      while (left >= 0 && mask[left]) {
        left--;
      }

      int right = i + 1;
      while (right < n && mask[right]) {
        right++;
      }

      if (left >= 0 && right < n) {
        // Linear interpolation
        final t = (i - left) / (right - left);
        cleaned[i] =
            cleaned[left] + (data[right] - cleaned[left]) * t;
      } else if (left >= 0) {
        cleaned[i] = cleaned[left];
      } else if (right < n) {
        cleaned[i] = data[right];
      } else {
        cleaned[i] = 0; // All neighbors are artifacts
      }
    }

    return cleaned;
  }

  // ═══════════════════════════════════════════════════════════════
  //  6. Clean Segment Extraction
  // ═══════════════════════════════════════════════════════════════

  /// Extract clean segments (artifact rate < maxArtifactRate)
  ///
  /// Returns: list of start indices + lengths of clean segments
  List<Map<String, int>> findCleanSegments(
      List<bool> mask,
      {int minLength = 128, double maxArtifactRate = 0.10}) {
    final segments = <Map<String, int>>[];
    final n = mask.length;

    int start = 0;
    while (start < n) {
      // Find start of clean region
      while (start < n && mask[start]) {
        start++;
      }
      if (start >= n) break;

      // Find end of clean region
      int end = start;
      int artifactCount = 0;
      while (end < n) {
        if (mask[end]) artifactCount++;
        final length = end - start + 1;
        if (artifactCount / length > maxArtifactRate && length > minLength) {
          break;
        }
        end++;
      }

      final length = end - start;
      if (length >= minLength) {
        segments.add({'start': start, 'length': length});
      }
      start = end + 1;
    }

    return segments;
  }
}
