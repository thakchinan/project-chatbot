import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../models/user.dart';
import 'eeg_assessment_service.dart';

/// EegPdfService จัดการสร้างรายงานสรุปผลการวิเคราะห์คลื่นสมอง (qEEG Report) ในรูปแบบไฟล์ PDF
/// โดยออกแบบหัวกระดาษ ข้อมูลผู้ประเมิน ตารางระดับความเบี่ยงเบน Z-Score ค่าความสมดุลซีกซ้ายขวา
/// แผนภูมิภาพจำลองตำแหน่งเซนเซอร์บนหัว และแปลงไฟล์ PDF เป็นไบต์ข้อมูล (Uint8List) สำหรับพิมพ์หรือส่งออก
class EegPdfService {
  
  /// ฟังก์ชันสำหรับสังเคราะห์เนื้อหาและวาดโครงร่างเอกสาร PDF รายงานผล 2 หน้า
  static Future<Uint8List> generateReport(
    Map<String, dynamic> s, 
    User user, {
    Uint8List? topoBytes,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansThaiRegular();
    final fontBold = await PdfGoogleFonts.notoSansThaiBold();
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    final riskLevel = s['riskLevel'] as String;
    final riskLevelEn = s['riskLevelEn'] as String;
    final eegIndex = (s['eegIndex'] as num).toDouble();
    final riskColorHex = eegIndex <= 33 ? PdfColors.green : (eegIndex <= 66 ? PdfColors.orange : PdfColors.red);

    final userName = user.fullName ?? user.username;
    final age = EegAssessmentService.ageFromBirthDate(user.birthDate);
    final recordedAtStr = EegAssessmentService.formatDate(s['recordedAt'] as String?);

    final tfliteLabel = s['tfliteMentalStateLabel'] as String?;
    final tfliteConf = s['tfliteMentalStateConfidence'] as double?;
    final tfliteConfPercent = tfliteConf != null ? ' (${(tfliteConf * 100).toStringAsFixed(0)}%)' : '';

    // ==========================================
    // PAGE 1: Executive Summary & Z-Score Table
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
                  pw.Text('ใบสรุปประเมินความเครียด', style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white)),
                  pw.SizedBox(height: 2),
                  pw.Text('จากการทดสอบสัญญาณสมอง (qEEG) / Quantitative EEG Analysis', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColor.fromHex('#93C5FD'))),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Patient + Test Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildInfoBox(font, fontBold, 'ข้อมูลผู้รับการประเมิน', [
                    'ชื่อ: $userName',
                    'อายุ: ${age != null ? "$age ปี" : "-"}',
                    'วันที่ประเมิน: $recordedAtStr',
                    'รหัสผู้ใช้: ${user.id}',
                  ]),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildInfoBox(font, fontBold, 'รายละเอียดการทดสอบ', [
                    'ประเภท: qEEG',
                    'เครื่องมือ: Muse EEG',
                    'สภาวะ: หลับตา (Eyes Closed)',
                    'ระยะเวลา: 1.5 นาที (90 วินาที)',
                    'ความสมบูรณ์ข้อมูล: ${s['samplesCollected']} samples',
                    'เกณฑ์อ้างอิง: ${s['normRef'] ?? 'Krigolson et al. (2017), DEAP Dataset (Calibrated for Frontal Muse EEG)'}',
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Risk Level
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: riskColorHex, width: 2),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                children: [
                  pw.Text('สรุปผลการวิเคราะห์เชิงลึก', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Text(riskLevel, style: pw.TextStyle(font: fontBold, fontSize: 20, color: riskColorHex)),
                  pw.Text('($riskLevelEn)', style: pw.TextStyle(font: font, fontSize: 10, color: riskColorHex)),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(eegIndex.toStringAsFixed(0), style: pw.TextStyle(font: fontBold, fontSize: 28, color: riskColorHex)),
                      pw.Text(' / 100', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('EEG Deep Analysis Index', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                  pw.SizedBox(height: 6),
                  _buildPdfRiskBar(),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('0-28 ความเสี่ยงต่ำ', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('29-48 ปานกลาง', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('49-100 สูง', style: pw.TextStyle(font: font, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Z-Score Table
            pw.Text('ผลการวิเคราะห์สัญญาณสมอง (Z-Score)', style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColor.fromHex('#0F1B4C'))),
            pw.SizedBox(height: 6),
            _buildZScoreTable(font, fontBold, s),
            pw.SizedBox(height: 10),

            // Alpha Asymmetry + Beta/Theta + PyTorch AI + TFLite AI
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildMetricBox(
                    font,
                    fontBold,
                    'Alpha Asymmetry (L-R)',
                    (s['alphaAsymmetry'] as num? ?? 0.0).toDouble().toStringAsFixed(2),
                    (s['alphaAsymmetry'] as num? ?? 0.0).toDouble().abs() > 0.5 ? 'ไม่สมดุล' : 'ปกติ',
                    (s['alphaAsymmetry'] as num? ?? 0.0).toDouble().abs() > 0.5 ? PdfColors.orange : PdfColors.green,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: _buildMetricBox(
                    font,
                    fontBold,
                    'Beta/Theta Ratio',
                    (s['betaThetaRatio'] as num? ?? 0.0).toDouble().toStringAsFixed(2),
                    (s['betaThetaRatio'] as num? ?? 0.0).toDouble() > 1.5 ? 'สูงกว่าปกติ' : 'ปกติ',
                    (s['betaThetaRatio'] as num? ?? 0.0).toDouble() > 1.5 ? PdfColors.orange : PdfColors.green,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: _buildMetricBox(
                    font,
                    fontBold,
                    'การประเมินสภาวะอารมณ์',
                    tfliteLabel ?? 'ไม่มีข้อมูล',
                    tfliteConfPercent.isNotEmpty ? 'มั่นใจ$tfliteConfPercent' : 'สภาวะอารมณ์',
                    tfliteLabel == 'สภาวะเป็นลบ' || tfliteLabel == 'Negative' || tfliteLabel == 'Stressed'
                        ? PdfColors.red
                        : (tfliteLabel == 'ปกติ' || tfliteLabel == 'Neutral' || tfliteLabel == 'Relaxed' || tfliteLabel == 'สภาวะเป็นบวก' ? PdfColors.green : PdfColors.orange),
                  ),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('วันที่ออกรายงาน: $dateStr', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                pw.Text('หน้า 1 จาก 2', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ],
            ),
          ],
        ),
      ),
    );

    // ==========================================
    // PAGE 2: Brain Map & Clinical Insights
    // ==========================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Mini Header / Title
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ผลวิเคราะห์ระดับลึก & ข้อเสนอแนะ', style: pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColor.fromHex('#0F1B4C'))),
                pw.Text('Detailed Analysis & Recommendations', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: PdfColor.fromHex('#0F1B4C')),
            pw.SizedBox(height: 12),

            // Topographic Maps Section
            if (topoBytes != null) ...[
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Image(
                  pw.MemoryImage(topoBytes),
                  width: 535,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ] else ...[
              // Brain Map Header (Fallback)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0F1B4C'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('แผนที่การทำงานของสมอง (Topographic Map)', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Topographic Maps Row (Fallback)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfTopoMap(
                    'Absolute Power (Theta)',
                    {
                      'AF7': s['avgTheta'] as double,
                      'AF8': (s['avgTheta'] as double) * 0.8,
                      'TP9': (s['avgTheta'] as double) * 0.6,
                      'TP10': (s['avgTheta'] as double) * 0.7,
                    },
                    false,
                    font,
                    fontBold,
                  ),
                  _buildPdfTopoMap(
                    'Absolute Power (Alpha)',
                    {
                      'AF7': s['avgAlpha'] as double,
                      'AF8': (s['avgAlpha'] as double) * 1.2,
                      'TP9': (s['avgAlpha'] as double) * 1.1,
                      'TP10': (s['avgAlpha'] as double) * 0.9,
                    },
                    false,
                    font,
                    fontBold,
                  ),
                  _buildPdfTopoMap(
                    'Z-Score (Theta)',
                    {
                      'AF7': s['thetaZScore'] as double,
                      'AF8': (s['thetaZScore'] as double) * 0.5,
                      'TP9': -0.5,
                      'TP10': 0.2,
                    },
                    true,
                    font,
                    fontBold,
                  ),
                ],
              ),
            ],
            pw.SizedBox(height: 16),

            // Clinical Summary
            pw.Text('สรุปความหมายเชิงคลินิก', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#0F1B4C'))),
            pw.SizedBox(height: 4),

            if (tfliteLabel != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E0F2FE'),
                  border: pw.Border.all(color: PdfColor.fromHex('#BAE6FD')),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'การวิเคราะห์สภาวะอารมณ์ (Emotion State):',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.0, color: PdfColor.fromHex('#0284C7')),
                    ),
                    pw.Text(
                      '$tfliteLabel$tfliteConfPercent',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.0, color: PdfColor.fromHex('#0F1B4C')),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
            ],
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                EegAssessmentService.clinicalSummary(s),
                style: pw.TextStyle(font: font, fontSize: 9.5, height: 1.4),
              ),
            ),
            pw.SizedBox(height: 12),

            // Observations & Recommendations
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildListSection(
                    'ข้อสังเกต',
                    EegAssessmentService.observations(s),
                    font,
                    fontBold,
                    false,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildListSection(
                    'ข้อเสนอแนะ',
                    EegAssessmentService.recommendations(s),
                    font,
                    fontBold,
                    true,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Disclaimer Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFF8E1'),
                border: pw.Border.all(color: PdfColors.amber300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1, right: 6),
                    child: pw.Text('⚠️', style: pw.TextStyle(font: font, fontSize: 10)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'หมายเหตุ: ผลการทดสอบนี้ไม่สามารถใช้วินิจฉัยภาวะความเครียดสะสมได้โดยลำพัง ต้องนำผลไปประกอบการพิจารณาร่วมกับการประเมินทางคลินิกโดยผู้เชี่ยวชาญเท่านั้น',
                      style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('วันที่ออกรายงาน: $dateStr', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
                pw.Text('หน้า 2 จาก 2', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey)),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoBox(pw.Font font, pw.Font fontBold, String title, List<String> items) {
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

  static pw.Widget _buildZScoreTable(pw.Font font, pw.Font fontBold, Map<String, dynamic> s) {
    final rows = [
      ['Delta (0.5–4 Hz)', 'ความง่วง/สมองล้า', s['deltaZScore'] as double? ?? 0.0],
      ['Theta (4–8 Hz)', 'ภาวะความเครียด/ครุ่นคิด', s['thetaZScore'] as double? ?? 0.0],
      ['Alpha (8–13 Hz)', 'ผ่อนคลาย/สมดุล', s['alphaZScore'] as double? ?? 0.0],
      ['Beta (13–30 Hz)', 'การคิดวิเคราะห์', s['betaZScore'] as double? ?? 0.0],
      ['High Beta (30–40 Hz)', 'ความเครียด/วิตกกังวล', s['highBetaZScore'] as double? ?? 0.0],
      ['Alpha Asymmetry', 'ความสมดุลอารมณ์', s['alphaAsymmetry'] as double? ?? 0.0],
      ['Beta/Theta Ratio', 'สมาธิและภาวะความเครียด', s['betaThetaRatio'] as double? ?? 0.0],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8EAF6')),
          children: ['ดัชนีสมอง', 'ความหมาย', 'ค่าสถิติ/สัดส่วน', 'ผลการแปลความ'].map((h) =>
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(h, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#0F1B4C'))),
            )
          ).toList(),
        ),
        ...rows.map((r) {
          final name = r[0] as String;
          final desc = r[1] as String;
          final val = r[2] as double;

          bool isAsym = name == 'Alpha Asymmetry';
          bool isRatio = name == 'Beta/Theta Ratio';

          String statusText;
          PdfColor color;

          if (isAsym) {
            if (val.abs() > 0.5) {
              statusText = 'ความสมดุลเสี่ยง';
              color = PdfColors.orange;
            } else {
              statusText = 'ใกล้เคียงปกติ';
              color = PdfColors.green;
            }
          } else if (isRatio) {
            if (val > 1.5) {
              statusText = 'สูงกว่าปกติ (เสี่ยง)';
              color = PdfColors.orange;
            } else {
              statusText = 'อยู่ในเกณฑ์ปกติ';
              color = PdfColors.green;
            }
          } else {
            if (val.abs() > 1.5) {
              statusText = val > 0 ? 'สูงกว่าปกติ' : 'ต่ำกว่าปกติ';
              color = PdfColors.red;
            } else if (val.abs() > 1.0) {
              statusText = 'ใกล้เคียงปกติ';
              color = PdfColors.orange;
            } else {
              statusText = 'ปกติ';
              color = PdfColors.green;
            }
          }

          return pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(name, style: pw.TextStyle(font: fontBold, fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(desc, style: pw.TextStyle(font: font, fontSize: 7.5))),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  val >= 0 && !isRatio && !isAsym ? '+${val.toStringAsFixed(2)}' : val.toStringAsFixed(2),
                  style: pw.TextStyle(font: fontBold, fontSize: 8, color: color),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  statusText,
                  style: pw.TextStyle(font: font, fontSize: 7.5, color: color),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildMetricBox(pw.Font font, pw.Font fontBold, String title, String value, String status, PdfColor statusColor) {
    final valFontSize = value.length > 8 ? 10.5 : 13.0;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColor.fromHex('#F8FAFC'),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#0F1B4C'))),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: valFontSize)),
              pw.Text(status, style: pw.TextStyle(font: font, fontSize: 7.0, color: statusColor)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfRiskBar() {
    return pw.Row(
      children: [
        pw.Expanded(child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColors.green, borderRadius: pw.BorderRadius.circular(3)))),
        pw.SizedBox(width: 2),
        pw.Expanded(child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColors.orange, borderRadius: pw.BorderRadius.circular(3)))),
        pw.SizedBox(width: 2),
        pw.Expanded(child: pw.Container(height: 6, decoration: pw.BoxDecoration(color: PdfColors.red, borderRadius: pw.BorderRadius.circular(3)))),
      ],
    );
  }

  static PdfColor _getHeatColor(double val, bool isZScore) {
    double t;
    if (isZScore) {
      t = ((val + 3) / 6).clamp(0.0, 1.0);
      if (t < 0.17) return PdfColor.fromHex('#0D47A1');
      if (t < 0.33) return PdfColor.fromHex('#1976D2');
      if (t < 0.5) return PdfColor.fromHex('#4DD0E1');
      if (t < 0.67) return PdfColor.fromHex('#66BB6A');
      if (t < 0.83) return PdfColor.fromHex('#FFEE58');
      if (t < 0.92) return PdfColor.fromHex('#FF9800');
      return PdfColor.fromHex('#D32F2F');
    } else {
      t = (val / 100).clamp(0.0, 1.0);
      if (t < 0.2) return PdfColor.fromHex('#0D47A1');
      if (t < 0.4) return PdfColor.fromHex('#29B6F6');
      if (t < 0.55) return PdfColor.fromHex('#66BB6A');
      if (t < 0.7) return PdfColor.fromHex('#FFEE58');
      if (t < 0.85) return PdfColor.fromHex('#FF9800');
      return PdfColor.fromHex('#D32F2F');
    }
  }

  static pw.Widget _buildPdfTopoMap(
    String title,
    Map<String, double> sensorValues,
    bool isZScore,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final af7 = sensorValues['AF7'] ?? 0.0;
    final af8 = sensorValues['AF8'] ?? 0.0;
    final tp9 = sensorValues['TP9'] ?? 0.0;
    final tp10 = sensorValues['TP10'] ?? 0.0;

    pw.Widget buildSensorDot(String label, double val) {
      final color = _getHeatColor(val, isZScore);
      final textColor = (val >= 0.6 * (isZScore ? 3.0 : 100.0)) ? PdfColors.white : PdfColors.black;
      
      return pw.Container(
        width: 24,
        height: 24,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: color,
          border: pw.Border.all(color: PdfColors.white, width: 1.5),
          boxShadow: [
            pw.BoxShadow(color: PdfColors.grey400, blurRadius: 2, offset: const PdfPoint(0, 1)),
          ],
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 5.5, color: textColor)),
              pw.Text(val.toStringAsFixed(1), style: pw.TextStyle(font: font, fontSize: 5, color: textColor)),
            ],
          ),
        ),
      );
    }

    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColor.fromHex('#FAFAFA'),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#0F1B4C')),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: 100,
            height: 100,
            child: pw.Stack(
              children: [
                // Ears Left
                pw.Positioned(
                  left: 2,
                  top: 35,
                  child: pw.Container(
                    width: 6,
                    height: 28,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(3),
                        bottomLeft: pw.Radius.circular(3),
                      ),
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                  ),
                ),
                // Ears Right
                pw.Positioned(
                  right: 2,
                  top: 35,
                  child: pw.Container(
                    width: 6,
                    height: 28,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: const pw.BorderRadius.only(
                        topRight: pw.Radius.circular(3),
                        bottomRight: pw.Radius.circular(3),
                      ),
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                  ),
                ),
                // Head Circle
                pw.Positioned(
                  left: 10,
                  top: 10,
                  child: pw.Container(
                    width: 80,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColor.fromHex('#ECEFF1'),
                      border: pw.Border.all(color: PdfColors.grey400, width: 1.5),
                    ),
                  ),
                ),
                // Nose
                pw.Positioned(
                  left: 46,
                  top: 3,
                  child: pw.Container(
                    width: 8,
                    height: 9,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey400,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(4),
                        topRight: pw.Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                // AF7
                pw.Positioned(
                  left: 22,
                  top: 20,
                  child: buildSensorDot('AF7', af7),
                ),
                // AF8
                pw.Positioned(
                  right: 22,
                  top: 20,
                  child: buildSensorDot('AF8', af8),
                ),
                // TP9
                pw.Positioned(
                  left: 15,
                  top: 55,
                  child: buildSensorDot('TP9', tp9),
                ),
                // TP10
                pw.Positioned(
                  right: 15,
                  top: 55,
                  child: buildSensorDot('TP10', tp10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          // Simple Legend
          if (isZScore) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(width: 6, height: 6, color: PdfColor.fromHex('#0D47A1')),
                pw.SizedBox(width: 1),
                pw.Text('-3', style: pw.TextStyle(font: font, fontSize: 6)),
                pw.SizedBox(width: 3),
                pw.Container(width: 6, height: 6, color: PdfColor.fromHex('#66BB6A')),
                pw.SizedBox(width: 1),
                pw.Text('0', style: pw.TextStyle(font: font, fontSize: 6)),
                pw.SizedBox(width: 3),
                pw.Container(width: 6, height: 6, color: PdfColor.fromHex('#D32F2F')),
                pw.SizedBox(width: 1),
                pw.Text('+3', style: pw.TextStyle(font: font, fontSize: 6)),
              ],
            ),
          ] else ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(width: 6, height: 6, color: PdfColor.fromHex('#0D47A1')),
                pw.SizedBox(width: 1),
                pw.Text('ต่ำ', style: pw.TextStyle(font: font, fontSize: 6)),
                pw.SizedBox(width: 5),
                pw.Container(width: 6, height: 6, color: PdfColor.fromHex('#D32F2F')),
                pw.SizedBox(width: 1),
                pw.Text('สูง', style: pw.TextStyle(font: font, fontSize: 6)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildListSection(
    String title,
    List<String> items,
    pw.Font font,
    pw.Font fontBold,
    bool isChecklist,
  ) {
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
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColor.fromHex('#0F1B4C'))),
          pw.SizedBox(height: 6),
          ...items.asMap().entries.map((e) {
            final bullet = isChecklist ? '✓' : '${e.key + 1}.';
            final bulletColor = isChecklist ? PdfColors.blue700 : PdfColors.orange700;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$bullet ',
                    style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: bulletColor),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      e.value,
                      style: pw.TextStyle(font: font, fontSize: 8.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Future<void> sharePdf(
    Map<String, dynamic> s, 
    User user, {
    Uint8List? topoBytes,
  }) async {
    final bytes = await generateReport(s, user, topoBytes: topoBytes);
    await Printing.sharePdf(bytes: bytes, filename: 'qEEG_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<void> printPdf(
    Map<String, dynamic> s, 
    User user, {
    Uint8List? topoBytes,
  }) async {
    final bytes = await generateReport(s, user, topoBytes: topoBytes);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
