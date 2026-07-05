import 'dart:math';
import '../models/complex_number.dart';

/// IFFT Engine — สร้างสัญญาณกลับโดเมนเวลา
///
/// คุณสมบัติ:
/// - Inverse Cooley-Tukey จาก complex spectrum กลับเป็น time-domain
/// - รักษา phase information (ไม่ใช้แค่ magnitude)
/// - Overlap-Add method สำหรับ continuous reconstruction
/// - Band-specific extraction: แยก alpha/beta signal ออกมาแล้ว IFFT
///
/// อ้างอิง:
/// - Allen (1977) "Short-Term Spectral Analysis, Synthesis, and Modification 
///   by Discrete Fourier Transform"
class EegIfftEngine {
  final int frameSize;
  final int samplingRate;

  EegIfftEngine({
    this.frameSize = 256,
    this.samplingRate = 256,
  });

  // ═══════════════════════════════════════════════════════════════
  //  IFFT — Inverse Cooley-Tukey
  // ═══════════════════════════════════════════════════════════════

  /// Inverse FFT จาก complex spectrum → time-domain signal
  ///
  /// ใช้ trick: IFFT(X) = conj(FFT(conj(X))) / N
  /// ไม่ต้องเขียน IFFT ใหม่ แค่ reuse FFT
  List<double> ifft(List<Complex> spectrum) {
    final n = spectrum.length;

    // 1. Conjugate input
    final conj = List<Complex>.generate(
        n, (i) => spectrum[i].conjugate);

    // 2. Forward FFT on conjugated input
    final fftResult = _fftComplex(conj);

    // 3. Conjugate and divide by N
    return List<double>.generate(
        n, (i) => fftResult[i].conjugate.real / n);
  }

  /// สร้าง time-domain signal จาก spectrum ที่เก็บเฉพาะบาง band
  ///
  /// ตัวอย่าง: แยกเฉพาะ alpha band (8-13 Hz) แล้ว IFFT กลับ
  /// ใช้สำหรับ neurofeedback visualization
  List<double> bandExtract(
      List<Complex> spectrum, double lowFreq, double highFreq) {
    final n = spectrum.length;
    final freqRes = samplingRate / n;

    // Zero-out frequencies นอก band
    final filtered = List<Complex>.generate(n, (i) {
      // Positive frequencies
      if (i < n ~/ 2) {
        final freq = i * freqRes;
        if (freq >= lowFreq && freq <= highFreq) {
          return spectrum[i];
        }
      }
      // Mirror (negative frequencies)
      if (i > n ~/ 2) {
        final mirrorIdx = n - i;
        final freq = mirrorIdx * freqRes;
        if (freq >= lowFreq && freq <= highFreq) {
          return spectrum[i];
        }
      }
      return const Complex.zero();
    });

    return ifft(filtered);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Overlap-Add Reconstruction
  // ═══════════════════════════════════════════════════════════════

  /// Overlap-Add reconstruction จากหลาย frames
  ///
  /// สำหรับ reconstruct continuous signal จาก overlapping windowed frames
  ///
  /// Parameters:
  /// - frames: list of complex spectra (from FFT of windowed segments)
  /// - hopSize: number of samples between frame starts
  ///
  /// Returns: reconstructed time-domain signal
  List<double> overlapAdd(List<List<Complex>> frames, int hopSize) {
    if (frames.isEmpty) return [];

    final n = frames[0].length;
    final outputLength = (frames.length - 1) * hopSize + n;
    final output = List<double>.filled(outputLength, 0.0);
    final windowSum = List<double>.filled(outputLength, 0.0);

    // Pre-compute Hann window for normalization
    final window = List<double>.generate(
        n, (i) => 0.5 * (1 - cos(2 * pi * i / (n - 1))));

    for (int f = 0; f < frames.length; f++) {
      final start = f * hopSize;
      final reconstructed = ifft(frames[f]);

      for (int i = 0; i < n && start + i < outputLength; i++) {
        // Multiply by window undo effect
        output[start + i] += reconstructed[i] * window[i];
        windowSum[start + i] += window[i] * window[i];
      }
    }

    // Normalize by window sum to compensate for overlap
    for (int i = 0; i < outputLength; i++) {
      if (windowSum[i] > 1e-10) {
        output[i] /= windowSum[i];
      }
    }

    return output;
  }

  /// Extract specific band from continuous signal using STFT → filter → ISTFT
  ///
  /// Short-Time Fourier Transform approach:
  /// 1. Window + FFT แต่ละ frame
  /// 2. Zero-out frequencies นอก band
  /// 3. IFFT + overlap-add reconstruct
  List<double> extractBandContinuous(
      List<double> signal, double lowFreq, double highFreq,
      {double overlap = 0.5}) {
    final n = frameSize;
    final hopSize = (n * (1 - overlap)).round();

    // Compute windowed FFT frames
    final frames = <List<Complex>>[];
    for (int start = 0; start + n <= signal.length; start += hopSize) {
      final segment = signal.sublist(start, start + n);

      // DC removal + window
      double sum = 0;
      for (final v in segment) {
        sum += v;
      }
      final mean = sum / n;

      final windowed = List<Complex>.generate(n, (i) {
        final w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
        return Complex((segment[i] - mean) * w, 0);
      });

      // FFT
      final spectrum = _fftComplex(windowed);

      // Band filter in frequency domain
      final freqRes = samplingRate / n;
      final filtered = List<Complex>.generate(n, (i) {
        if (i < n ~/ 2) {
          final freq = i * freqRes;
          if (freq >= lowFreq && freq <= highFreq) {
            return spectrum[i];
          }
        }
        if (i > n ~/ 2) {
          final mirrorIdx = n - i;
          final freq = mirrorIdx * freqRes;
          if (freq >= lowFreq && freq <= highFreq) {
            return spectrum[i];
          }
        }
        return const Complex.zero();
      });

      frames.add(filtered);
    }

    return overlapAdd(frames, hopSize);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Internal FFT (operates on Complex list)
  // ═══════════════════════════════════════════════════════════════

  List<Complex> _fftComplex(List<Complex> input) {
    final n = input.length;
    var data = List<Complex>.from(input);

    // Bit-reversal
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final temp = data[j];
        data[j] = data[i];
        data[i] = temp;
      }
      int k = n ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }

    // Butterfly stages
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
}
