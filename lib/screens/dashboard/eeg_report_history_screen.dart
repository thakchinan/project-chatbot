import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/eeg_assessment_service.dart';
import '../../services/eeg_pdf_service.dart';
import 'eeg_assessment_report_screen.dart';

/// EegReportHistoryScreen คือหน้าแสดงประวัติผลการประเมินวิเคราะห์คลื่นสมอง qEEG ทั้งหมดของคนไข้
/// ดึงประวัติรายงานที่บันทึกไว้ในฐานข้อมูล แสดงผลระดับความเสี่ยงของแต่ละรายงาน และความสามารถในการเปิดอ่านหรือแปลงเป็นไฟล์ PDF
class EegReportHistoryScreen extends StatefulWidget {
  final User user;

  const EegReportHistoryScreen({super.key, required this.user});

  @override
  State<EegReportHistoryScreen> createState() => _EegReportHistoryScreenState();
}

class _EegReportHistoryScreenState extends State<EegReportHistoryScreen> {
  bool _loading = true;                     // ใช้แสดงโหลดดิ้งขณะดึงประวัติรายงานจากฐานข้อมูล
  List<Map<String, dynamic>> _reports = []; // อาเรย์สำหรับจัดเก็บข้อมูลรายงานประวัติทั้งหมดที่ดึงขึ้นมาได้

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.getEegAssessmentReports(widget.user.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true && result['reports'] != null) {
        _reports = (result['reports'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } else {
        _reports = [];
      }
    });
  }

  Map<String, dynamic> _summaryFromReport(Map<String, dynamic> row) {
    final data = row['report_data'];
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> _downloadPdf(Map<String, dynamic> summary) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryBlue),
              const SizedBox(height: 16),
              Text(
                'กำลังสร้าง PDF...',
                style: GoogleFonts.prompt(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final display = EegAssessmentService.forDisplay(summary);
      await EegPdfService.sharePdf(display, widget.user, topoBytes: null);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการดาวน์โหลด PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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
            'ประวัติใบสรุป qEEG',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'ยังไม่มีใบสรุป',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ทำการวัดคลื่นสมอง 1.5 นาทีเพื่อสร้างใบสรุป',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = _reports[index];
                      final summary = _summaryFromReport(row);
                      final riskColor = EegAssessmentService.riskColor(summary);
                      final eegIndex = (summary['eegIndex'] as num?)?.toDouble() ??
                          (row['eeg_index'] as num?)?.toDouble() ??
                          0;
                      final riskLevel = summary['riskLevel'] as String? ??
                          row['risk_level'] as String? ??
                          '-';
                      final recordedAt = row['recorded_at']?.toString() ??
                          summary['recordedAt'] as String?;

                      return Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EegAssessmentReportScreen(
                                  user: widget.user,
                                  summary: summary,
                                  recordedAt: recordedAt,
                                  reportId: row['id'] as int?,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.glassDecoration(
                              color: riskColor,
                              opacity: 0.08,
                              borderColor: riskColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: riskColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.psychology_rounded, color: riskColor),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ใบสรุปประเมินความเครียด',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        riskLevel,
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'EEG Index: ${eegIndex.toStringAsFixed(0)}/100',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (recordedAt != null)
                                        Text(
                                          EegAssessmentService.formatDate(recordedAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                                  tooltip: 'ดาวน์โหลด PDF',
                                  onPressed: () => _downloadPdf(summary),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
