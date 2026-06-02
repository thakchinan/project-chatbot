import 'dart:math';

/// Virtual Channel Interpolation — ขยาย 4 channels เป็น 32 channels
///
/// ใช้ Spherical Spline Interpolation ตาม Perrin et al. (1989):
/// - จาก Muse 2 (TP9, AF7, AF8, TP10) → 32 virtual electrodes
/// - ตำแหน่ง electrode ตาม International 10-20 System
/// - Compatible กับ PyTorch model input [1, 1, 32, 5]
///
/// วิธีการ: Distance-weighted interpolation บน unit sphere
/// - แต่ละ virtual electrode = weighted average ของ measured electrodes
/// - น้ำหนักขึ้นกับระยะทางบน sphere (ยิ่งใกล้ = น้ำหนักมาก)
/// - ให้ confidence score ที่ลดลงตามระยะทาง
///
/// อ้างอิง:
/// - Perrin, Pernier, Bertnard & Echallier (1989) 
///   "Spherical splines for scalp potential and current density mapping"
/// - International 10-20 System electrode positions
class VirtualChannelInterpolator {
  /// Measured electrode positions (Muse 2) in spherical coordinates
  /// Format: {name: (theta, phi)} — theta=polar angle, phi=azimuth
  static const Map<String, List<double>> measuredPositions = {
    'TP9':  [-0.91, -0.39, 0.14],  // Behind left ear
    'AF7':  [-0.59,  0.81, 0.15],  // Left forehead
    'AF8':  [ 0.59,  0.81, 0.15],  // Right forehead
    'TP10': [ 0.91, -0.39, 0.14],  // Behind right ear
  };

  /// Standard 10-20 System positions for 32 electrodes
  /// Coordinates on unit sphere: (x, y, z) where
  /// x=left/right, y=front/back, z=up/down
  static const Map<String, List<double>> standardPositions = {
    // Frontal
    'Fp1': [-0.31,  0.95, 0.05],
    'Fp2': [ 0.31,  0.95, 0.05],
    'F7':  [-0.81,  0.59, 0.05],
    'F3':  [-0.55,  0.67, 0.50],
    'Fz':  [ 0.00,  0.72, 0.69],
    'F4':  [ 0.55,  0.67, 0.50],
    'F8':  [ 0.81,  0.59, 0.05],
    // Frontal-Central
    'FC5': [-0.81,  0.31, 0.50],
    'FC1': [-0.31,  0.36, 0.88],
    'FC2': [ 0.31,  0.36, 0.88],
    'FC6': [ 0.81,  0.31, 0.50],
    // Central
    'T7':  [-1.00,  0.00, 0.00],
    'C3':  [-0.59,  0.00, 0.81],
    'Cz':  [ 0.00,  0.00, 1.00],
    'C4':  [ 0.59,  0.00, 0.81],
    'T8':  [ 1.00,  0.00, 0.00],
    // Central-Parietal
    'CP5': [-0.81, -0.31, 0.50],
    'CP1': [-0.31, -0.36, 0.88],
    'CP2': [ 0.31, -0.36, 0.88],
    'CP6': [ 0.81, -0.31, 0.50],
    // Parietal
    'P7':  [-0.81, -0.59, 0.05],
    'P3':  [-0.55, -0.67, 0.50],
    'Pz':  [ 0.00, -0.72, 0.69],
    'P4':  [ 0.55, -0.67, 0.50],
    'P8':  [ 0.81, -0.59, 0.05],
    // Parietal-Occipital
    'PO3': [-0.31, -0.88, 0.36],
    'PO4': [ 0.31, -0.88, 0.36],
    // Occipital
    'O1':  [-0.31, -0.95, 0.05],
    'Oz':  [ 0.00, -1.00, 0.05],
    'O2':  [ 0.31, -0.95, 0.05],
    // Additional temporal
    'AF7': [-0.59,  0.81, 0.15],
    'AF8': [ 0.59,  0.81, 0.15],
  };

  /// Pre-computed interpolation weights
  late final Map<String, Map<String, double>> _weights;

  /// Pre-computed confidence scores
  late final Map<String, double> _confidence;

  VirtualChannelInterpolator() {
    _precomputeWeights();
  }

