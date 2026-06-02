import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/quality_metrics.dart';
import '../spectral/eeg_fft_engine.dart';

/// Real-time EEG Quality Monitor
///
/// ทำหน้าที่ตรวจสอบคุณภาพสัญญาณแบบ real-time:
/// 1. SNR (Signal-to-Noise Ratio) แยกแต่ละช่อง
/// 2. PSD Stability (variance ของ PSD ใน window 10-30 วินาที)
/// 3. Artifact Rate (% ของ frames ที่มี artifact)
/// 4. Contact Quality (electrode contact indicator)
/// 5. Research-Grade Equivalence Score (0-100)
///
/// Thresholds (ตาม literature):
/// - SNR: >10 dB = ดี, 5-10 dB = พอใช้, <5 dB = แย่
/// - Artifact rate: <10% = ดี, 10-30% = พอใช้, >30% = แย่
/// - Contact: based on RMS level + flatline detection
///
/// อ้างอิง:
/// - IFCN Standards for Digital EEG Recording (2017)
/// - Krigolson et al. (2017) Muse validation study
class EegQualityMonitor {
  final int samplingRate;

  /// FFT engine สำหรับ spectral analysis
  late final EegFftEngine _fftEngine;

  /// History of quality measurements (for trend analysis)
  final List<OverallQuality> _qualityHistory = [];

  /// PSD history per channel (for stability calculation)
  final Map<String, List<List<double>>> _psdHistory = {
    'TP9': [],
    'AF7': [],
    'AF8': [],
    'TP10': [],
  };

  /// Maximum history length (seconds)
  static const int _maxHistorySeconds = 60;

  /// PSD stability window (seconds)
  final int psdStabilityWindow;

