import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../widgets/eeg_assessment_report_view.dart';
import 'eeg_report_history_screen.dart';

import '../../theme/app_theme.dart';

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ใบสรุปประเมินความเครียด',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primaryBlue),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: EegAssessmentReportView(
          summary: summary,
          user: user,
          recordedAtOverride: recordedAt,
        ),
      ),
    );
  }
}
