import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/chatgpt_service.dart';

/// WeeklyReportScreen เป็นหน้าจอสรุปสถิติและแนวโน้มสภาวะจิตใจรายสัปดาห์ (AI Weekly Report)
/// ดึงประวัติการบันทึกอารมณ์ ค่าคลื่นสมอง และคะแนน PHQ-9 ย้อนหลัง 7 วัน
/// เพื่อให้ AI Chatbot สังเคราะห์บทวิเคราะห์แนวโน้มสุขภาพจิตและส่งออกรายงาน PDF
class WeeklyReportScreen extends StatefulWidget {
  final User? user;

  const WeeklyReportScreen({super.key, this.user});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  bool _isLoading = true;
  bool _isGeneratingAI = false;

  Map<String, dynamic> _emotionSummary = {};
  List<dynamic> _eegSessions = [];
  List<dynamic> _phq9Results = [];

  List<FlSpot> _chartSpots = [];
  List<String> _chartDates = [];

  String _aiReport = '';
  String _errorMessage = '';

  double get _avgStressIndex {
    final logs = _emotionSummary['logs'] as List? ?? [];
    if (logs.isEmpty) return 0.0;

    double totalWeighted = 0;
    for (final log in logs) {
      final type = (log['emotion_type'] as String? ?? 'happy').toLowerCase();
      final intensity = (log['intensity'] as num?)?.toDouble() ?? 5.0;
      if (type == 'sad' || type == 'anxious' || type == 'angry') {
        totalWeighted += intensity;
      } else {
        totalWeighted += 1.0; // Low stress/depression contribution for happy/calm
      }
    }
    return totalWeighted / logs.length;
  }

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    if (widget.user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่พบข้อมูลผู้ใช้';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = widget.user!.id;

      // 1. Fetch emotion summary (last 7 days)
      final emotionRes = await ApiService.getEmotionSummary(userId);
      if (emotionRes['success'] == true) {
        _emotionSummary = emotionRes;
      }

      // 2. Fetch EEG sessions (last 7 days)
      final eegRes = await SupabaseService.getEEGSessions(userId, limit: 10);
      if (eegRes['success'] == true) {
        _eegSessions = eegRes['sessions'] ?? [];
      }

      // 3. Fetch PHQ-9 test results (last 7 days)
      final phqRes = await ApiService.getTestResults(userId);
      if (phqRes['success'] == true) {
        _phq9Results = phqRes['results'] ?? [];
      }

      // Process chart data
      _processChartData();

      // Load cached AI report
      await _loadCachedAIReport();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'เกิดข้อผิดพลาดในการดึงข้อมูล: $e';
      });
    }
  }

  void _processChartData() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    final dates = <String>[];

    // Generate last 7 dates (from 6 days ago to today)
    final days = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));

    final logs = _emotionSummary['logs'] as List? ?? [];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayStr = '${day.day}/${day.month}';
      dates.add(dayStr);

      // Find logs on this date
      final dayLogs = logs.where((log) {
        final createdAt = log['created_at'];
        if (createdAt == null) return false;
        final logDate = DateTime.parse(createdAt.toString()).toLocal();
        return logDate.year == day.year && logDate.month == day.month && logDate.day == day.day;
      }).toList();

      if (dayLogs.isNotEmpty) {
        // Average intensity
        final avgInt = dayLogs.map((l) => (l['intensity'] as num?)?.toDouble() ?? 5.0).reduce((a, b) => a + b) / dayLogs.length;
        spots.add(FlSpot(i.toDouble(), avgInt));
      } else {
        // Default to a middle baseline (e.g. 5.0) or skip
        spots.add(FlSpot(i.toDouble(), 0)); // 0 represents no log recorded
      }
    }

    _chartSpots = spots;
    _chartDates = dates;
  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/weekly_ai_report_${widget.user!.id}.txt');
  }

  Future<void> _loadCachedAIReport() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final cachedText = await file.readAsString();
        if (cachedText.isNotEmpty) {
          _aiReport = cachedText;
        }
      }
    } catch (e) {
      debugPrint('Error loading cached AI report: $e');
    }
  }

  Future<void> _cacheAIReport(String text) async {
    try {
      final file = await _getCacheFile();
      await file.writeAsString(text);
    } catch (e) {
      debugPrint('Error saving cached AI report: $e');
    }
  }

  Future<void> _generateAIReport() async {
    if (widget.user == null) return;

    setState(() {
      _isGeneratingAI = true;
    });

    final emotionCounts = _emotionSummary['emotion_counts']?.toString() ?? 'ไม่มีการบันทึก';
    final avgIntensity = _avgStressIndex.toStringAsFixed(1);
    final totalLogs = _emotionSummary['total_logs'] ?? 0;

    String eegSessionsStr = '';
    if (_eegSessions.isNotEmpty) {
      eegSessionsStr = _eegSessions.take(5).map((s) {
        final date = DateTime.parse(s['started_at'].toString()).toLocal();
        return '- วันที่ ${date.day}/${date.month}/${date.year} | สมาธิ: ${s['avg_attention_score'] ?? 0}, ผ่อนคลาย: ${s['avg_relaxation_score'] ?? 0}, ความเครียด: ${s['avg_stress_score'] ?? 0}';
      }).join('\n');
    } else {
      eegSessionsStr = 'ไม่มีประวัติคลื่นสมอง EEG ในสัปดาห์นี้';
    }

    String phq9Str = '';
    if (_phq9Results.isNotEmpty) {
      phq9Str = _phq9Results.take(3).map((r) {
        final date = DateTime.parse(r['test_date'].toString()).toLocal();
        return '- วันที่ ${date.day}/${date.month}/${date.year} | คะแนนประเมินความเครียด: ${r['stress_score'] ?? r['depression_score'] ?? 0} (${r['stress_level'] ?? 'ปกติ'})';
      }).join('\n');
    } else {
      phq9Str = 'ไม่มีประวัติทำแบบประเมินความเครียด PHQ-9';
    }

    final prompt = '''
ข้อมูลการบันทึกสุขภาพผู้ใช้ในรอบ 7 วันที่ผ่านมา:
- บันทึกอารมณ์: ทั้งหมด $totalLogs ครั้ง
- สรุปประเภทอารมณ์ที่รู้สึก: $emotionCounts
- ความเข้มข้นอารมณ์เฉลี่ย (ระดับความเครียดเฉลี่ย 1-10): $avgIntensity

บันทึกสถิติคลื่นสมอง EEG (ย้อนหลัง):
$eegSessionsStr

ผลประเมินความเครียดและสุขภาพจิต PHQ-9 (ย้อนหลัง):
$phq9Str

ช่วยเขียนรายงานภาพรวมสุขภาพจิต การวิเคราะห์อารมณ์/พฤติกรรม วิเคราะห์คลื่นสมอง และให้คำแนะนำฟื้นฟูเฉพาะบุคคลในภาษาไทยที่สุภาพ อบอุ่น และเข้าใจง่ายหน่อยครับ
''';

    final result = await ChatGPTService.generateWeeklyReport(promptContent: prompt);

    if (result['success'] == true && result['report'] != null) {
      final reportText = result['report'] as String;
      await _cacheAIReport(reportText);
      if (!mounted) return;
      setState(() {
        _aiReport = reportText;
        _isGeneratingAI = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isGeneratingAI = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'เกิดข้อผิดพลาดในการสร้างรายงาน AI'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansThaiRegular();
    final fontBold = await PdfGoogleFonts.notoSansThaiBold();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final userName = widget.user?.fullName ?? widget.user?.username ?? 'ผู้ใช้งาน';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'รายงานสุขภาพและอารมณ์รายสัปดาห์ (AI Weekly Report)',
                  style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue800),
                ),
                pw.SizedBox(height: 8),
                pw.Text('ชื่อผู้ใช้: $userName | วันที่ออกรายงาน: $dateStr', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                pw.Divider(thickness: 1.5, color: PdfColors.blue800),
                pw.SizedBox(height: 16),
                
                pw.Text('1. สรุปข้อมูลดิบรายสัปดาห์', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900)),
                pw.Bullet(text: 'บันทึกอารมณ์รวม: ${_emotionSummary['total_logs'] ?? 0} ครั้ง (เฉลี่ยระดับความเครียด: ${_avgStressIndex.toStringAsFixed(1)}/10)', style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Bullet(text: 'จำนวน session คลื่นสมอง: ${_eegSessions.length} ครั้ง', style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Bullet(text: 'จำนวนประวัติ PHQ-9: ${_phq9Results.length} ครั้ง', style: pw.TextStyle(font: font, fontSize: 10)),
                
                pw.SizedBox(height: 20),
                pw.Text('2. บทวิเคราะห์และคำแนะนำโดย AI', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue900)),
                pw.SizedBox(height: 8),
                pw.Text(
                  _aiReport.isNotEmpty ? _aiReport : 'ยังไม่มีบทวิเคราะห์สรุป AI (กรุณากดรับรายงาน AI ในแอปพลิเคชันก่อน)',
                  style: pw.TextStyle(font: font, fontSize: 9.5, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รายงานประจำสัปดาห์ AI',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Quick Stats Overview
                        _buildQuickStatsCard(),
                        const SizedBox(height: 20),

                        // Card 2: Trend Chart
                        _buildTrendChartCard(),
                        const SizedBox(height: 20),

                        // Card 3: AI Analysis report
                        _buildAIReportCard(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final totalLogs = _emotionSummary['total_logs'] ?? 0;
    final avgIntensity = _avgStressIndex;
    final eegCount = _eegSessions.length;
    final phq9Count = _phq9Results.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.primaryBlue, size: 24),
              SizedBox(width: 8),
              Text(
                'สรุปสถิติประจำสัปดาห์',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('บันทึกอารมณ์', '$totalLogs ครั้ง', Colors.blue),
              _buildStatItem('ระดับความเครียด', '${avgIntensity.toStringAsFixed(1)}/10', Colors.red),
              _buildStatItem('ตรวจคลื่นสมอง', '$eegCount ครั้ง', Colors.teal),
              _buildStatItem('แบบทดสอบ', '$phq9Count ครั้ง', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textGray),
        ),
      ],
    );
  }

  Widget _buildTrendChartCard() {
    final activeSpots = _chartSpots.where((s) => s.y > 0).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.primaryBlue, size: 24),
              SizedBox(width: 8),
              Text(
                'แนวโน้มสภาวะจิตใจ (ย้อนหลัง 7 วัน)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'ระดับความเข้มข้นความเครียดเฉลี่ยในแต่ละวัน (1 = ปกติ/มีความสุข, 10 = เครียดมาก)',
            style: TextStyle(fontSize: 11, color: AppColors.textGray),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: activeSpots.isEmpty
                ? const Center(
                    child: Text('ยังไม่มีข้อมูลบันทึกอารมณ์เพียงพอในสัปดาห์นี้',
                        style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.15),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 1 || value == 5 || value == 10) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 20,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < _chartDates.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _chartDates[idx],
                                    style: const TextStyle(color: AppColors.textGray, fontSize: 9),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 24,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _chartSpots,
                          isCurved: true,
                          color: AppColors.primaryBlue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology, color: AppColors.primaryBlue, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'บทวิเคราะห์สุขภาพจิตโดย AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ],
              ),
              if (_aiReport.isNotEmpty)
                IconButton(
                  onPressed: _exportToPDF,
                  icon: const Icon(Icons.share, color: AppColors.primaryBlue, size: 20),
                  tooltip: 'ส่งออกเป็น PDF',
                ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
          if (_isGeneratingAI)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('สมาร์ทเบรน AI กำลังวิเคราะห์ข้อมูลสุขภาพประจำสัปดาห์...',
                        style: TextStyle(fontSize: 13, color: AppColors.textGray, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            )
          else if (_aiReport.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('ยังไม่มีบทสรุปสำหรับสัปดาห์นี้',
                        style: TextStyle(color: AppColors.textGray, fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _generateAIReport,
                      icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                      label: const Text('วิเคราะห์สุขภาพด้วย AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aiReport,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _generateAIReport,
                      icon: const Icon(Icons.refresh, size: 18, color: AppColors.primaryBlue),
                      label: const Text('อัปเดต / วิเคราะห์ซ้ำ', style: TextStyle(color: AppColors.primaryBlue)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _exportToPDF,
                      icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                      label: const Text('พิมพ์ / บันทึก PDF', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
