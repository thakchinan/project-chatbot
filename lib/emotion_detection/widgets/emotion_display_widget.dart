import 'package:flutter/material.dart';
import '../models/emotion_result.dart';
import '../models/emotion_type.dart';

class EmotionDisplayWidget extends StatelessWidget {
  final EmotionResult? emotionResult;

  const EmotionDisplayWidget({
    super.key,
    this.emotionResult,
  });

  @override
  Widget build(BuildContext context) {
    if (emotionResult == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('ยังไม่มีข้อมูลอารมณ์'),
        ),
      );
    }

    final emotion = EmotionType.fromString(emotionResult!.emotionType);
    final confidence = emotionResult!.confidence;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emotion.emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              emotion.label,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: confidence,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getConfidenceColor(confidence),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ความมั่นใจ: ${(confidence * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
