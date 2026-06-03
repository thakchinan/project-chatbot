import 'dart:math';

/// Complex number สำหรับ FFT/IFFT — เก็บทั้ง real + imaginary
///
/// สำคัญมากสำหรับ research-grade EEG:
/// - ถ้าใช้แค่ magnitude จะสูญเสีย phase information
/// - Phase สำคัญสำหรับ IFFT reconstruction, coherence, connectivity analysis
/// - Channel coherence ต้องใช้ cross-spectral density (ต้อง complex)
class Complex {
  final double real;
  final double imag;

  const Complex(this.real, this.imag);
  const Complex.zero() : real = 0, imag = 0;
  const Complex.one() : real = 1, imag = 0;
  const Complex.i() : real = 0, imag = 1;

  /// สร้างจาก polar coordinates: r * e^(i*theta)
  factory Complex.fromPolar(double r, double theta) {
    return Complex(r * cos(theta), r * sin(theta));
  }

  /// |z| = sqrt(real² + imag²)
  double get magnitude => sqrt(real * real + imag * imag);

  /// |z|² = real² + imag² (เร็วกว่า magnitude เพราะไม่ต้อง sqrt)
  double get magnitudeSquared => real * real + imag * imag;

  /// Phase angle: atan2(imag, real) ∈ [-π, π]
  double get phase => atan2(imag, real);

  /// Complex conjugate: a - bi
  Complex get conjugate => Complex(real, -imag);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);

  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);

  /// (a+bi)(c+di) = (ac-bd) + (ad+bc)i
  Complex operator *(Complex other) => Complex(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  /// Scalar multiplication
  Complex scale(double s) => Complex(real * s, imag * s);

  /// Complex division: z1/z2 = z1 * conj(z2) / |z2|²
  Complex operator /(Complex other) {
    final denom = other.magnitudeSquared;
    if (denom == 0) return const Complex.zero();
    return Complex(
      (real * other.real + imag * other.imag) / denom,
      (imag * other.real - real * other.imag) / denom,
    );
  }

  /// e^(i*theta) — Euler's formula
  static Complex exp(Complex z) {
    final er = math_exp(z.real);
    return Complex(er * cos(z.imag), er * sin(z.imag));
  }

  /// Twiddle factor สำหรับ FFT: e^(-2πi*k/N)
  /// ใช้บ่อยมากใน Cooley-Tukey algorithm
  static Complex twiddle(int k, int n) {
    final angle = -2.0 * pi * k / n;
    return Complex(cos(angle), sin(angle));
  }

  @override
  String toString() {
    if (imag >= 0) return '${real.toStringAsFixed(4)} + ${imag.toStringAsFixed(4)}i';
    return '${real.toStringAsFixed(4)} - ${(-imag).toStringAsFixed(4)}i';
  }

  @override
  bool operator ==(Object other) =>
      other is Complex &&
      (real - other.real).abs() < 1e-10 &&
      (imag - other.imag).abs() < 1e-10;

  @override
  int get hashCode => Object.hash(real, imag);
}

/// dart:math exp — avoid name collision
double math_exp(double x) => exp(x);
