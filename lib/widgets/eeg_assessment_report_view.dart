import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../services/eeg_assessment_service.dart';
import '../services/eeg_pdf_service.dart';
import 'eeg_risk_gauge.dart';
import 'eeg_topographic_map.dart';

/// ใบสรุปประเมินภาวะซึมเศร้า (qEEG)
class EegAssessmentReportView extends StatelessWidget {
  final Map<String, dynamic> summary;
  final User user;
  final String? recordedAtOverride;
  final bool showActions;

  const EegAssessmentReportView({
    super.key,
    required this.summary,
    required this.user,
    this.recordedAtOverride,
    this.showActions = true,
  });

  TextStyle get _titleStyle => GoogleFonts.notoSansThai(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1a237e),
      );

  TextStyle get _bodyStyle => GoogleFonts.notoSansThai(
        fontSize: 11,
        color: const Color(0xFF424242),
        height: 1.45,
      );

  TextStyle get _smallStyle => GoogleFonts.notoSansThai(
        fontSize: 10,
        color: const Color(0xFF616161),
        height: 1.4,
      );

  Color get _riskColor => EegAssessmentService.riskColor(summary);
  double get _eegIndex => (summary['eegIndex'] as num).toDouble();

  @override
  Widget build(BuildContext context) {
    final userName = user.fullName ?? user.username;
    final age = EegAssessmentService.ageFromBirthDate(user.birthDate);
    final dateStr = EegAssessmentService.formatDate(
      recordedAtOverride ?? summary['recordedAt'] as String?,
    );

    return DefaultTextStyle(
      style: _bodyStyle,
      child: Container(
        color: const Color(0xFFF0F4F8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 560;
                  return narrow
                      ? Column(
                          children: [
                            _patientInfo(userName, age, dateStr),
                            const SizedBox(height: 10),
                            _testInfo(userName),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _patientInfo(userName, age, dateStr)),
                            const SizedBox(width: 10),
                            Expanded(child: _testInfo(userName)),
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 560;
                  return narrow
                      ? Column(
                          children: [
                            _analysisSection(),
                            const SizedBox(height: 12),
                            _riskSection(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _analysisSection()),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: _riskSection()),
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),
              _topoSection(),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 560;
                  return narrow
                      ? Column(
                          children: [
                            _clinicalSection(),
                            const SizedBox(height: 10),
                            _observationsSection(),
                            const SizedBox(height: 10),
                            _recommendationsSection(),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _topoClinicalRow()),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _observationsSection()),
                                const SizedBox(width: 10),
                                Expanded(child: _recommendationsSection()),
                              ],
                            ),
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),
              _footerDisclaimer(),
              if (showActions) ...[
                const SizedBox(height: 16),
                _actionButtons(userName),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }

  Widget _header() {
    return _sectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1a237e).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded, color: Color(0xFF1a237e), size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ใบสรุปประเมินภาวะซึมเศร้า', style: _titleStyle.copyWith(fontSize: 18)),
                Text(
                  'จากการทดสอบสัญญาณสมอง (qEEG)',
                  style: _bodyStyle.copyWith(color: const Color(0xFF00838F), fontWeight: FontWeight.w600),
                ),
                Text('Quantitative EEG Analysis', style: _smallStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientInfo(String userName, int? age, String dateStr) {
    return _infoBox('ข้อมูลผู้รับการประเมิน', [
      'ชื่อ-นามสกุล: $userName',
      if (age != null) 'อายุ: $age ปี',
      'วันที่ประเมิน: $dateStr',
      'รหัสผู้ใช้: ${user.id}',
    ]);
  }

  Widget _testInfo(String userName) {
    return _infoBox('รายละเอียดการทดสอบ', [
      'ประเภท: qEEG',
      'เครื่องมือ: Muse EEG',
      'สภาวะ: หลับตา (Eyes Closed)',
      'ระยะเวลา: 1.5 นาที (90 วินาที)',
      'ผู้ทดสอบ: $userName',
    ]);
  }

  Widget _infoBox(String title, List<String> lines) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: _smallStyle),
              )),
        ],
      ),
    );
  }

  Widget _analysisSection() {
    final bands = [
      ('Delta', '0.5–4 Hz', 'ความง่วง / สมองล้า', summary['deltaZScore'] as double, false),
      ('Theta', '4–8 Hz', 'ครุ่นคิด / อารมณ์', summary['thetaZScore'] as double, false),
      ('Alpha', '8–13 Hz', 'ผ่อนคลาย / สมดุล', summary['alphaZScore'] as double, false),
      ('Beta', '13–30 Hz', 'คิดวิเคราะห์', summary['betaZScore'] as double, false),
      ('High Beta', '30+ Hz', 'เครียด / วิตกกังวล', summary['highBetaZScore'] as double, false),
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ผลวิเคราะห์คลื่นสมอง (เทียบค่าปกติ)', style: _titleStyle),
          const SizedBox(height: 4),
          Text(
            'อ่านง่าย: สีเขียว = ปกติ | ส้ม = ควรติดตาม | แดง = ผิดปกติชัด',
            style: _smallStyle.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          ...bands.map((b) => _bandCard(b.$1, b.$2, b.$3, b.$4)),
          _ratioCard('Alpha Asymmetry', 'ความสมดุลอารมณ์ซีกซ้าย-ขวา',
              summary['alphaAsymmetry'] as double, true),
          _ratioCard('Beta/Theta', 'สมาธิและภาวะซึมเศร้า',
              summary['betaThetaRatio'] as double, false),
        ],
      ),
    );
  }

  Widget _bandCard(String name, String freq, String meaning, double z) {
    final st = EegAssessmentService.zStatus(z);
    final plain = EegAssessmentService.plainInterpretation(z);
    final zLabel = z >= 0 ? '+${z.toStringAsFixed(2)}' : z.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: st.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: st.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name ($freq)', style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                Text(meaning, style: _smallStyle),
                const SizedBox(height: 4),
                Text(plain, style: _smallStyle.copyWith(color: st.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            children: [
              Text('Z-Score', style: _smallStyle),
              Text(zLabel, style: _titleStyle.copyWith(color: st.color, fontSize: 16)),
              Icon(st.icon, color: st.color, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratioCard(String name, String meaning, double value, bool isAsymmetry) {
    final plain = EegAssessmentService.plainRatioInterpretation(name, value);
    final st = isAsymmetry && value.abs() > 0.5
        ? EegAssessmentService.zStatus(1.2)
        : (!isAsymmetry && value > 1.5)
            ? EegAssessmentService.zStatus(1.2)
            : EegAssessmentService.zStatus(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: st.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: st.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: _bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                Text(meaning, style: _smallStyle),
                Text(plain, style: _smallStyle.copyWith(color: st.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(value.toStringAsFixed(2), style: _titleStyle.copyWith(color: st.color, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _riskSection() {
    return _sectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'สรุประดับความเสี่ยงภาวะซึมเศร้า',
            style: _titleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 95,
            child: EegRiskGauge(value: _eegIndex, accentColor: _riskColor),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              summary['riskLevel'] as String,
              style: GoogleFonts.notoSansThai(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _riskColor,
              ),
            ),
          ),
          Text(
            summary['riskLevelEn'] as String,
            style: _smallStyle.copyWith(color: _riskColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'คะแนนดัชนีภาวะซึมเศร้า',
                  style: _smallStyle,
                  textAlign: TextAlign.center,
                ),
                Text('(EEG-Depression Index)', style: _smallStyle.copyWith(fontSize: 9)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_eegIndex.toStringAsFixed(0)} / 100',
                    style: GoogleFonts.notoSansThai(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _riskColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              _riskChip('0–33 ต่ำ', const Color(0xFF4CAF50)),
              _riskChip('34–66 ปานกลาง', const Color(0xFFFF9800)),
              _riskChip('67–100 สูง', const Color(0xFFF44336)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: _smallStyle.copyWith(fontSize: 8, color: color)),
    );
  }

  Widget _topoSection() {
    final avgTheta = summary['avgTheta'] as double;
    final avgAlpha = summary['avgAlpha'] as double;
    final thetaZ = summary['thetaZScore'] as double;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a237e),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'แผนที่การทำงานของสมอง (Topographic Map)',
              style: _titleStyle.copyWith(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EegTopographicMap(
                  title: 'Absolute Power (Theta)',
                  value: avgTheta,
                ),
                const SizedBox(width: 8),
                EegTopographicMap(
                  title: 'Absolute Power (Alpha)',
                  value: avgAlpha,
                ),
                const SizedBox(width: 8),
                EegTopographicMap(
                  title: 'Z-Score (Theta)',
                  value: thetaZ,
                  isZScore: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topoClinicalRow() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _clinicalSection()),
        ],
      );

  Widget _clinicalSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('สรุปความหมายเชิงคลินิก', style: _titleStyle),
          const SizedBox(height: 8),
          Text(EegAssessmentService.clinicalSummary(summary), style: _bodyStyle),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ผลนี้เป็นข้อมูลประกอบ ไม่ใช่การวินิจฉัยโรค ต้องประเมินร่วมกับแพทย์/นักจิตวิทยา',
              style: _smallStyle.copyWith(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _observationsSection() => _listSection(
        'ข้อสังเกต',
        Icons.visibility_outlined,
        EegAssessmentService.observations(summary),
      );

  Widget _recommendationsSection() => _listSection(
        'ข้อเสนอแนะ',
        Icons.checklist_rounded,
        EegAssessmentService.recommendations(summary),
        checklist: true,
      );

  Widget _listSection(String title, IconData icon, List<String> items,
      {bool checklist = false}) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1a237e)),
              const SizedBox(width: 6),
              Text(title, style: _titleStyle),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    checklist ? Icons.check_box_outlined : Icons.fiber_manual_record,
                    size: checklist ? 16 : 8,
                    color: const Color(0xFF1a237e),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item, style: _smallStyle)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a237e),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'หมายเหตุ: ผลการทดสอบนี้ไม่สามารถใช้วินิจฉัยภาวะซึมเศร้าได้โดยลำพัง ต้องนำผลไปประกอบการพิจารณาร่วมกับการประเมินทางคลินิกโดยผู้เชี่ยวชาญเท่านั้น',
              style: GoogleFonts.notoSansThai(
                fontSize: 10,
                color: Colors.white,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(String userName) {
    final display = EegAssessmentService.forDisplay(summary);
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => EegPdfService.sharePdf(display, userName),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
            label: Text('ดาวน์โหลด PDF', style: _bodyStyle.copyWith(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => EegPdfService.printPdf(display, userName),
            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
            label: Text('พิมพ์รายงาน', style: _bodyStyle.copyWith(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a237e),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
