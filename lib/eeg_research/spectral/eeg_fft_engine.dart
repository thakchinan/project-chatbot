import 'dart:math';
import '../models/complex_number.dart';
import '../models/quality_metrics.dart';

/// Research-Grade FFT Engine สำหรับ EEG
///
/// คุณสมบัติหลัก:
/// - Cooley-Tukey FFT สำหรับ real/complex array → เก็บ complex spectrum
/// - Hann/Hamming/Blackman-Harris windowing
/// - Welch's Method PSD (overlapping segments → lower variance)
/// - Band power: Delta(1-4), Theta(4-8), Alpha(8-13), Beta(13-30), Gamma(30-45)
/// - Advanced features: entropy, coherence, spectral edge
///
/// อ้างอิง:
/// - Cooley & Tukey (1965) "An Algorithm for the Machine Calculation of Complex Fourier Series"
/// - Welch (1967) "The Use of FFT for Estimation of Power Spectra"
/// - IFCN Standards for Digital EEG Recording (2017)
class EegFftEngine {
  /// Sampling rate (Hz) — Muse 2 = 256 Hz
  final int samplingRate;

  /// FFT frame size — must be power of 2
  final int frameSize;

  /// Window function type
  final WindowType windowType;

  /// Pre-computed window coefficients
  late final List<double> _window;

  /// Window energy for PSD normalization
  late final double _windowEnergy;

  EegFftEngine({
    this.samplingRate = 256,
    this.frameSize = 256,
    this.windowType = WindowType.hann,
  }) {
    assert(frameSize > 0 && (frameSize & (frameSize - 1)) == 0,
        'frameSize must be power of 2');
    _window = _computeWindow(frameSize, windowType);
    _windowEnergy = _window.fold(0.0, (sum, w) => sum + w * w) / frameSize;
  }

  /// Frequency resolution (Hz per bin)
  double get frequencyResolution => samplingRate / frameSize;

  /// Maximum representable frequency (Nyquist)
  double get nyquistFrequency => samplingRate / 2.0;

  // ═══════════════════════════════════════════════════════════════
  //  FFT — Cooley-Tukey Radix-2 DIT (complex output)
  // ═══════════════════════════════════════════════════════════════

  /// Full complex FFT
  ///
  /// Returns List<Complex> ขนาด N (full spectrum)
  /// ใช้ first N/2 bins สำหรับ positive frequencies
  List<Complex> fft(List<double> input) {
    final n = frameSize;
    assert(input.length >= n, 'Input must be >= frameSize ($n)');

    // 1. Apply window + DC removal
    double sum = 0;
    for (int i = 0; i < n; i++) {
      sum += input[i];
    }
    final mean = sum / n;

    List<Complex> data = List.generate(n, (i) {
      return Complex((input[i] - mean) * _window[i], 0);
    });

    // 2. Bit-reversal permutation
    data = _bitReverse(data);

    // 3. Cooley-Tukey butterfly
    for (int len = 2; len <= n; len *= 2) {
      final halfLen = len ~/ 2;
      final angle = -2.0 * pi / len;
      final wLen = Complex(cos(angle), sin(angle));

      for (int i = 0; i < n; i += len) {
        var w = const Complex.one();
        for (int j = 0; j < halfLen; j++) {
          final u = data[i + j];
          final v = data[i + j + halfLen] * w;
          data[i + j] = u + v;
          data[i + j + halfLen] = u - v;
          w = w * wLen;
        }
      }
    }

    return data;
  }

  /// FFT แล้วส่งกลับแค่ magnitude spectrum (N/2 bins)
  List<double> fftMagnitudes(List<double> input) {
    final spectrum = fft(input);
    final n = frameSize ~/ 2;
    return List.generate(n, (i) => spectrum[i].magnitude);
  }

