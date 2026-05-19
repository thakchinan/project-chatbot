import 'dart:math';

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
      {double lowCut = 0.5, double highCut = 45.0}) {
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
  //  Signal Quality
  // =========================================================

  /// Signal Quality Index (0-100) — Optimized for Muse Consumer-Grade EEG
  ///
  /// ปรับปรุงจากเวอร์ชันเดิมที่ได้ SQI ต่ำเกินจริง (~59%) เนื่องจาก:
  /// - ใช้ raw data (มี DC offset/drift) ทำให้ SD สูงเกินไป
  /// - Flatline threshold เข้มงวดเกินสำหรับ consumer-grade
  /// - Spectral Entropy ใช้ amplitude histogram แทน frequency-domain
  ///
  /// เวอร์ชันใหม่:
  /// 1. Pre-filter: ลบ DC offset ก่อนคำนวณ (สำคัญมาก!)
  /// 2. SD Score: ปรับ range ให้เหมาะกับ Muse (3-150 µV)
  /// 3. Flatline: ลด sensitivity เป็น 0.1 µV (Muse ADC quantization noise)
  /// 4. Artifact: ใช้ 4σ rule แทน 3σ (consumer-grade มี noise มากกว่า clinical)
  /// 5. Spectral Entropy: ใช้ FFT-based frequency domain จริง
  /// 6. Alpha Presence: ตรวจว่ามีคลื่น Alpha (สัญญาณว่า electrode แนบดี)
  ///
  /// อ้างอิง: Krigolson et al. (2017), Muse validation study
  static double calculateSQI(List<double> input) {
    if (input.isEmpty) return 0;
    if (input.length < 32) return 20; // ข้อมูลน้อยเกินไป

    // === Step 0: Remove DC offset (zero-mean) ===
    // สำคัญ! Raw Muse data มี DC offset ~400-800 µV
    // ถ้าไม่ลบ DC → SD จะสูงเกินจริง → SQI ต่ำ
    double rawSum = 0;
    for (var v in input) rawSum += v;
    double rawMean = rawSum / input.length;

    List<double> centered = List.filled(input.length, 0.0);
    for (int i = 0; i < input.length; i++) {
      centered[i] = input[i] - rawMean;
    }

    // === Compute stats on centered (DC-removed) data ===
    double sum = 0, sqSum = 0;
    for (var v in centered) { sum += v; sqSum += v * v; }
    double mean = sum / centered.length;
    double variance = (sqSum / centered.length) - (mean * mean);
    double sd = sqrt(variance.abs());

    // === 1. SD Score (30% weight) ===
    // สัญญาณ EEG ดีจะมี SD อยู่ในช่วง 3-150 µV
    // Muse consumer-grade: ADC 12-bit, range 0-1682 µV → centered SD ~10-80 µV ปกติ
    double sdScore;
    if (sd >= 3 && sd <= 150) {
      sdScore = 100;
    } else if (sd < 3) {
      // สัญญาณแบนเกินไป (electrode อาจไม่แนบ)
      sdScore = (sd / 3.0) * 70;
    } else {
      // Noise สูงเกินไป (sd > 150 → กระดิก/สิ่งรบกวน)
      sdScore = max(0, 100 - (sd - 150) * 0.5);
    }

    // === 2. Flatline Detection (15% weight) ===
    // ใช้ threshold 0.1 µV แทน 0.01 (Muse ADC quantization ~0.4 µV)
    int flatCount = 0;
    for (int i = 1; i < centered.length; i++) {
      if ((centered[i] - centered[i-1]).abs() < 0.1) flatCount++;
    }
    double flatRatio = flatCount / (centered.length - 1);
    // Flatline < 30% ถือว่าปกติ (consumer-grade อาจมี flat spots เล็กน้อย)
    double flatScore;
    if (flatRatio < 0.3) {
      flatScore = 100;
    } else if (flatRatio < 0.7) {
      flatScore = 100 - ((flatRatio - 0.3) / 0.4) * 80;
    } else {
      flatScore = max(0, 20 - (flatRatio - 0.7) * 60);
    }

    // === 3. Artifact Ratio (20% weight) ===
    // ใช้ 4σ rule สำหรับ consumer-grade (เดิม 3σ เข้มเกิน)
    // ~0.006% ของข้อมูลปกติจะเกิน 4σ
    int artCount = 0;
    double artThreshold = max(4 * sd, 10.0); // ขั้นต่ำ 10 µV
    for (var v in centered) {
      if ((v - mean).abs() > artThreshold) artCount++;
    }
    double artRatio = artCount / centered.length;
    // < 5% artifacts = perfect, > 20% = poor
    double artScore;
    if (artRatio < 0.05) {
      artScore = 100;
    } else if (artRatio < 0.20) {
      artScore = 100 - ((artRatio - 0.05) / 0.15) * 60;
    } else {
      artScore = max(0, 40 - (artRatio - 0.20) * 200);
    }

    // === 4. Spectral Entropy — Frequency Domain (20% weight) ===
    // ใช้ FFT-based spectral entropy จริง (ไม่ใช่ amplitude histogram)
    double entropyScore = _spectralEntropyFFT(centered);

    // === 5. Alpha Presence Check (15% weight) ===
    // ถ้ามีคลื่น Alpha (8-13 Hz) = electrode แนบหน้าผากดี
    // อ้างอิง: Alpha rhythm เป็น hallmark ของ EEG ที่มี electrode contact ดี
    double alphaScore = _alphaBandPresence(centered);

    // === Weighted Average ===
    double finalSQI = (sdScore * 0.30 +
                       flatScore * 0.15 +
                       artScore * 0.20 +
                       entropyScore * 0.20 +
                       alphaScore * 0.15).clamp(0.0, 100.0);

    return finalSQI;
  }

  /// Spectral Entropy (Frequency Domain) — ใช้ FFT จริง
  /// สัญญาณ EEG ดีจะมี entropy ปานกลาง (มีหลาย frequency bands)
  /// Noise ขาวจะมี entropy สูงมาก, สัญญาณ flat จะมี entropy ต่ำมาก
  static double _spectralEntropyFFT(List<double> input) {
    if (input.length < 64) return 50;

    // หา power-of-2 ที่ใกล้ที่สุดและ ≤ ความยาว input
    int fftSize = 64;
    while (fftSize * 2 <= input.length && fftSize < 512) {
      fftSize *= 2;
    }

    // ตัด input ให้พอดี fftSize
    List<double> segment = input.sublist(input.length - fftSize);
    
    try {
      List<double> mags = computeMagnitudes(segment);
      
      // คำนวณ Power Spectral Density
      double totalPower = 0;
      List<double> powers = List.filled(mags.length, 0.0);
      for (int i = 1; i < mags.length; i++) {
        powers[i] = mags[i] * mags[i];
        totalPower += powers[i];
      }
      
      if (totalPower < 1e-10) return 0; // No signal

      // Shannon Entropy ของ normalized PSD
      double entropy = 0;
      for (int i = 1; i < powers.length; i++) {
        double p = powers[i] / totalPower;
        if (p > 1e-10) {
          entropy -= p * log(p);
        }
      }

      // Normalize: max entropy = log(N-1) สำหรับ uniform distribution
      double maxEntropy = log(powers.length - 1);
      if (maxEntropy < 1e-10) return 50;

      double normalizedEntropy = entropy / maxEntropy; // 0-1

      // EEG ดีจะมี entropy อยู่กลางๆ (0.4-0.85)
      // ต่ำเกินไป = single frequency = artifact/power line
      // สูงเกินไป = white noise = electrode ไม่ดี
      double score;
      if (normalizedEntropy >= 0.4 && normalizedEntropy <= 0.85) {
        score = 100; // Sweet spot
      } else if (normalizedEntropy < 0.4) {
        score = (normalizedEntropy / 0.4) * 85; // Too narrow-band
      } else {
        // > 0.85: leaning towards noise
        score = max(40, 100 - ((normalizedEntropy - 0.85) / 0.15) * 60);
      }

      return score.clamp(0.0, 100.0);
    } catch (e) {
      return 50; // Fallback
    }
  }

  /// Alpha Band Presence — ตรวจว่ามีคลื่น Alpha หรือไม่
  /// Alpha (8-13 Hz) เป็นตัวบ่งชี้ว่า electrode แนบหนังศีรษะดี
  /// ถ้าไม่มี Alpha เลย = อาจเป็น noise/electrode หลุด
  static double _alphaBandPresence(List<double> input) {
    if (input.length < 64) return 50;

    int fftSize = 64;
    while (fftSize * 2 <= input.length && fftSize < 512) {
      fftSize *= 2;
    }

    List<double> segment = input.sublist(input.length - fftSize);
    
    try {
      List<double> mags = computeMagnitudes(segment);
      double resolution = 256.0 / fftSize; // Assuming 256 Hz

      double alphaPower = 0;
      double totalPower = 0;

      for (int i = 1; i < mags.length; i++) {
        double freq = i * resolution;
        double power = mags[i] * mags[i];
        totalPower += power;
        if (freq >= 8 && freq < 13) {
          alphaPower += power;
        }
      }

      if (totalPower < 1e-10) return 30;

      double alphaRatio = alphaPower / totalPower;

      // EEG ปกติ: alpha = 10-40% ของ total power (relaxed, eyes closed)
      // Active: alpha = 5-15%
      // Consumer-grade (Muse): alpha ~8-25% typically
      double score;
      if (alphaRatio >= 0.05) {
        // มี alpha = electrode contact ดี
        score = min(100, 70 + (alphaRatio / 0.30) * 30);
      } else if (alphaRatio >= 0.02) {
        // Alpha น้อยแต่พอมี
        score = 50 + (alphaRatio / 0.05) * 20;
      } else {
        // ไม่มี alpha เลย = น่าสงสัย
        score = max(20, alphaRatio * 1000);
      }

      return score.clamp(0.0, 100.0);
    } catch (e) {
      return 50;
    }
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