  EegQualityMonitor({
    this.samplingRate = 256,
    this.psdStabilityWindow = 15,
  }) {
    _fftEngine = EegFftEngine(
      samplingRate: samplingRate,
      frameSize: 256,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Main Quality Assessment
  // ═══════════════════════════════════════════════════════════════

  /// คำนวณ quality metrics ทั้งหมดจาก per-channel data
  OverallQuality assess(Map<String, List<double>> channels) {
    final channelQualities = <String, ChannelQuality>{};
    double totalSnr = 0;
    double totalArtifactRate = 0;
    int goodContacts = 0;
    int channelCount = 0;

    for (final entry in channels.entries) {
      final name = entry.key;
      final data = entry.value;

      if (data.length < 64) {
        channelQualities[name] = ChannelQuality(
          channelName: name,
          contactQuality: QualityLevel.noData,
          isDisconnected: true,
        );
        continue;
      }

      // 1. Compute SNR
      final snr = computeSnr(data);

      // 2. Compute artifact rate
      final artRate = computeArtifactRate(data);

      // 3. Check contact quality
      final rms = _computeRms(data);
      final contact = _assessContact(data, rms);
      final disconnected = contact == QualityLevel.poor && rms < 0.5;

      if (contact != QualityLevel.poor) goodContacts++;

      final cq = ChannelQuality(
        channelName: name,
        snrDb: snr,
        artifactRate: artRate,
        contactQuality: contact,
        rmsAmplitude: rms,
        isDisconnected: disconnected,
      );

      channelQualities[name] = cq;
      totalSnr += snr;
      totalArtifactRate += artRate;
      channelCount++;

      // 4. Update PSD history
      _updatePsdHistory(name, data);
    }

    final avgSnr = channelCount > 0 ? totalSnr / channelCount : 0.0;
    final avgArtRate =
        channelCount > 0 ? totalArtifactRate / channelCount : 1.0;

    // 5. PSD Stability
    final psdStab = computePsdStability();

    // 6. Research-Grade Score
    final researchScore = _computeResearchScore(
      avgSnr: avgSnr,
      artifactRate: avgArtRate,
      psdStability: psdStab,
      goodContacts: goodContacts,
    );

    final quality = OverallQuality(
      channels: channelQualities,
      avgSnrDb: avgSnr,
      overallArtifactRate: avgArtRate,
      psdStability: psdStab,
      goodContactCount: goodContacts,
      researchScore: researchScore,
      timestamp: DateTime.now(),
    );

    // Save to history
    _qualityHistory.add(quality);
    if (_qualityHistory.length > _maxHistorySeconds) {
      _qualityHistory.removeAt(0);
    }

    return quality;
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. Signal-to-Noise Ratio (SNR)
  // ═══════════════════════════════════════════════════════════════

  /// Compute SNR in dB
  ///
  /// SNR = 10 × log10(signal_power / noise_power)
  /// Signal: band-passed 1-45 Hz power
  /// Noise: out-of-band power (>50 Hz) + low-frequency drift (<1 Hz)
  double computeSnr(List<double> data) {
    if (data.length < 256) return 0;

    // Use FFT to separate in-band vs out-of-band power
    final psd = _fftEngine.welchPSD(data);
    final freqRes = _fftEngine.frequencyResolution;

    double signalPower = 0; // 1-45 Hz
    double noisePower = 0; // <1 Hz + >45 Hz

    for (int i = 0; i < psd.length; i++) {
      final freq = i * freqRes;
      if (freq >= 1.0 && freq <= 45.0) {
        signalPower += psd[i];
      } else {
        noisePower += psd[i];
      }
    }

    if (noisePower <= 0) return 30.0; // Essentially no noise
    if (signalPower <= 0) return 0;

    return 10 * log(signalPower / noisePower) / ln10;
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. Artifact Rate
  // ═══════════════════════════════════════════════════════════════

  /// Compute artifact rate (0.0-1.0)
  ///
  /// ตรวจจับ artifact จาก:
  /// - Amplitude > 100 µV (absolute)
  /// - Amplitude > 3*SD (adaptive)
  /// - Flatline segments
  double computeArtifactRate(List<double> data) {
    if (data.length < 10) return 0;

    // Stats
    double sum = 0, sqSum = 0;
    for (final v in data) {
      sum += v;
      sqSum += v * v;
    }
    final mean = sum / data.length;
    final sd = sqrt(sqSum / data.length - mean * mean);

    final threshold = min(3 * sd, 100.0);
    final safeThreshold = max(threshold, 5.0);

    int artifactCount = 0;

    for (int i = 0; i < data.length; i++) {
      // Amplitude check
      if ((data[i] - mean).abs() > safeThreshold) {
        artifactCount++;
        continue;
      }

      // Flatline check (5+ identical values)
      if (i >= 5) {
        bool flat = true;
        for (int k = 1; k <= 5; k++) {
          if ((data[i] - data[i - k]).abs() > 0.01) {
            flat = false;
            break;
          }
        }
        if (flat) artifactCount++;
      }
    }

    return artifactCount / data.length;
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. Contact Quality
  // ═══════════════════════════════════════════════════════════════

  QualityLevel _assessContact(List<double> data, double rms) {
    // Very low RMS → likely disconnected
    if (rms < 0.3) return QualityLevel.poor;

    // Very high RMS → saturated/artifact
    if (rms > 500) return QualityLevel.poor;

    // Check flatline ratio
    int flatCount = 0;
    for (int i = 1; i < data.length; i++) {
      if ((data[i] - data[i - 1]).abs() < 0.01) flatCount++;
    }
    final flatRatio = flatCount / data.length;
    if (flatRatio > 0.5) return QualityLevel.poor;
    if (flatRatio > 0.2) return QualityLevel.fair;

    // Normal range EEG: RMS 1-100 µV
    if (rms >= 1 && rms <= 100) return QualityLevel.good;
    if (rms < 1 || rms > 200) return QualityLevel.fair;

    return QualityLevel.good;
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. PSD Stability
  // ═══════════════════════════════════════════════════════════════

  void _updatePsdHistory(String channel, List<double> data) {
    if (data.length < 256) return;

    final psd = _fftEngine.welchPSD(data);
    final history = _psdHistory[channel];
    if (history == null) return;

    history.add(psd);

    // Keep only recent history
    final maxEntries = psdStabilityWindow;
    if (history.length > maxEntries) {
      history.removeRange(0, history.length - maxEntries);
    }
  }

  /// PSD Stability Score (0-100)
  ///
  /// ยิ่งสูง = PSD spectrum คงที่ระหว่าง frames = สัญญาณเสถียร
  /// คำนวณจาก coefficient of variation (CV) ของ band powers
  double computePsdStability() {
    double totalCv = 0;
    int bandCount = 0;

    for (final entry in _psdHistory.entries) {
      final history = entry.value;
      if (history.length < 3) continue;

      // Compute CV of total power across frames
      final powers = history.map((psd) {
        return psd.fold(0.0, (s, v) => s + v);
      }).toList();

      double sum = 0, sqSum = 0;
      for (final p in powers) {
        sum += p;
        sqSum += p * p;
      }
      final mean = sum / powers.length;
      final variance = sqSum / powers.length - mean * mean;
      final sd = sqrt(max(0, variance));
      final cv = mean > 0 ? sd / mean : 1.0;

      totalCv += cv;
      bandCount++;
    }

    if (bandCount == 0) return 50.0;

    final avgCv = totalCv / bandCount;
    // Map CV to 0-100 score: CV=0 → 100, CV=1 → 0
    return (100 * (1 - avgCv)).clamp(0.0, 100.0);
  }

  // ═══════════════════════════════════════════════════════════════
  //  5. Research-Grade Equivalence Score
  // ═══════════════════════════════════════════════════════════════

  /// Research-Grade Score (0-100)
  ///
  /// Composite metric ที่ map ไปยัง research-grade equivalence:
  /// - 90-100: Clinical-grade (เทียบเท่า Emotiv EPOC X)
  /// - 80-89: Research-grade (เทียบเท่า OpenBCI Cyton)
  /// - 60-79: Consumer+ (acceptable for screening research)
  /// - <60: Low quality (ต้อง retry)
  ///
  /// Weights:
  /// - SNR: 30% (signal quality)
  /// - Artifact rate: 30% (data usability)
  /// - PSD stability: 20% (temporal consistency)
  /// - Contact quality: 20% (hardware connection)
  double _computeResearchScore({
    required double avgSnr,
    required double artifactRate,
    required double psdStability,
    required int goodContacts,
  }) {
    // SNR component (30%)
    // >15 dB = 100, 10-15 = 80-100, 5-10 = 40-80, <5 = 0-40
    double snrScore;
    if (avgSnr >= 15) {
      snrScore = 100;
    } else if (avgSnr >= 10) {
      snrScore = 80 + (avgSnr - 10) * 4;
    } else if (avgSnr >= 5) {
      snrScore = 40 + (avgSnr - 5) * 8;
    } else {
      snrScore = max(0, avgSnr * 8);
    }

    // Artifact rate component (30%)
    // <5% = 100, 5-10% = 80-100, 10-30% = 40-80, >30% = 0-40
    double artScore;
    if (artifactRate < 0.05) {
      artScore = 100;
    } else if (artifactRate < 0.10) {
      artScore = 80 + (0.10 - artifactRate) * 400;
    } else if (artifactRate < 0.30) {
      artScore = 40 + (0.30 - artifactRate) * 200;
    } else {
      artScore = max(0, 40 * (1 - (artifactRate - 0.30)));
    }

    // Contact quality component (20%)
    final contactScore = (goodContacts / 4.0) * 100;

    // Final composite
    final score = snrScore * 0.30 +
        artScore * 0.30 +
        psdStability * 0.20 +
        contactScore * 0.20;

    return score.clamp(0.0, 100.0);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════

  double _computeRms(List<double> data) {
    if (data.isEmpty) return 0;
    // Remove mean first
    double sum = 0;
    for (final v in data) sum += v;
    final mean = sum / data.length;

    double sqSum = 0;
    for (final v in data) {
      final centered = v - mean;
      sqSum += centered * centered;
    }
    return sqrt(sqSum / data.length);
  }

  /// Get quality history for trend analysis
  List<OverallQuality> get qualityHistory =>
      List.unmodifiable(_qualityHistory);

  /// Latest quality assessment
  OverallQuality? get latest =>
      _qualityHistory.isNotEmpty ? _qualityHistory.last : null;

  /// Export quality history as JSON
  List<Map<String, dynamic>> exportHistory() {
    return _qualityHistory.map((q) => q.toJson()).toList();
  }

  /// Clear all history
  void reset() {
    _qualityHistory.clear();
    for (final list in _psdHistory.values) {
      list.clear();
    }
  }
}
