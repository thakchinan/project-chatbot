import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../widgets/eeg_assessment_report_view.dart';
import 'eeg_report_history_screen.dart';

/// แสดงใบสรุป qEEG แบบเต็มหน้าจอ (หลังวัด 90 วินาที หรือจากประวัติ)
class EegAssessmentReportScreen extends StatelessWidget {
  final User user;
  final Map<String, dynamic> summary;
  final String? recordedAt;
  final int? reportId;

  const EegAssessmentReportScreen({
    super.key,
    required this.user,
    required this.summary,
    this.recordedAt,
    this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(
          'ใบสรุปประเมินภาวะซึมเศร้า',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'ประวัติใบสรุป',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EegReportHistoryScreen(user: user),
                ),
              );
            },
          ),
        ],
      ),
      body: EegAssessmentReportView(
        summary: summary,
        user: user,
        recordedAtOverride: recordedAt,
      ),
    );
  }
}
