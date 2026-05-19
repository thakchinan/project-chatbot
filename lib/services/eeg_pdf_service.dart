import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class EegPdfService {
  static Future<Uint8List> generateReport(Map<String, dynamic> s, String userName) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansThaiRegular();
    final fontBold = await PdfGoogleFonts.notoSansThaiBold();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    final riskLevel = s['riskLevel'] as String;
    final riskLevelEn = s['riskLevelEn'] as String;
    final eegIndex = (s['eegIndex'] as double);
    final riskColorHex = eegIndex <= 33 ? PdfColors.green : (eegIndex <= 66 ? PdfColors.orange : PdfColors.red);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1a237e'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(children: [
                pw.Text('ใบสรุปประเมินภาวะซึมเศร้า', style: pw.TextStyle(font: fontBold, fontSize: 20, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('จากการทดสอบสัญญาณสมอง (qEEG)', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.white)),
              ]),
            ),
            pw.SizedBox(height: 16),

            // Patient + Test Info
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: _buildInfoBox(font, fontBold, 'ข้อมูลผู้รับการประเมิน', [
                'ชื่อ: $userName', 'วันที่ประเมิน: $dateStr',
              ])),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _buildInfoBox(font, fontBold, 'รายละเอียดการทดสอบ', [
                'ประเภท: Quantitative EEG (qEEG)', 'เครื่องมือ: Muse EEG System',
                'ความยาวสัญญาณ: 1.5 นาที (90s)', 'Samples: ${s['samplesCollected']}',
              ])),
            ]),
            pw.SizedBox(height: 16),

            // Z-Score Table
            pw.Text('ผลการวิเคราะห์สัญญาณสมอง (Z-Score)', style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColor.fromHex('#1a237e'))),
            pw.SizedBox(height: 8),
            _buildZScoreTable(font, fontBold, s),
            pw.SizedBox(height: 12),

            // Alpha Asymmetry + Beta/Theta
            pw.Row(children: [
              pw.Expanded(child: _buildMetricBox(font, fontBold, 'Alpha Asymmetry (ซ้าย-ขวา)', (s['alphaAsymmetry'] as double).toStringAsFixed(2),
                  (s['alphaAsymmetry'] as double).abs() > 0.5 ? 'เข้าข่ายเสี่ยง' : 'ใกล้เคียงปกติ')),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _buildMetricBox(font, fontBold, 'Beta/Theta Ratio', (s['betaThetaRatio'] as double).toStringAsFixed(2),
                  (s['betaThetaRatio'] as double) > 1.5 ? 'เข้าข่ายเสี่ยง' : 'ปกติ')),
            ]),
            pw.SizedBox(height: 16),

            // Risk Level
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: riskColorHex, width: 2), borderRadius: pw.BorderRadius.circular(10)),
              child: pw.Column(children: [
                pw.Text('สรุประดับความเสี่ยงภาวะซึมเศร้า', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                pw.SizedBox(height: 8),
                pw.Text(riskLevel, style: pw.TextStyle(font: fontBold, fontSize: 22, color: riskColorHex)),
                pw.Text('($riskLevelEn)', style: pw.TextStyle(font: font, fontSize: 11, color: riskColorHex)),
                pw.SizedBox(height: 8),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Text('${eegIndex.toStringAsFixed(0)}', style: pw.TextStyle(font: fontBold, fontSize: 32, color: riskColorHex)),
                  pw.Text(' / 100', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey)),
                ]),
                pw.SizedBox(height: 6),
                pw.Text('EEG–Depression Index', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                pw.SizedBox(height: 8),
                _buildPdfRiskBar(),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('0-33 ความเสี่ยงต่ำ', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text('34-66 ปานกลาง', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text('67-100 สูง', style: pw.TextStyle(font: font, fontSize: 8)),
                ]),
              ]),
            ),
            pw.SizedBox(height: 16),

            // Clinical note
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF8E1'), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('หมายเหตุ', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text('ผลการทดสอบนี้ไม่สามารถใช้วินิจฉัยภาวะซึมเศร้าได้โดยลำพัง ต้องนำผลไปประกอบการพิจารณาร่วมกับการประเมินทางคลินิกโดยผู้เชี่ยวชาญเท่านั้น',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ]),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text('วันที่ออกรายงาน: $dateStr', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey)),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoBox(pw.Font font, pw.Font fontBold, String title, List<String> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#1a237e'))),
        pw.SizedBox(height: 6),
        ...items.map((i) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(i, style: pw.TextStyle(font: font, fontSize: 10)))),
      ]),
    );
  }

  static pw.Widget _buildZScoreTable(pw.Font font, pw.Font fontBold, Map<String, dynamic> s) {
    final rows = [
      ['Delta (0.5–4 Hz)', 'ความง่วง/สมองล้า', s['deltaZScore'], s['avgDelta']],
      ['Theta (4–8 Hz)', 'ภาวะซึมเศร้า/ครุ่นคิด', s['thetaZScore'], s['avgTheta']],
      ['Alpha (8–13 Hz)', 'ผ่อนคลาย/สมดุล', s['alphaZScore'], s['avgAlpha']],
      ['Beta (13–30 Hz)', 'การคิดวิเคราะห์', s['betaZScore'], s['avgBeta']],
      ['High Beta (30–40 Hz)', 'ความเครียด/วิตกกังวล', s['highBetaZScore'], s['avgGamma']],
      ['Alpha Asymmetry', 'ความสมดุลอารมณ์', s['alphaAsymmetry'], 0.0],
      ['Beta/Theta Ratio', 'สมาธิและภาวะซึมเศร้า', s['betaThetaRatio'], 0.0],
    ];

    String getStatus(double z) {
      if (z.abs() > 1.5) return z > 0 ? 'สูงกว่าปกติ' : 'ต่ำกว่าปกติ';
      if (z.abs() > 1.0) return 'ใกล้เคียงปกติ';
      return 'ปกติ';
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(2.5), 2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.8)},
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8EAF6')),
          children: ['ดัชนีสมอง', 'ความหมาย', 'ค่า Z-Score', 'ผลการแปลความ'].map((h) =>
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 9)))
          ).toList(),
        ),
        ...rows.map((r) {
          final z = r[2] as double;
          final zColor = z.abs() > 1.5 ? PdfColors.red : (z.abs() > 1.0 ? PdfColors.orange : PdfColors.green);
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r[0] as String, style: pw.TextStyle(font: fontBold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r[1] as String, style: pw.TextStyle(font: font, fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(z >= 0 ? '+${z.toStringAsFixed(2)}' : z.toStringAsFixed(2), style: pw.TextStyle(font: fontBold, fontSize: 9, color: zColor), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(getStatus(z), style: pw.TextStyle(font: font, fontSize: 8, color: zColor))),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _buildMetricBox(pw.Font font, pw.Font fontBold, String title, String value, String status) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColor.fromHex('#1a237e'))),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 18)),
        pw.Text(status, style: pw.TextStyle(font: font, fontSize: 9)),
      ]),
    );
  }

  static pw.Widget _buildPdfRiskBar() {
    return pw.Row(children: [
      pw.Expanded(child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColors.green, borderRadius: pw.BorderRadius.circular(3)))),
      pw.SizedBox(width: 2),
      pw.Expanded(child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColors.orange, borderRadius: pw.BorderRadius.circular(3)))),
      pw.SizedBox(width: 2),
      pw.Expanded(child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(3)))),
    ]);
  }

  static Future<void> sharePdf(Map<String, dynamic> s, String userName) async {
    final bytes = await generateReport(s, userName);
    await Printing.sharePdf(bytes: bytes, filename: 'qEEG_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<void> printPdf(Map<String, dynamic> s, String userName) async {
    final bytes = await generateReport(s, userName);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