  /// FFT แล้วส่งกลับ power spectrum = |X(f)|² (N/2 bins)
  List<double> fftPower(List<double> input) {
    final spectrum = fft(input);
    final n = frameSize ~/ 2;
    return List.generate(n, (i) => spectrum[i].magnitudeSquared);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Welch's Method PSD
  // ═══════════════════════════════════════════════════════════════

  /// Welch's Method Power Spectral Density
  ///
  /// Parameters:
  /// - data: raw time-domain signal
  /// - overlap: overlap fraction (0.0-1.0), default 0.5 (50%)
  ///
  /// Returns: PSD curve in µV²/Hz (list of N/2 values)
  ///
  /// อ้างอิง: Welch (1967) — ลด variance ของ PSD estimate ~50%
  List<double> welchPSD(List<double> data, {double overlap = 0.5}) {
    final n = frameSize;
    final halfN = n ~/ 2;
    final stepSize = (n * (1 - overlap)).round();
    final numSegments =
        max(1, ((data.length - n) / stepSize).floor() + 1);

    // Accumulate power from all segments
    final psd = List<double>.filled(halfN, 0.0);

    int segCount = 0;
    for (int seg = 0; seg < numSegments; seg++) {
      final start = seg * stepSize;
      if (start + n > data.length) break;

      final segment = data.sublist(start, start + n);
      final power = fftPower(segment);

      for (int i = 0; i < halfN; i++) {
        psd[i] += power[i];
      }
      segCount++;
    }

    if (segCount == 0) {
      // Fallback: zero-pad and compute single segment
      final padded = List<double>.filled(n, 0.0);
      for (int i = 0; i < min(data.length, n); i++) {
        padded[i] = data[i];
      }
      final power = fftPower(padded);
      for (int i = 0; i < halfN; i++) {
        psd[i] = power[i];
      }
      segCount = 1;
    }

    // Average across segments and normalize
    // PSD = |X(f)|² / (fs * sum(w²))
    final norm = segCount * samplingRate * _windowEnergy * n;
    for (int i = 0; i < halfN; i++) {
      psd[i] = psd[i] / (norm > 0 ? norm : 1);
    }

    return psd;
  }

  // ═══════════════════════════════════════════════════════════════
  //  Band Power Calculation
  // ═══════════════════════════════════════════════════════════════

  /// Band power boundaries (Hz)
  static const Map<String, List<double>> bandRanges = {
    'delta': [1.0, 4.0],
    'theta': [4.0, 8.0],
    'alpha': [8.0, 13.0],
    'beta': [13.0, 30.0],
    'gamma': [30.0, 45.0],
  };

  /// คำนวณ band power จาก PSD curve
  ///
  /// Returns BandPowerResult พร้อม absolute + relative power
  BandPowerResult computeBandPower(List<double> psd) {
    final freqRes = frequencyResolution;
    final absolute = <String, double>{};

    for (final entry in bandRanges.entries) {
      final lowBin = (entry.value[0] / freqRes).ceil();
      final highBin = (entry.value[1] / freqRes).floor();
      double power = 0;
      for (int i = lowBin;
          i <= highBin && i < psd.length;
          i++) {
        power += psd[i] * freqRes; // Integrate PSD
      }
      absolute[entry.key] = power;
    }

    // Relative power
    final total =
        absolute.values.fold(0.0, (s, v) => s + v);
    final relative = <String, double>{};
    for (final entry in absolute.entries) {
      relative[entry.key] =
          total > 0 ? entry.value / total : 0;
    }

    // Advanced features
    final alpha = absolute['alpha'] ?? 0;
    final beta = absolute['beta'] ?? 0;
    final theta = absolute['theta'] ?? 0;

    final alphaBetaRatio = beta > 0.001 ? alpha / beta : 0.0;
    final thetaAlphaRatio = alpha > 0.001 ? theta / alpha : 0.0;

    // Spectral edge frequency 95%
    final totalPsd =
        psd.fold(0.0, (s, v) => s + v);
    double cumPsd = 0;
    double sef95 = nyquistFrequency;
    for (int i = 0; i < psd.length; i++) {
      cumPsd += psd[i];
      if (cumPsd >= totalPsd * 0.95) {
        sef95 = i * freqRes;
        break;
      }
    }

    return BandPowerResult(
      absolute: absolute,
      relative: relative,
      psdCurve: psd,
      frequencyResolution: freqRes,
      alphaBetaRatio: alphaBetaRatio,
      thetaAlphaRatio: thetaAlphaRatio,
      spectralEdgeFreq95: sef95,
    );
  }

  /// คำนวณ band power จาก raw signal (shortcut)
  BandPowerResult computeFromSignal(List<double> signal) {
    final psd = welchPSD(signal);
    return computeBandPower(psd);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Sample Entropy — Signal Complexity Measure
  // ═══════════════════════════════════════════════════════════════

  /// Sample Entropy (SampEn)
  ///
  /// Measures signal complexity/regularity:
  /// - Low SampEn → regular/periodic (e.g., eyes closed alpha)
  /// - High SampEn → complex/irregular (e.g., active thinking)
  ///
  /// Parameters:
  /// - m: template length (default 2)
  /// - r: tolerance (default 0.2 * SD)
  ///
  /// อ้างอิง: Richman & Moorman (2000)
  static double sampleEntropy(List<double> data,
      {int m = 2, double? r}) {
    final n = data.length;
    if (n < m + 2) return 0;

    // Compute standard deviation
    double sum = 0, sqSum = 0;
    for (final v in data) {
      sum += v;
      sqSum += v * v;
    }
    final mean = sum / n;
    final sd = sqrt(sqSum / n - mean * mean);
    final tolerance = r ?? (0.2 * sd);
    if (tolerance <= 0) return 0;

    int countM = 0, countM1 = 0;

    for (int i = 0; i < n - m; i++) {
      for (int j = i + 1; j < n - m; j++) {
        // Check template match of length m
        bool matchM = true;
        for (int k = 0; k < m; k++) {
          if ((data[i + k] - data[j + k]).abs() > tolerance) {
            matchM = false;
            break;
          }
        }
        if (matchM) {
          countM++;
          // Check extended match of length m+1
          if (i + m < n &&
              j + m < n &&
              (data[i + m] - data[j + m]).abs() <= tolerance) {
            countM1++;
          }
        }
      }
    }

    if (countM == 0 || countM1 == 0) return 0;
    return -log(countM1 / countM);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Channel Coherence — Connectivity Measure
  // ═══════════════════════════════════════════════════════════════

  /// Magnitude-Squared Coherence ระหว่าง 2 channels
  ///
  /// Coherence = |Sxy(f)|² / (Sxx(f) * Syy(f))
  /// ค่า 0-1: 0 = ไม่สัมพันธ์, 1 = สัมพันธ์สมบูรณ์
  ///
  /// Returns: average coherence ใน band 8-13 Hz (alpha band)
  double coherence(List<double> x, List<double> y,
      {double lowFreq = 8.0, double highFreq = 13.0}) {
    final n = frameSize;
    if (x.length < n || y.length < n) return 0;

    final fftX = fft(x.sublist(0, n));
    final fftY = fft(y.sublist(0, n));
    final halfN = n ~/ 2;

    final lowBin = (lowFreq / frequencyResolution).ceil();
    final highBin = min(halfN - 1, (highFreq / frequencyResolution).floor());

    double sumCxy = 0, sumCxx = 0, sumCyy = 0;

    for (int i = lowBin; i <= highBin; i++) {
      // Cross-spectral density
      final cxy = fftX[i] * fftY[i].conjugate;
      sumCxy += cxy.magnitudeSquared;
      sumCxx += fftX[i].magnitudeSquared;
      sumCyy += fftY[i].magnitudeSquared;
    }

    final denom = sumCxx * sumCyy;
    return denom > 0 ? sumCxy / denom : 0;
  }

  /// คำนวณ coherence ทุก channel pairs
  Map<String, double> allCoherences(Map<String, List<double>> channels) {
    final names = channels.keys.toList();
    final result = <String, double>{};

    for (int i = 0; i < names.length; i++) {
      for (int j = i + 1; j < names.length; j++) {
        final key = '${names[i]}-${names[j]}';
        final x = channels[names[i]]!;
        final y = channels[names[j]]!;
        result[key] = coherence(x, y);
      }
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  //  Window Functions
  // ═══════════════════════════════════════════════════════════════

  static List<double> _computeWindow(int n, WindowType type) {
    return List.generate(n, (i) {
      switch (type) {
        case WindowType.hann:
          return 0.5 * (1 - cos(2 * pi * i / (n - 1)));
        case WindowType.hamming:
          return 0.54 - 0.46 * cos(2 * pi * i / (n - 1));
        case WindowType.blackmanHarris:
          return 0.35875 -
              0.48829 * cos(2 * pi * i / (n - 1)) +
              0.14128 * cos(4 * pi * i / (n - 1)) -
              0.01168 * cos(6 * pi * i / (n - 1));
        case WindowType.rectangular:
          return 1.0;
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  Bit-Reversal (for in-place FFT)
  // ═══════════════════════════════════════════════════════════════

  List<Complex> _bitReverse(List<Complex> data) {
    final n = data.length;
    final result = List<Complex>.from(data);
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final temp = result[j];
        result[j] = result[i];
        result[i] = temp;
      }
      int k = n ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }
    return result;
  }
}

/// Window function types สำหรับ FFT
enum WindowType {
  hann,          // Hanning — default สำหรับ EEG
  hamming,       // Hamming — slightly better sidelobe
  blackmanHarris, // Blackman-Harris — best sidelobe rejection
  rectangular,   // No window — for testing only
}
