import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Band Power Meter — แสดง 5 แถบ band power พร้อมสีและ features
///
/// แสดง:
/// - Delta, Theta, Alpha, Beta, Gamma เป็น horizontal bars
/// - Animated transitions
/// - Relative % labels
/// - Advanced features: α/β ratio, θ/α ratio, entropy, coherence
class BandPowerMeter extends StatelessWidget {
  /// Relative band powers (0.0-1.0)
  final Map<String, double> relativePower;

  /// Absolute band powers (µV²/Hz) — optional, for tooltip
  final Map<String, double> absolutePower;

  /// Alpha/Beta ratio
  final double alphaBetaRatio;

  /// Theta/Alpha ratio
  final double thetaAlphaRatio;

  /// Sample entropy
  final double sampleEntropy;

  /// Spectral edge frequency 95%
  final double spectralEdge95;

  /// Channel coherence (optional)
  final Map<String, double> coherence;

  /// Band definitions with colors and icons
  static const List<Map<String, dynamic>> _bandDefs = [
    {
      'key': 'delta',
      'label': 'Delta (δ)',
      'range': '1-4 Hz',
      'color': Color(0xFF9B59B6),
      'desc': 'หลับสนิท / ฟื้นฟู',
    },
    {
      'key': 'theta',
      'label': 'Theta (θ)',
      'range': '4-8 Hz',
      'color': Color(0xFF3498DB),
      'desc': 'ความง่วง / สมาธิลึก',
    },
    {
      'key': 'alpha',
      'label': 'Alpha (α)',
      'range': '8-13 Hz',
      'color': Color(0xFF2ECC71),
      'desc': 'ผ่อนคลาย / สงบ',
    },
    {
      'key': 'beta',
      'label': 'Beta (β)',
      'range': '13-30 Hz',
      'color': Color(0xFFE67E22),
      'desc': 'คิดวิเคราะห์ / เครียด',
    },
    {
      'key': 'gamma',
      'label': 'Gamma (γ)',
      'range': '30-45 Hz',
      'color': Color(0xFFE74C3C),
      'desc': 'ประมวลผลสูง / ตื่นตัว',
    },
  ];

  const BandPowerMeter({
    super.key,
    required this.relativePower,
    this.absolutePower = const {},
    this.alphaBetaRatio = 0,
    this.thetaAlphaRatio = 0,
    this.sampleEntropy = 0,
    this.spectralEdge95 = 0,
    this.coherence = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.equalizer, color: Color(0xFFFF6B6B), size: 18),
              SizedBox(width: 8),
              Text(
                'Band Power',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Band power bars
          ..._bandDefs.map((def) => _buildBar(def)),

          const SizedBox(height: 12),
          Divider(color: Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 8),

          // Feature indicators
          _buildFeatureRow(),
        ],
      ),
    );
  }

  Widget _buildBar(Map<String, dynamic> def) {
    final key = def['key'] as String;
    final label = def['label'] as String;
    final range = def['range'] as String;
    final color = def['color'] as Color;

    final value = relativePower[key] ?? 0;
    final percent = (value * 100).clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                range,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 9,
                ),
              ),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Stack(
            children: [
              // Background
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Value bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color],
                  ),
                ),
                // Clip to percentage
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (percent / 100).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.7), color],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildFeatureChip('α/β', alphaBetaRatio, const Color(0xFF2ECC71)),
        _buildFeatureChip('θ/α', thetaAlphaRatio, const Color(0xFF3498DB)),
        _buildFeatureChip('SampEn', sampleEntropy, const Color(0xFF9B59B6)),
        _buildFeatureChip('SEF95', spectralEdge95, const Color(0xFFE67E22),
            unit: 'Hz'),
      ],
    );
  }

  Widget _buildFeatureChip(String label, double value, Color color,
      {String unit = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${value.toStringAsFixed(2)}$unit',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
