import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../theme/app_theme.dart';

/// Power Spectral Density (PSD) Chart
///
/// แสดง PSD curve พร้อม color-coded frequency bands:
/// - Delta (1-4 Hz) = purple
/// - Theta (4-8 Hz) = blue
/// - Alpha (8-13 Hz) = green
/// - Beta (13-30 Hz) = orange
/// - Gamma (30-45 Hz) = red
class PsdChart extends StatelessWidget {
  /// PSD curve values (µV²/Hz)
  final List<double> psdCurve;

  /// Frequency resolution (Hz per bin)
  final double frequencyResolution;

  /// Use logarithmic Y-axis
  final bool logScale;

  /// Band power colors
  static const Map<String, Color> bandColors = {
    'delta': Color(0xFF9B59B6),
    'theta': Color(0xFF3498DB),
    'alpha': Color(0xFF2ECC71),
    'beta': Color(0xFFE67E22),
    'gamma': Color(0xFFE74C3C),
  };

  static const Map<String, List<double>> bandRanges = {
    'delta': [1.0, 4.0],
    'theta': [4.0, 8.0],
    'alpha': [8.0, 13.0],
    'beta': [13.0, 30.0],
    'gamma': [30.0, 45.0],
  };

  const PsdChart({
    super.key,
    required this.psdCurve,
    this.frequencyResolution = 1.0,
    this.logScale = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Power Spectrum (PSD)',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Band legend
                ..._buildLegend(),
              ],
            ),
          ),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
              child: _buildChart(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLegend() {
    return bandColors.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              entry.key[0].toUpperCase(),
              style: TextStyle(
                color: entry.value,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildChart() {
    if (psdCurve.isEmpty) {
      return const Center(
        child: Text(
          'รอข้อมูล...',
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }

    // Max frequency to display
    const maxFreq = 50.0;
    final maxBin = min(psdCurve.length, (maxFreq / frequencyResolution).ceil());

    // Create spots with band-colored sections
    final barGroups = <BarChartGroupData>[];

    // Downsample if too many bins
    final step = max(1, maxBin ~/ 50);

    for (int i = 1; i < maxBin; i += step) {
      final freq = i * frequencyResolution;
      if (freq > maxFreq) break;

      // Average power in this bin range
      double avgPower = 0;
      int count = 0;
      for (int j = i; j < min(i + step, maxBin); j++) {
        avgPower += psdCurve[j];
        count++;
      }
      avgPower = count > 0 ? avgPower / count : 0;

      // Apply log scale if needed
      final displayVal = logScale && avgPower > 0
          ? log(avgPower) / ln10 + 6 // Offset for positive values
          : avgPower;

      // Get band color
      Color barColor = Colors.grey;
      for (final band in bandRanges.entries) {
        if (freq >= band.value[0] && freq < band.value[1]) {
          barColor = bandColors[band.key]!;
          break;
        }
      }

      barGroups.add(
        BarChartGroupData(
          x: (freq * 10).round(),
          barRods: [
            BarChartRodData(
              toY: max(0, displayVal),
              color: barColor.withValues(alpha: 0.8),
              width: max(2, 200 / maxBin * step),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                color: barColor.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: null,
          verticalInterval: 100,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.black.withValues(alpha: 0.04),
            strokeWidth: 0.5,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: Colors.black.withValues(alpha: 0.04),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            axisNameWidget: const Text(
              'Hz',
              style: TextStyle(color: AppColors.textGray, fontSize: 10),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final freq = value / 10;
                if (freq == 1 || freq == 8 || freq == 13 ||
                    freq == 30 || freq == 45) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${freq.toInt()}',
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 9,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            left: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }
}
