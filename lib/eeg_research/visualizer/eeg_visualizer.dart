import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../models/quality_metrics.dart';
import 'oscilloscope_chart.dart';
import 'psd_chart.dart';
import 'band_power_meter.dart';
import 'quality_meter.dart';

/// EEG Visualizer — รวมทุก chart/widget ไว้ใน widget เดียว
///
/// ประกอบด้วย:
/// - Oscilloscope (time-domain scrolling)
/// - PSD chart (frequency-domain)
/// - Band power meter (5 bands + features)
/// - Quality meter (SNR, artifact, contact)
class EegVisualizer extends StatelessWidget {
  /// Per-channel time-domain data
  final Map<String, List<double>> channels;

  /// PSD curve data
  final List<double> psdCurve;

  /// Frequency resolution
  final double frequencyResolution;

  /// Band power (relative 0-1)
  final Map<String, double> relativePower;

  /// Band power (absolute µV²/Hz)
  final Map<String, double> absolutePower;

  /// Quality assessment
  final OverallQuality quality;

  /// Advanced features
  final double alphaBetaRatio;
  final double thetaAlphaRatio;
  final double sampleEntropy;
  final double spectralEdge95;
  final Map<String, double> coherence;

  const EegVisualizer({
    super.key,
    required this.channels,
    this.psdCurve = const [],
    this.frequencyResolution = 1.0,
    this.relativePower = const {},
    this.absolutePower = const {},
    required this.quality,
    this.alphaBetaRatio = 0,
    this.thetaAlphaRatio = 0,
    this.sampleEntropy = 0,
    this.spectralEdge95 = 0,
    this.coherence = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 1. Oscilloscope — tall view
          SizedBox(
            height: 280,
            child: OscilloscopeChart(channels: channels),
          ),
          const SizedBox(height: 12),

          // 2. PSD + Quality side by side (or stacked on narrow screens)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 220,
                        child: PsdChart(
                          psdCurve: psdCurve,
                          frequencyResolution: frequencyResolution,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: QualityMeter(quality: quality),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PsdChart(
                      psdCurve: psdCurve,
                      frequencyResolution: frequencyResolution,
                    ),
                  ),
                  const SizedBox(height: 12),
                  QualityMeter(quality: quality),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // 3. Band Power Meter
          BandPowerMeter(
            relativePower: relativePower,
            absolutePower: absolutePower,
            alphaBetaRatio: alphaBetaRatio,
            thetaAlphaRatio: thetaAlphaRatio,
            sampleEntropy: sampleEntropy,
            spectralEdge95: spectralEdge95,
            coherence: coherence,
          ),
          const SizedBox(height: 12),

          // 4. Coherence display (if available)
          if (coherence.isNotEmpty) _buildCoherenceCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCoherenceCard() {
    return Container(
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub, color: Color(0xFFFFB347), size: 18),
              SizedBox(width: 8),
              Text(
                'Channel Coherence',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: coherence.entries.map((entry) {
              final value = entry.value;
              Color color;
              if (value > 0.7) {
                color = const Color(0xFF2ECC71);
              } else if (value > 0.4) {
                color = const Color(0xFFF39C12);
              } else {
                color = const Color(0xFFE74C3C);
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      value.toStringAsFixed(2),
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
