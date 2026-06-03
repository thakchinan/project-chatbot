import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../models/user.dart';

class WeeklyReportPdfService {
  static Future<Uint8List> generate(Map<String, dynamic> report, User user) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansThaiRegular();
    final fontBold = await PdfGoogleFonts.notoSansThaiBold();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    final eeg = report['eeg'] as Map<String, dynamic>;
    final mood = report['mood'] as Map<String, dynamic>;
    final stress = report['stress'] as Map<String, dynamic>;
    final activity = report['activity'] as Map<String, dynamic>;
    final alerts = (report['alerts'] as List).cast<Map<String, dynamic>>();
    final carePlan = (report['carePlan'] as List).cast<String>();
    final aiSummary = report['aiSummary']?.toString() ?? report['insight']?.toString() ?? '';
    final userName = user.fullName ?? user.username;

    final periodStart = report['periodStart'];
    final periodEnd = report['periodEnd'];
    final periodStr = periodStart is DateTime && periodEnd is DateTime
        ? '${periodStart.day}/${periodStart.month}/${periodStart.year} - ${periodEnd.day}/${periodEnd.month}/${periodEnd.year}'
        : 'สัปดาห์ล่าสุด';

    // ==========================================
    // PAGE 1: Summary + EEG Data + Alerts
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0F1B4C'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('รายงานสุขภาพสมองและอารมณ์รายสัปดาห์',
                      style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
                  pw.SizedBox(height: 2),
                  pw.Text('AI Weekly Health Report / SmartBrain Care',
                      style: pw.TextStyle(font: font, fontSize: 11, color: PdfColor.fromHex('#93C5FD'))),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Patient + Period Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _infoBox(font, fontBold, 'ข้อมูลผู้ใช้', [
                    'ชื่อ: $userName',
                    'รหัส: ${user.id}',
                    'วันที่ออกรายงาน: $dateStr',
                  ]),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _infoBox(font, fontBold, 'ช่วงเวลา', [
                    'ช่วง: $periodStr',
                    'ตัวอย่าง EEG: ${report['brainwaveCount']}',
                    'บันทึกอารมณ์: ${report['emotionCount']}',
                    'กิจกรรม: ${activity['sessions']} ครั้ง (${activity['minutes']} นาที)',
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // AI Summary
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EEF2FF'),
                border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE')),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('สรุปภาพรวมโดย AI', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#4F46E5'))),
                  pw.SizedBox(height: 6),
                  pw.Text(aiSummary, style: pw.TextStyle(font: font, fontSize: 10, height: 1.5)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // EEG Data Table
            pw.Text('ข้อมูลคลื่นสมองเฉลี่ย', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColor.fromHex('#0F1B4C'))),
            pw.SizedBox(height: 6),
            _eegTable(font, fontBold, eeg),
            pw.SizedBox(height: 12),

            // Metric summary row
            pw.Row(
              children: [
                pw.Expanded(child: _metricBox(font, fontBold, 'Stress Index', _f(eeg['stressIndex']), eeg['label'].toString(), _statusColor(eeg['stressIndex']))),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _metricBox(font, fontBold, 'Sleep Score', _f(eeg['sleepScore']), eeg['sleepTrend']?.toString() ?? '-', PdfColors.blue)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _metricBox(font, fontBold, 'อารมณ์หลัก', mood['topEmotion'].toString(), 'เข้มข้นเฉลี่ย ${_f(mood['avgIntensity'])}', PdfColors.purple)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _metricBox(font, fontBold, 'ผลประเมิน', stress['latestLevel'].toString(), 'คะแนนเฉลี่ย ${_f(stress['avgScore'])}', PdfColors.orange)),
              ],
            ),
            pw.Spacer(),
            _footer(font, dateStr, '1'),
          ],
        ),
      ),
    );

    // ==========================================
    // PAGE 2: Alerts + Care Plan + Disclaimer
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('การแจ้งเตือนและแผนดูแล', style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColor.fromHex('#0F1B4C'))),
                pw.Text('Alerts & Care Plan', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: PdfColor.fromHex('#0F1B4C')),
            pw.SizedBox(height: 12),

            // Alerts
            pw.Text('สัญญาณที่ควรเฝ้าระวัง', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#0F1B4C'))),
            pw.SizedBox(height: 6),
            ...alerts.map((alert) => _alertRow(font, fontBold, alert)),
            pw.SizedBox(height: 16),

            // Care Plan
            pw.Text('แผนดูแลสัปดาห์ถัดไป', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#0F1B4C'))),
            pw.SizedBox(height: 6),
            ...carePlan.asMap().entries.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${e.key + 1}. ', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue700)),
                  pw.Expanded(child: pw.Text(e.value, style: pw.TextStyle(font: font, fontSize: 10, height: 1.4))),
                ],
              ),
            )),
            pw.SizedBox(height: 16),

            // High Stress Days
            if (eeg['highStressDays'] is List && (eeg['highStressDays'] as List).isNotEmpty) ...[
              pw.Text('วันที่เครียดสูงสุด', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#0F1B4C'))),
              pw.SizedBox(height: 6),
              pw.Row(
                children: (eeg['highStressDays'] as List).take(3).map((item) {
                  final row = Map<String, dynamic>.from(item as Map);
                  return pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 8),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#FFF3E0'),
                        border: pw.Border.all(color: PdfColors.orange300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(children: [
                        pw.Text(row['day'].toString(), style: pw.TextStyle(font: fontBold, fontSize: 11)),
                        pw.Text('Stress: ${_f(row['stressIndex'])}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.orange800)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Disclaimer
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFF8E1'),
                border: pw.Border.all(color: PdfColors.amber300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'หมายเหตุ: รายงานนี้สร้างขึ้นโดยระบบ AI เพื่อเป็นข้อมูลประกอบการติดตามดูแลผู้สูงอายุ '
                'ไม่สามารถใช้แทนการวินิจฉัยทางการแพทย์ กรุณานำผลไปปรึกษาแพทย์หรือผู้เชี่ยวชาญ',
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800, height: 1.4),
              ),
            ),
            pw.Spacer(),
            _footer(font, dateStr, '2'),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoBox(pw.Font font, pw.Font fontBold, String title, List<String> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColor.fromHex('#F8FAFC'),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#0F1B4C'))),
          pw.SizedBox(height: 4),
          ...items.map((i) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(i, style: pw.TextStyle(font: font, fontSize: 9)),
          )),
        ],
      ),
    );
  }

  static pw.Widget _eegTable(pw.Font font, pw.Font fontBold, Map<String, dynamic> eeg) {
    final rows = [
      ['Alpha (8-13 Hz)', 'ผ่อนคลาย', eeg['alpha']],
      ['Beta (13-30 Hz)', 'ตื่นตัว/เครียด', eeg['beta']],
      ['Theta (4-8 Hz)', 'สมาธิ', eeg['theta']],
      ['Delta (0.5-4 Hz)', 'นอนหลับลึก', eeg['delta']],
      ['Attention', 'สมาธิจดจ่อ', eeg['attention']],
      ['Meditation', 'ผ่อนคลาย', eeg['meditation']],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8EAF6')),
          children: ['คลื่นสมอง', 'ความหมาย', 'ค่าเฉลี่ย'].map((h) =>
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#0F1B4C'))),
            ),
          ).toList(),
        ),
        ...rows.map((r) => pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r[0] as String, style: pw.TextStyle(font: fontBold, fontSize: 8.5))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r[1] as String, style: pw.TextStyle(font: font, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_f(r[2]), style: pw.TextStyle(font: fontBold, fontSize: 9), textAlign: pw.TextAlign.center)),
          ],
        )),
      ],
    );
  }

  static pw.Widget _metricBox(pw.Font font, pw.Font fontBold, String title, String value, String status, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColor.fromHex('#F8FAFC'),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#0F1B4C'))),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 14, color: color)),
          pw.Text(status, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _alertRow(pw.Font font, pw.Font fontBold, Map<String, dynamic> alert) {
    final level = alert['level'];
    final color = level == 'high' ? PdfColors.red : (level == 'medium' ? PdfColors.orange : PdfColors.green);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 8, height: 8,
            decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: color),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(alert['title'].toString(), style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text(alert['message'].toString(), style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Font font, String dateStr, String page) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey300),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SmartBrain Care - AI Weekly Report', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
          pw.Text('วันที่ออกรายงาน: $dateStr | หน้า $page จาก 2', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    ]);
  }

  static PdfColor _statusColor(dynamic value) {
    final v = (value as num?)?.toDouble() ?? 0;
    if (v >= 55) return PdfColors.red;
    if (v >= 35) return PdfColors.orange;
    return PdfColors.green;
  }

  static String _f(dynamic value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return n.toStringAsFixed(1);
  }

  /// Open print preview / share dialog
  static Future<void> printReport(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  /// Share the PDF
  static Future<void> shareReport(Uint8List pdfBytes) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: 'weekly_report.pdf');
  }
}
