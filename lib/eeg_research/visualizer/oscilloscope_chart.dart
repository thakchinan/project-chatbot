import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../theme/app_theme.dart';

/// Real-time scrolling oscilloscope สำหรับ EEG time-domain
///
/// แสดง 4 ช่อง (TP9, AF7, AF8, TP10) แยกแต่ละแถว
/// Scrolling window 5 วินาที (1,280 samples @ 256 Hz)
/// Auto-scale amplitude
class OscilloscopeChart extends StatelessWidget {
  /// Per-channel data {TP9: [...], AF7: [...], ...}
  final Map<String, List<double>> channels;

  /// Visible window duration (seconds)
  final double windowSeconds;

  /// Sampling rate
  final int samplingRate;

  /// Channel colors
  static const Map<String, Color> channelColors = {
    'TP9': Color(0xFF6C63FF),
    'AF7': Color(0xFF00D4AA),
    'AF8': Color(0xFFFF6B6B),
    'TP10': Color(0xFFFFB347),
  };

  const OscilloscopeChart({
    super.key,
    required this.channels,
    this.windowSeconds = 3.0,
    this.samplingRate = 256,
  });

  @override
  Widget build(BuildContext context) {
    final channelNames = ['TP9', 'AF7', 'AF8', 'TP10'];

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
                const Icon(Icons.show_chart, color: AppColors.primaryGreen, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'EEG Oscilloscope',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${windowSeconds.toStringAsFixed(0)}s window',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Channel charts
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: channelNames.map((name) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: _buildChannelTrace(name),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTrace(String channelName) {
    final data = channels[channelName] ?? [];
    final color = channelColors[channelName] ?? Colors.white;
    final maxSamples = (windowSeconds * samplingRate).round();

    // Take last N samples for display
    final displayData = data.length > maxSamples
        ? data.sublist(data.length - maxSamples)
        : data;

    // Auto-scale: compute amplitude range
    double minVal = 0, maxVal = 1;
    if (displayData.isNotEmpty) {
      minVal = displayData.reduce(min);
      maxVal = displayData.reduce(max);
      final range = maxVal - minVal;
      if (range < 1) {
        minVal -= 5;
        maxVal += 5;
      } else {
        minVal -= range * 0.1;
        maxVal += range * 0.1;
      }
    }

    // Downsample for performance (max 300 points per trace)
    const maxPoints = 300;
    final step = max(1, displayData.length ~/ maxPoints);
    final spots = <FlSpot>[];
    for (int i = 0; i < displayData.length; i += step) {
      spots.add(FlSpot(i.toDouble(), displayData[i]));
    }

    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            channelName,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: spots.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'ไม่มีข้อมูล',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 9,
                      ),
                    ),
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxVal - minVal) / 3,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.black.withValues(alpha: 0.04),
                        strokeWidth: 0.5,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.15,
                        color: color,
                        barWidth: 1.2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.05),
                        ),
                      ),
                    ],
                    minY: minVal,
                    maxY: maxVal,
                    lineTouchData: const LineTouchData(enabled: false),
                    clipData: const FlClipData.all(),
                  ),
                  duration: const Duration(milliseconds: 0),
                ),
        ),
      ],
    );
  }
}
