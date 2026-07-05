import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../widgets/eeg_assessment_report_view.dart';
import 'eeg_report_history_screen.dart';

import '../../theme/app_theme.dart';

/// EegAssessmentReportScreen คือหน้าจอหลักสำหรับห่อหุ้มและแสดงผลใบสรุป qEEG แบบเต็มหน้าจอ
/// ทำหน้าที่เป็น container รองรับการสั่งพ่นไฟล์ภาพออกเป็น PDF และมีปุ่มนำทางด่วนไปดูประวัติรายงานย้อนหลัง
class EegAssessmentReportScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic> summary; // ผลลัพธ์ข้อมูลสรุปที่ได้จากการประเมิน
  final String? recordedAt;           // เวลาที่บันทึกรายงาน
  final int? reportId;                // รหัสอ้างอิงของรายงาน

  const EegAssessmentReportScreen({
    super.key,
    required this.user,
    required this.summary,
    this.recordedAt,
    this.reportId,
  });

  @override
  State<EegAssessmentReportScreen> createState() => _EegAssessmentReportScreenState();
}

class _EegAssessmentReportScreenState extends State<EegAssessmentReportScreen> {
  final GlobalKey<EegAssessmentReportViewState> _reportViewKey = GlobalKey<EegAssessmentReportViewState>();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.glassBackgroundGradient,
      ),
      child: Scaffold(
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
              icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
              tooltip: 'ดาวน์โหลด PDF',
              onPressed: () {
                _reportViewKey.currentState?.handlePdfExport(true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppColors.primaryBlue),
              tooltip: 'ประวัติใบสรุป',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EegReportHistoryScreen(user: widget.user),
                  ),
                );
              },
            ),
          ],
        ),
        body: EegAssessmentReportView(
          key: _reportViewKey,
          summary: widget.summary,
          user: widget.user,
          recordedAtOverride: widget.recordedAt,
        ),
      ),
    );
  }
}
