import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../services/eeg_assessment_service.dart';
import '../services/eeg_pdf_service.dart';
import '../emotion_detection/services/emotion_detection_service.dart';
import '../emotion_detection/models/emotion_type.dart';
import 'eeg_risk_gauge.dart';
import 'eeg_topographic_map.dart';

/// ใบสรุปประเมินภาวะซึมเศร้า (qEEG) — Premium Design
class EegAssessmentReportView extends StatefulWidget {
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

  @override
  State<EegAssessmentReportView> createState() => _EegAssessmentReportViewState();
}

class _EegAssessmentReportViewState extends State<EegAssessmentReportView> {
  final GlobalKey _topoKey = GlobalKey();
  late Map<String, dynamic> _localSummary;

  // === Design Tokens ===
  static const _navy = Color(0xFF0F1B4C);
  static const _accent = Color(0xFF3B82F6);
  static const _bgColor = Color(0xFFF1F5F9);
  static const _cardColor = Colors.white;

  TextStyle get _h1 => GoogleFonts.notoSansThai(fontSize: 20, fontWeight: FontWeight.w800, color: _navy);
  TextStyle get _h2 => GoogleFonts.notoSansThai(fontSize: 14, fontWeight: FontWeight.w700, color: _navy);
  TextStyle get _body => GoogleFonts.notoSansThai(fontSize: 12, color: const Color(0xFF334155), height: 1.5);
  TextStyle get _caption => GoogleFonts.notoSansThai(fontSize: 10, color: const Color(0xFF94A3B8), height: 1.4);
  TextStyle get _mono => GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700);

  Color get _riskColor => EegAssessmentService.riskColor(_localSummary);
  double get _eegIndex => (_localSummary['eegIndex'] as num? ?? 50.0).toDouble();

  @override
  void initState() {
    super.initState();
    _localSummary = Map<String, dynamic>.from(widget.summary);
    _checkAndPredictMentalState();
  }

  Future<void> _checkAndPredictMentalState() async {
    if (_localSummary['predictedMentalStateLabel'] == null || _localSummary['tfliteMentalStateLabel'] == null) {
      try {
        final service = EmotionDetectionService();
        await service.loadModel();
        final sessionEegData = {
          'alpha': (_localSummary['avgAlpha'] as num? ?? 0.0).toDouble(),
          'beta': (_localSummary['avgBeta'] as num? ?? 0.0).toDouble(),
          'theta': (_localSummary['avgTheta'] as num? ?? 0.0).toDouble(),
          'delta': (_localSummary['avgDelta'] as num? ?? 0.0).toDouble(),
          'gamma': (_localSummary['avgGamma'] as num? ?? 0.0).toDouble(),
        };
        final results = await service.detectFromEEG(sessionEegData);
        final pytorchResult = results['pytorch'];
        final tfliteResult = results['tflite'];
        if (mounted) {
          setState(() {
            if (pytorchResult != null) {
              _localSummary['predictedMentalState'] = pytorchResult.emotionType;
              _localSummary['predictedMentalStateLabel'] = EmotionType.fromString(pytorchResult.emotionType).label;
              _localSummary['predictedMentalStateConfidence'] = pytorchResult.confidence;
            }
            if (tfliteResult != null) {
              _localSummary['tfliteMentalState'] = tfliteResult.emotionType;
              _localSummary['tfliteMentalStateLabel'] = EmotionType.fromString(tfliteResult.emotionType).label;
              _localSummary['tfliteMentalStateConfidence'] = tfliteResult.confidence;
            }
          });
        }
        service.dispose();
      } catch (e) {
        debugPrint('❌ Error predicting mental state on-the-fly: $e');
      }
    }
  }

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      // Small delay to ensure widget is fully rendered and rasterized
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing topographic map: $e");
      return null;
    }
  }

  Future<void> _handlePdfExport(bool isShare) async {
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
              const CircularProgressIndicator(color: _navy),
              const SizedBox(height: 16),
              Text(
                'กำลังบันทึกรายงาน PDF...',
                style: GoogleFonts.notoSansThai(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final topoBytes = await _capturePng(_topoKey);

      if (mounted) {
        Navigator.of(context).pop();
      }

      final display = EegAssessmentService.forDisplay(_localSummary);
      if (isShare) {
        await EegPdfService.sharePdf(display, widget.user, topoBytes: topoBytes);
      } else {
        await EegPdfService.printPdf(display, widget.user, topoBytes: topoBytes);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      debugPrint("Error exporting PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เกิดข้อผิดพลาดในการบันทึก PDF: $e',
              style: GoogleFonts.notoSansThai(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user.fullName ?? widget.user.username;
    final age = EegAssessmentService.ageFromBirthDate(widget.user.birthDate);
    final dateStr = EegAssessmentService.formatDate(widget.recordedAtOverride ?? _localSummary['recordedAt'] as String?);

    return DefaultTextStyle(
      style: _body,
      child: Container(
        color: _bgColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 16),
              _buildResponsive((narrow) => narrow
                  ? Column(children: [_patientCard(userName, age, dateStr), const SizedBox(height: 12), _testCard(userName)])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _patientCard(userName, age, dateStr)),
                      const SizedBox(width: 12),
                      Expanded(child: _testCard(userName)),
                    ])),
              const SizedBox(height: 16),
              _buildResponsive((narrow) => narrow
                  ? Column(children: [_analysisSection(), const SizedBox(height: 16), _riskSection()])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 3, child: _analysisSection()),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _riskSection()),
                    ])),
              const SizedBox(height: 16),
              _topoSection(),
              const SizedBox(height: 16),
              _buildResponsive((narrow) => narrow
                  ? Column(children: [_clinicalSection(), const SizedBox(height: 12), _observationsSection(), const SizedBox(height: 12), _recommendationsSection()])
                  : Column(children: [
                      _clinicalSection(),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _observationsSection()),
                        const SizedBox(width: 12),
                        Expanded(child: _recommendationsSection()),
                      ]),
                    ])),
              const SizedBox(height: 16),
              _footerDisclaimer(),
              if (widget.showActions) ...[const SizedBox(height: 20), _actionButtons()],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsive(Widget Function(bool narrow) builder) {
    return LayoutBuilder(builder: (_, c) => builder(c.maxWidth < 560));
  }

  // === Cards ===
  Widget _card({required Widget child, EdgeInsets? padding, List<Color>? gradient}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient != null ? LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: gradient == null ? _cardColor : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  // === Header ===
  Widget _header() {
    return _card(
      gradient: const [Color(0xFF0F1B4C), Color(0xFF1E3A8A)],
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ใบสรุปประเมินภาวะซึมเศร้า', style: _h1.copyWith(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 2),
                Text('จากการทดสอบสัญญาณสมอง (qEEG)', style: _body.copyWith(color: const Color(0xFF93C5FD), fontWeight: FontWeight.w600)),
                Text('Quantitative EEG Analysis', style: _caption.copyWith(color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === Info Cards ===
  Widget _patientCard(String name, int? age, String dateStr) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.person_rounded, 'ข้อมูลผู้รับการประเมิน'),
        const SizedBox(height: 10),
        _infoRow('ชื่อ-นามสกุล', name),
        if (age != null) _infoRow('อายุ', '$age ปี'),
        _infoRow('วันที่ประเมิน', dateStr),
        _infoRow('รหัสผู้ใช้', '${widget.user.id}'),
      ]),
    );
  }

  Widget _testCard(String name) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.science_rounded, 'รายละเอียดการทดสอบ'),
        const SizedBox(height: 10),
        _infoRow('ประเภท', 'qEEG'),
        _infoRow('เครื่องมือ', 'Muse EEG'),
        _infoRow('สภาวะ', 'หลับตา (Eyes Closed)'),
        _infoRow('ระยะเวลา', '1.5 นาที (90 วินาที)'),
        _infoRow('ผู้ทดสอบ', name),
      ]),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _accent),
      ),
      const SizedBox(width: 8),
      Text(title, style: _h2),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: _caption.copyWith(fontSize: 11))),
        Expanded(child: Text(value, style: _body.copyWith(fontWeight: FontWeight.w500, fontSize: 11))),
      ]),
    );
  }

  // === Analysis Section ===
  Widget _analysisSection() {
    final bands = [
      ('Delta', '0.5–4 Hz', 'ความง่วง / สมองล้า', (_localSummary['deltaZScore'] as num? ?? 0.0).toDouble(), Icons.bedtime_rounded),
      ('Theta', '4–8 Hz', 'ครุ่นคิด / อารมณ์', (_localSummary['thetaZScore'] as num? ?? 0.0).toDouble(), Icons.waves_rounded),
      ('Alpha', '8–13 Hz', 'ผ่อนคลาย / สมดุล', (_localSummary['alphaZScore'] as num? ?? 0.0).toDouble(), Icons.spa_rounded),
      ('Beta', '13–30 Hz', 'คิดวิเคราะห์', (_localSummary['betaZScore'] as num? ?? 0.0).toDouble(), Icons.bolt_rounded),
      ('High Beta', '30+ Hz', 'เครียด / วิตกกังวล', (_localSummary['highBetaZScore'] as num? ?? 0.0).toDouble(), Icons.electric_bolt_rounded),
    ];

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.analytics_rounded, 'ผลวิเคราะห์คลื่นสมอง'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            _legendDot(Colors.green, 'ปกติ'),
            const SizedBox(width: 12),
            _legendDot(Colors.orange, 'ควรติดตาม'),
            const SizedBox(width: 12),
            _legendDot(Colors.red, 'ผิดปกติ'),
          ]),
        ),
        const SizedBox(height: 12),
        ...bands.map((b) => _bandCard(b.$1, b.$2, b.$3, b.$4, b.$5)),
        _ratioCard('Alpha Asymmetry', 'ความสมดุลอารมณ์ซีกซ้าย-ขวา', (_localSummary['alphaAsymmetry'] as num? ?? 0.0).toDouble(), true),
        _ratioCard('Beta/Theta', 'สมาธิและภาวะซึมเศร้า', (_localSummary['betaThetaRatio'] as num? ?? 0.0).toDouble(), false),
      ]),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: _caption.copyWith(fontSize: 9)),
    ]);
  }

  Widget _bandCard(String name, String freq, String meaning, double z, IconData icon) {
    final st = EegAssessmentService.zStatus(z);
    final plain = EegAssessmentService.plainInterpretation(z);
    final zLabel = z >= 0 ? '+${z.toStringAsFixed(2)}' : z.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: st.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: st.color, width: 4)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: st.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: st.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name ($freq)', style: _body.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(meaning, style: _caption),
            const SizedBox(height: 2),
            Text(plain, style: _caption.copyWith(color: st.color, fontWeight: FontWeight.w600)),
          ]),
        ),
        Column(children: [
          Text('Z-Score', style: _caption.copyWith(fontSize: 8)),
          Text(zLabel, style: _mono.copyWith(color: st.color, fontSize: 18)),
          Icon(st.icon, color: st.color, size: 16),
        ]),
      ]),
    );
  }

  Widget _ratioCard(String name, String meaning, double value, bool isAsym) {
    final plain = EegAssessmentService.plainRatioInterpretation(name, value);
    final st = (isAsym && value.abs() > 0.5) || (!isAsym && value > 1.5)
        ? EegAssessmentService.zStatus(1.2)
        : EegAssessmentService.zStatus(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: st.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: st.color, width: 4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: _body.copyWith(fontWeight: FontWeight.w700)),
            Text(meaning, style: _caption),
            Text(plain, style: _caption.copyWith(color: st.color, fontWeight: FontWeight.w600)),
          ]),
        ),
        Text(value.toStringAsFixed(2), style: _mono.copyWith(color: st.color)),
      ]),
    );
  }

  // === Risk Section ===
  Widget _riskSection() {
    return _card(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sectionTitle(Icons.monitor_heart_rounded, 'สรุประดับความเสี่ยง'),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: EegRiskGauge(value: _eegIndex, accentColor: _riskColor),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(_localSummary['riskLevel'] as String? ?? '-',
              style: GoogleFonts.notoSansThai(fontSize: 22, fontWeight: FontWeight.w800, color: _riskColor)),
        ),
        Text(_localSummary['riskLevelEn'] as String? ?? '-', style: _caption.copyWith(color: _riskColor, fontWeight: FontWeight.w500)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_riskColor.withValues(alpha: 0.08), _riskColor.withValues(alpha: 0.03)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _riskColor.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text('คะแนนดัชนีภาวะซึมเศร้า', style: _caption.copyWith(fontWeight: FontWeight.w500)),
            Text('EEG-Depression Index', style: _caption.copyWith(fontSize: 9)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${_eegIndex.toStringAsFixed(0)} / 100', style: _mono.copyWith(color: _riskColor, fontSize: 32)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _riskChip('0–33 ต่ำ', const Color(0xFF43A047)),
          const SizedBox(width: 6),
          _riskChip('34–66 กลาง', const Color(0xFFF57C00)),
          const SizedBox(width: 6),
          _riskChip('67–100 สูง', const Color(0xFFE53935)),
        ]),
      ]),
    );
  }

  Widget _riskChip(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: _caption.copyWith(fontSize: 9, color: c, fontWeight: FontWeight.w600)),
    );
  }

  // === Topo Section ===
  Widget _topoSection() {
    return RepaintBoundary(
      key: _topoKey,
      child: _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F1B4C), Color(0xFF1E3A8A)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.map_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text('แผนที่การทำงานของสมอง (Topographic Map)',
                  style: _h2.copyWith(color: Colors.white, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              EegTopographicMap(
                title: 'Absolute Power (Theta)', 
                overlayImagePath: 'assets/images/International_10-20_system_for_EEG-MCN.svg.png',
                sensorValues: {
                  'AF7': (_localSummary['avgTheta'] as num? ?? 0.0).toDouble(),
                  'AF8': ((_localSummary['avgTheta'] as num? ?? 0.0).toDouble()) * 0.8,
                  'TP9': ((_localSummary['avgTheta'] as num? ?? 0.0).toDouble()) * 0.6,
                  'TP10': ((_localSummary['avgTheta'] as num? ?? 0.0).toDouble()) * 0.7,
                },
              ),
              const SizedBox(width: 8),
              EegTopographicMap(
                title: 'Absolute Power (Alpha)', 
                overlayImagePath: 'assets/images/International_10-20_system_for_EEG-MCN.svg.png',
                sensorValues: {
                  'AF7': (_localSummary['avgAlpha'] as num? ?? 0.0).toDouble(),
                  'AF8': ((_localSummary['avgAlpha'] as num? ?? 0.0).toDouble()) * 1.2,
                  'TP9': ((_localSummary['avgAlpha'] as num? ?? 0.0).toDouble()) * 1.1,
                  'TP10': ((_localSummary['avgAlpha'] as num? ?? 0.0).toDouble()) * 0.9,
                },
              ),
              const SizedBox(width: 8),
              EegTopographicMap(
                title: 'Z-Score (Theta)', 
                isZScore: true,
                overlayImagePath: 'assets/images/International_10-20_system_for_EEG-MCN.svg.png',
                sensorValues: {
                  'AF7': (_localSummary['thetaZScore'] as num? ?? 0.0).toDouble(),
                  'AF8': ((_localSummary['thetaZScore'] as num? ?? 0.0).toDouble()) * 0.5,
                  'TP9': -0.5,
                  'TP10': 0.2,
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // === Clinical / Observations / Recommendations ===
  Widget _clinicalSection() {
    final mentalStateLabel = _localSummary['predictedMentalStateLabel'] as String?;
    final confidence = _localSummary['predictedMentalStateConfidence'] as double?;
    final confidencePercent = confidence != null ? ' (${(confidence * 100).toStringAsFixed(0)}%)' : '';

    final tfliteLabel = _localSummary['tfliteMentalStateLabel'] as String?;
    final tfliteConf = _localSummary['tfliteMentalStateConfidence'] as double?;
    final tfliteConfPercent = tfliteConf != null ? ' (${(tfliteConf * 100).toStringAsFixed(0)}%)' : '';

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.medical_information_rounded, 'สรุปความหมายเชิงคลินิก'),
        const SizedBox(height: 12),
        if (mentalStateLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_emotions_rounded, color: Color(0xFF667eea), size: 18),
                const SizedBox(width: 8),
                Text(
                  'การประเมินสภาวะจิตใจ (Mental State):',
                  style: _body.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF667eea), fontSize: 11),
                ),
                const Spacer(),
                Text(
                  '$mentalStateLabel$confidencePercent',
                  style: _body.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F1B4C), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (tfliteLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, color: Color(0xFF0D47A1), size: 18),
                const SizedBox(width: 8),
                Text(
                  'การประเมินสภาวะอารมณ์ (Emotion State):',
                  style: _body.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1), fontSize: 11),
                ),
                const Spacer(),
                Text(
                  '$tfliteLabel$tfliteConfPercent',
                  style: _body.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F1B4C), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(EegAssessmentService.clinicalSummary(_localSummary), style: _body),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ผลนี้เป็นข้อมูลประกอบ ไม่ใช่การวินิจฉัยโรค ต้องประเมินร่วมกับแพทย์/นักจิตวิทยา',
                style: _caption.copyWith(color: const Color(0xFFDC2626), fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _observationsSection() => _listSection('ข้อสังเกต', Icons.visibility_rounded, EegAssessmentService.observations(_localSummary));
  Widget _recommendationsSection() => _listSection('ข้อเสนอแนะ', Icons.task_alt_rounded, EegAssessmentService.recommendations(_localSummary), checklist: true);

  Widget _listSection(String title, IconData icon, List<String> items, {bool checklist = false}) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(icon, title),
        const SizedBox(height: 10),
        ...items.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: checklist ? const Color(0xFF3B82F6).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: checklist
                        ? const Icon(Icons.check_rounded, size: 13, color: Color(0xFF3B82F6))
                        : Text('${e.key + 1}', style: _caption.copyWith(fontSize: 9, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value, style: _body.copyWith(fontSize: 11))),
              ]),
            )),
      ]),
    );
  }

  // === Footer ===
  Widget _footerDisclaimer() {
    return _card(
      gradient: const [Color(0xFF0F1B4C), Color(0xFF1E3A8A)],
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'หมายเหตุ: ผลการทดสอบนี้ไม่สามารถใช้วินิจฉัยภาวะซึมเศร้าได้โดยลำพัง ต้องนำผลไปประกอบการพิจารณาร่วมกับการประเมินทางคลินิกโดยผู้เชี่ยวชาญเท่านั้น',
            style: GoogleFonts.notoSansThai(fontSize: 10, color: const Color(0xFFCBD5E1), height: 1.5),
          ),
        ),
      ]),
    );
  }

  // === Action Buttons ===
  Widget _actionButtons() {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _handlePdfExport(true),
          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
          label: Text('ดาวน์โหลด PDF', style: _body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _handlePdfExport(false),
          icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
          label: Text('พิมพ์รายงาน', style: _body.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }
}
