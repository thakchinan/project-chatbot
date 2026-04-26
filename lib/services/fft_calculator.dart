import 'dart:math';

class FFTCalculator {

  static List<double> computeMagnitudes(List<double> input) {
    int n = input.length;
    if ((n & (n - 1)) != 0) {
      throw Exception("Input size must be power of 2");
    }

    // 1. หาค่าเฉลี่ย (Mean) เพื่อลบ DC Offset (สำคัญมาก!)
    double sum = 0;
    for (double val in input) sum += val;
    double mean = sum / n;

    List<double> real = List.filled(n, 0.0);
    List<double> imag = List.filled(n, 0.0);

    for (int i = 0; i < n; i++) {
        // 2. ลบ DC Offset ออก แล้วค่อยคูณด้วย Hanning Window
        double multiplier = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
        real[i] = (input[i] - mean) * multiplier;
    }

    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        double tr = real[j]; double ti = imag[j];
        real[j] = real[i]; imag[j] = imag[i];
        real[i] = tr; imag[i] = ti;
      }
      int k = n ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }

    for (int len = 2; len <= n; len *= 2) {
      double ang = -2 * pi / len;
      double wlenR = cos(ang);
      double wlenI = sin(ang);

      for (int i = 0; i < n; i += len) {
        double wR = 1.0;
        double wI = 0.0;
        for (int j = 0; j < len ~/ 2; j++) {
          double uR = real[i + j];
          double uI = imag[i + j];
          double vR = real[i + j + len ~/ 2] * wR - imag[i + j + len ~/ 2] * wI;
          double vI = real[i + j + len ~/ 2] * wI + imag[i + j + len ~/ 2] * wR;

          real[i + j] = uR + vR;
          imag[i + j] = uI + vI;
          real[i + j + len ~/ 2] = uR - vR;
          imag[i + j + len ~/ 2] = uI - vI;

          double tempR = wR * wlenR - wI * wlenI;
          wI = wR * wlenI + wI * wlenR;
          wR = tempR;
        }
      }
    }

    List<double> magnitudes = List.filled(n ~/ 2, 0.0);

    for (int i = 1; i < n ~/ 2; i++) {
        // คำนวณ Magnitude
        magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }

    return magnitudes;
  }

  static Map<String, double> calculateBandPowers(List<double> magnitudes, int samplingRate) {
    int fftSize = magnitudes.length * 2;
    double resolution = samplingRate / fftSize;

    double delta = 0;
    double theta = 0;
    double alpha = 0;
    double beta = 0;
    double gamma = 0;

    for (int i = 0; i < magnitudes.length; i++) {
        double freq = i * resolution;
        // คิดเป็น Power ที่แท้จริง (ยกกำลังสอง) ตามหลักสัญญาณ PSD
        double power = magnitudes[i] * magnitudes[i];

        if (freq >= 1 && freq < 4) delta += power;
        else if (freq >= 4 && freq < 8) theta += power;
        else if (freq >= 8 && freq < 13) alpha += power;
        else if (freq >= 13 && freq < 30) beta += power;
        else if (freq >= 30 && freq < 50) gamma += power;
    }

    return {
        'delta': delta,
        'theta': theta,
        'alpha': alpha,
        'beta': beta,
        'gamma': gamma,
    };
  }
}
