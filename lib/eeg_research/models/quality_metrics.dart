import 'package:flutter/material.dart';

/// ระดับคุณภาพสัญญาณ
enum QualityLevel {
  good,   // 🟢 สัญญาณดี
  fair,   // 🟡 พอใช้ได้
  poor,   // 🔴 สัญญาณแย่
  noData, // ⚫ ไม่มีข้อมูล
}

extension QualityLevelExt on QualityLevel {
  Color get color {
    switch (this) {
      case QualityLevel.good:
        return const Color(0xFF4CAF50);
      case QualityLevel.fair:
        return const Color(0xFFFFC107);
      case QualityLevel.poor:
        return const Color(0xFFF44336);
      case QualityLevel.noData:
        return const Color(0xFF9E9E9E);
    }
  }

  String get label {
    switch (this) {
      case QualityLevel.good:
        return 'ดี';
      case QualityLevel.fair:
        return 'พอใช้';
      case QualityLevel.poor:
        return 'แย่';
      case QualityLevel.noData:
        return 'ไม่มีข้อมูล';
    }
  }

  String get labelEn {
    switch (this) {
      case QualityLevel.good:
        return 'Good';
      case QualityLevel.fair:
        return 'Fair';
      case QualityLevel.poor:
        return 'Poor';
      case QualityLevel.noData:
        return 'No Data';
    }
  }

  IconData get icon {
    switch (this) {
      case QualityLevel.good:
        return Icons.check_circle;
      case QualityLevel.fair:
        return Icons.warning_amber_rounded;
      case QualityLevel.poor:
        return Icons.error;
      case QualityLevel.noData:
        return Icons.help_outline;
    }
  }
}

/// คุณภาพสัญญาณแยกแต่ละ electrode
class ChannelQuality {
  final String channelName;

  /// Signal-to-Noise Ratio (dB)
  /// >10 dB = ดี, 5-10 dB = พอใช้, <5 dB = แย่
  final double snrDb;

  /// Artifact rate (0.0-1.0)
  /// <0.10 = ดี, 0.10-0.30 = พอใช้, >0.30 = แย่
  final double artifactRate;

  /// Contact quality (impedance estimation)
  final QualityLevel contactQuality;

  /// RMS amplitude (µV) — ใช้ตรวจ flatline/saturation
  final double rmsAmplitude;

  /// Is electrode likely disconnected?
  final bool isDisconnected;

  const ChannelQuality({
    required this.channelName,
    this.snrDb = 0,
    this.artifactRate = 0,
    this.contactQuality = QualityLevel.noData,
    this.rmsAmplitude = 0,
    this.isDisconnected = false,
  });

  QualityLevel get snrLevel {
    if (snrDb > 10) return QualityLevel.good;
    if (snrDb > 5) return QualityLevel.fair;
    return QualityLevel.poor;
  }

  QualityLevel get artifactLevel {
    if (artifactRate < 0.10) return QualityLevel.good;
    if (artifactRate < 0.30) return QualityLevel.fair;
    return QualityLevel.poor;
  }

  /// Overall quality สำหรับ electrode นี้
  QualityLevel get overall {
    if (isDisconnected) return QualityLevel.poor;
    final levels = [snrLevel, artifactLevel, contactQuality];
    if (levels.any((l) => l == QualityLevel.poor)) return QualityLevel.poor;
    if (levels.any((l) => l == QualityLevel.fair)) return QualityLevel.fair;
    return QualityLevel.good;
  }

  Map<String, dynamic> toJson() => {
        'channel': channelName,
        'snr_db': snrDb,
        'artifact_rate': artifactRate,
        'contact': contactQuality.labelEn,
        'rms_uv': rmsAmplitude,
        'disconnected': isDisconnected,
      };
}

/// คุณภาพสัญญาณรวม (ทั้ง 4 ช่อง)
class OverallQuality {
  /// Per-channel quality
  final Map<String, ChannelQuality> channels;

  /// Average SNR across all channels (dB)
  final double avgSnrDb;

  /// Overall artifact rate (0.0-1.0)
  final double overallArtifactRate;

  /// PSD stability score (0-100)
  /// ยิ่งสูง = PSD คงที่ = สัญญาณเสถียร
  final double psdStability;

  /// จำนวน electrode ที่ contact ดี
  final int goodContactCount;

  /// Research-grade equivalence score (0-100)
  final double researchScore;

  /// Timestamp
  final DateTime timestamp;

  const OverallQuality({
    required this.channels,
    this.avgSnrDb = 0,
    this.overallArtifactRate = 0,
    this.psdStability = 0,
    this.goodContactCount = 0,
    this.researchScore = 0,
    required this.timestamp,
  });

  factory OverallQuality.empty() => OverallQuality(
        channels: {},
        timestamp: DateTime.now(),
      );

  /// Research-grade label
  String get researchLabel {
    if (researchScore >= 90) return 'Clinical-Grade (Emotiv EPOC X)';
    if (researchScore >= 80) return 'Research-Grade (OpenBCI)';
    if (researchScore >= 60) return 'Consumer+ (screening OK)';
    return 'Low Quality (retry)';
  }

  QualityLevel get researchLevel {
    if (researchScore >= 80) return QualityLevel.good;
    if (researchScore >= 60) return QualityLevel.fair;
    return QualityLevel.poor;
  }

  QualityLevel get overallLevel {
    if (goodContactCount >= 4 &&
        avgSnrDb > 10 &&
        overallArtifactRate < 0.10) {
      return QualityLevel.good;
    }
    if (goodContactCount >= 2 &&
        avgSnrDb > 5 &&
        overallArtifactRate < 0.30) {
      return QualityLevel.fair;
    }
    return QualityLevel.poor;
  }

  Map<String, dynamic> toJson() => {
        'avg_snr_db': avgSnrDb,
        'artifact_rate': overallArtifactRate,
        'psd_stability': psdStability,
        'good_contacts': goodContactCount,
        'research_score': researchScore,
        'research_label': researchLabel,
        'timestamp': timestamp.toIso8601String(),
        'channels':
            channels.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Band power results พร้อม absolute + relative values
class BandPowerResult {
  /// Absolute power (µV²/Hz)
  final Map<String, double> absolute;

  /// Relative power (0.0-1.0)
  final Map<String, double> relative;

  /// Full PSD curve: frequency (Hz) → power (µV²/Hz)
  final List<double> psdCurve;

  /// Frequency resolution (Hz per bin)
  final double frequencyResolution;

  /// Advanced features
  final double alphaBetaRatio;
  final double thetaAlphaRatio;
  final double sampleEntropy;
  final double spectralEdgeFreq95;

  /// Channel coherence (channel pair → coherence 0-1)
  final Map<String, double> coherence;

  const BandPowerResult({
    required this.absolute,
    required this.relative,
    this.psdCurve = const [],
    this.frequencyResolution = 1.0,
    this.alphaBetaRatio = 0,
    this.thetaAlphaRatio = 0,
    this.sampleEntropy = 0,
    this.spectralEdgeFreq95 = 0,
    this.coherence = const {},
  });

  double get totalPower =>
      absolute.values.fold(0.0, (sum, v) => sum + v);

  Map<String, dynamic> toJson() => {
        'absolute': absolute,
        'relative': relative,
        'alpha_beta_ratio': alphaBetaRatio,
        'theta_alpha_ratio': thetaAlphaRatio,
        'sample_entropy': sampleEntropy,
        'spectral_edge_95': spectralEdgeFreq95,
        'coherence': coherence,
      };
}
