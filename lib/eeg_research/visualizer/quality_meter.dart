import 'package:flutter/material.dart';
import '../models/quality_metrics.dart';

/// Quality Meter Widget — แสดงคุณภาพสัญญาณ EEG
///
/// แสดง:
/// - 4 electrode contact indicators (🟢/🟡/🔴)
/// - SNR gauge per channel
/// - Overall artifact rate bar
/// - Research-grade equivalence score (0-100)
class QualityMeter extends StatelessWidget {
  final OverallQuality quality;

  const QualityMeter({
    super.key,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: Color(0xFF00D4AA), size: 18),
              SizedBox(width: 8),
              Text(
                'Signal Quality',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Research-grade score (main indicator)
          _buildResearchScore(),
          const SizedBox(height: 12),

          // Electrode contact status
          _buildContactStatus(),
          const SizedBox(height: 12),

          // Per-channel SNR
          _buildSnrBars(),
          const SizedBox(height: 8),

          // Artifact rate
          _buildArtifactRate(),
          const SizedBox(height: 8),

          // PSD Stability
          _buildPsdStability(),
        ],
      ),
    );
  }

  /// Research-grade equivalence score (main display)
  Widget _buildResearchScore() {
    final score = quality.researchScore;
    final level = quality.researchLevel;
    final label = quality.researchLabel;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            level.color.withOpacity(0.15),
            level.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  level.color.withOpacity(0.3),
                  level.color.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: level.color, width: 2),
            ),
            child: Center(
              child: Text(
                '${score.toStringAsFixed(0)}',
                style: TextStyle(
                  color: level.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Research Score',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: level.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(level.color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Electrode contact status (4 circles)
  Widget _buildContactStatus() {
    final channelNames = ['TP9', 'AF7', 'AF8', 'TP10'];
    final channelLabels = ['หลังหูซ้าย', 'หน้าผากซ้าย', 'หน้าผากขวา', 'หลังหูขวา'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(4, (i) {
        final name = channelNames[i];
        final cq = quality.channels[name];
        final level = cq?.contactQuality ?? QualityLevel.noData;

        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: level.color.withOpacity(0.15),
                border: Border.all(color: level.color, width: 2),
              ),
              child: Icon(
                level.icon,
                color: level.color,
                size: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              channelLabels[i],
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 7,
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Per-channel SNR bars
  Widget _buildSnrBars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SNR',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Avg: ${quality.avgSnrDb.toStringAsFixed(1)} dB',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...['TP9', 'AF7', 'AF8', 'TP10'].map((name) {
          final cq = quality.channels[name];
          final snr = cq?.snrDb ?? 0;
          final level = cq?.snrLevel ?? QualityLevel.noData;

          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    name,
                    style: TextStyle(
                      color: level.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (snr / 20).clamp(0, 1),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation(level.color),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 35,
                  child: Text(
                    '${snr.toStringAsFixed(1)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Artifact rate indicator
  Widget _buildArtifactRate() {
    final rate = quality.overallArtifactRate;
    final percent = (rate * 100).clamp(0, 100);
    Color barColor;
    String label;

    if (rate < 0.10) {
      barColor = const Color(0xFF2ECC71);
      label = 'ดี (<10%)';
    } else if (rate < 0.30) {
      barColor = const Color(0xFFF39C12);
      label = 'พอใช้ (10-30%)';
    } else {
      barColor = const Color(0xFFE74C3C);
      label = 'แย่ (>30%)';
    }

    return Row(
      children: [
        Text(
          'Artifact',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rate.clamp(0, 1),
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: TextStyle(
            color: barColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// PSD Stability indicator
  Widget _buildPsdStability() {
    final stability = quality.psdStability;
    Color color;
    if (stability >= 70) {
      color = const Color(0xFF2ECC71);
    } else if (stability >= 40) {
      color = const Color(0xFFF39C12);
    } else {
      color = const Color(0xFFE74C3C);
    }

    return Row(
      children: [
        Text(
          'PSD Stability',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (stability / 100).clamp(0, 1),
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${stability.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
