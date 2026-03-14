import 'package:flutter/material.dart';
import '../models/emotion_result.dart';
import '../models/emotion_type.dart';

/// Widget แสดงกราฟแท่งคะแนนอารมณ์ทั้งหมด
class EmotionChartWidget extends StatelessWidget {
  final EmotionResult? emotionResult;

  const EmotionChartWidget({
    super.key,
    this.emotionResult,
  });

  @override
  Widget build(BuildContext context) {
    if (emotionResult == null || emotionResult!.allScores.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('ยังไม่มีข้อมูลกราฟอารมณ์'),
        ),
      );
    }

    final scores = emotionResult!.allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '📊 คะแนนอารมณ์ทั้งหมด',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...scores.map((entry) {
              final emotion = EmotionType.fromString(entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Text(emotion.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        emotion.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getBarColor(entry.value),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${(entry.value * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getBarColor(double value) {
    if (value >= 0.7) return Colors.teal;
    if (value >= 0.4) return Colors.amber;
    return Colors.blueGrey;
  }
}
