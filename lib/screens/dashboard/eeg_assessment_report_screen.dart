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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'ใบสรุปประเมินความเครียด',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F1B4C),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1B4C), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
