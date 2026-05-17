class BrainwaveData {
  final double alpha;
  final double beta;
  final double theta;
  final double delta;
  final double gamma;
  final double attention;
  final double meditation;
  final DateTime timestamp;

  BrainwaveData({
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.delta,
    required this.gamma,
    this.attention = 0,
    this.meditation = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'alpha': alpha,
        'beta': beta,
        'theta': theta,
        'delta': delta,
        'gamma': gamma,
        'attention': attention,
        'meditation': meditation,
      };
}

class MuseBleDevice {
  final String platformName;
  final String remoteId;

  const MuseBleDevice({
    required this.platformName,
    required this.remoteId,
  });
}

class MuseScanResult {
  final MuseBleDevice device;
  final int rssi;

  const MuseScanResult({
    required this.device,
    required this.rssi,
  });
}