  /// Pre-compute interpolation weights สำหรับทุก virtual electrode
  void _precomputeWeights() {
    _weights = {};
    _confidence = {};

    for (final vEntry in standardPositions.entries) {
      final vName = vEntry.key;
      final vPos = vEntry.value;

      // Skip if it's a measured electrode
      if (measuredPositions.containsKey(vName)) {
        _weights[vName] = {vName: 1.0};
        _confidence[vName] = 1.0;
        continue;
      }

      // Compute distances to all measured electrodes
      final distances = <String, double>{};
      for (final mEntry in measuredPositions.entries) {
        distances[mEntry.key] = _sphericalDistance(vPos, mEntry.value);
      }

      // Inverse distance weighting: w_i = 1/d_i^2
      // (squared for stronger locality)
      final weights = <String, double>{};
      double totalWeight = 0;

      for (final dEntry in distances.entries) {
        final d = dEntry.value;
        final w = d > 0.01 ? 1.0 / (d * d) : 100.0; // Avoid div-by-zero
        weights[dEntry.key] = w;
        totalWeight += w;
      }

      // Normalize weights
      if (totalWeight > 0) {
        for (final key in weights.keys) {
          weights[key] = weights[key]! / totalWeight;
        }
      }

      _weights[vName] = weights;

      // Confidence: based on minimum distance to any measured electrode
      // Closer = higher confidence
      final minDist = distances.values.reduce(min);
      // Confidence decays as sigmoid: 1/(1 + e^(3*(d-0.5)))
      _confidence[vName] = 1.0 / (1.0 + exp(3.0 * (minDist - 0.5)));
    }
  }

  /// Spherical distance between two points on unit sphere
  static double _sphericalDistance(List<double> a, List<double> b) {
    // Euclidean distance in 3D (good approximation on unit sphere)
    double sum = 0;
    for (int i = 0; i < 3; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sqrt(sum);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Interpolation
  // ═══════════════════════════════════════════════════════════════

  /// Interpolate band powers สำหรับ 32 virtual electrodes
  ///
  /// Input: per-channel band powers {TP9: {delta: ..., theta: ..., ...}, ...}
  /// Output: 32-electrode band powers [32][5] — ready for PyTorch model
  List<List<double>> interpolateBandPowers(
      Map<String, Map<String, double>> channelPowers) {
    final bandNames = ['delta', 'theta', 'alpha', 'beta', 'gamma'];
    final result = <List<double>>[];

    // Get ordered list of standard electrode names (32 channels)
    final electrodeNames = standardPositions.keys.toList();

    for (final eName in electrodeNames) {
      final weights = _weights[eName] ?? {};
      final bands = <double>[];

      for (final band in bandNames) {
        double value = 0;
        for (final wEntry in weights.entries) {
          final chPower = channelPowers[wEntry.key];
          if (chPower != null) {
            value += (chPower[band] ?? 0) * wEntry.value;
          }
        }
        bands.add(value);
      }

      result.add(bands);
    }

    return result;
  }

  /// Interpolate single time-domain sample
  ///
  /// Input: measured values {TP9: value, AF7: value, AF8: value, TP10: value}
  /// Output: 32 interpolated values
  Map<String, double> interpolateSample(Map<String, double> measured) {
    final result = <String, double>{};

    for (final entry in _weights.entries) {
      double value = 0;
      for (final wEntry in entry.value.entries) {
        value += (measured[wEntry.key] ?? 0) * wEntry.value;
      }
      result[entry.key] = value;
    }

    return result;
  }

  /// Get confidence score for a virtual electrode (0.0-1.0)
  double getConfidence(String electrodeName) {
    return _confidence[electrodeName] ?? 0;
  }

  /// Get all confidence scores
  Map<String, double> get allConfidences =>
      Map.unmodifiable(_confidence);

  /// Get interpolation weights for a virtual electrode
  Map<String, double> getWeights(String electrodeName) {
    return _weights[electrodeName] ?? {};
  }

  /// Summary: สำหรับแสดงใน UI
  Map<String, dynamic> summary() {
    final highConf = _confidence.entries
        .where((e) => e.value > 0.7)
        .length;
    final medConf = _confidence.entries
        .where((e) => e.value > 0.4 && e.value <= 0.7)
        .length;
    final lowConf = _confidence.entries
        .where((e) => e.value <= 0.4)
        .length;

    return {
      'total_electrodes': standardPositions.length,
      'measured': measuredPositions.length,
      'interpolated': standardPositions.length - measuredPositions.length,
      'high_confidence': highConf,
      'medium_confidence': medConf,
      'low_confidence': lowConf,
      'method': 'Inverse Distance Weighting (Spherical)',
    };
  }
}
