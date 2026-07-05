import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../eeg_research/preprocessing/eeg_preprocessor.dart';
import '../services/muse_service.dart';

/// EegPipelineVisualizer เป็น Widget แสดงสถานะขั้นตอนการประมวลผลและการคัดกรองสัญญาณคลื่นสมอง (Preprocessing Pipeline Visualizer)
/// โดยจำลองการประมวลผลทีละขั้นตอน (Step-by-Step) ตั้งแต่ระดับคลื่นสมองดิบจนเป็นคลื่นสมองสะอาด
class EegPipelineVisualizer extends StatefulWidget {
  final Map<String, List<double>> channels;
  final bool hasData;

  // สถานะทางโครงสร้างคลาสแบบ Static เพื่อเก็บค่าข้ามการเรนเดอร์ใหม่ของ Parent Widget และการเปลี่ยนหน้า
  static String selectedChannel = 'AF7';
  static bool isExpanded = true;

  const EegPipelineVisualizer({
    super.key,
    required this.channels,
    required this.hasData,
  });

  @override
  State<EegPipelineVisualizer> createState() => _EegPipelineVisualizerState();
}

class _EegPipelineVisualizerState extends State<EegPipelineVisualizer> {
  // ตัวแปรกำหนดความเร็วการอัปเดตสถิติ (หน่วงเวลาให้อัปเดต 2 ครั้งต่อวินาที เพื่อความนิ่งทางสายตา)
  DateTime _lastStatsUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  
  // ค่าสถิติที่แคชไว้สำหรับขั้นตอนที่ 0, 1, 2, 3
  double _mean0 = 0, _std0 = 0, _latest0 = 0;
  double _mean1 = 0, _std1 = 0, _latest1 = 0;
  double _mean2 = 0, _std2 = 0, _latest2 = 0;
  double _mean3 = 0, _std3 = 0, _latest3 = 0;

  @override
  Widget build(BuildContext context) {
    final channelData = widget.channels[EegPipelineVisualizer.selectedChannel] ?? [];
    final double notchFreq = MuseService().notchFrequency;
    final EegPreprocessor preprocessor = EegPreprocessor(
      samplingRate: 256,
      bandpassLow: 1.0,
      bandpassHigh: 45.0,
      notchFrequency: notchFreq,
    );
    
    // สร้างคลื่นจำลองที่ปนเปื้อนสัญญาณรบกวนในกรณีที่มีข้อมูลเข้ามา
    List<double> rawSignal = [];
    List<double> step1Signal = [];
    List<double> step2Signal = [];
    List<double> step3Signal = [];

    if (channelData.isNotEmpty && widget.hasData) {
      // จำกัดข้อมูลเพียง 150 จุดล่าสุดเพื่อให้เห็นการไหลของสัญญาณแบบละเอียด
      final int len = math.min(150, channelData.length);
      final rawSlice = channelData.sublist(channelData.length - len);

      // ใส่ค่า DC offset, drift และสัญญาณรบกวน 50/60 Hz เพื่อจำลองให้เห็นขั้นตอนการกรองชัดเจน
      rawSignal = List<double>.generate(rawSlice.length, (i) {
        final t = i / 256.0;
        final original = rawSlice[i];
        
        // 1. ค่า DC offset ขนาดใหญ่ (800.0)
        const double dcOffset = 800.0;
        // 2. การเบี่ยงเบนของเส้นเบสไลน์ความถี่ต่ำ (Drift 70.0 µV ที่ 0.25 Hz)
        final double drift = 70.0 * math.sin(2 * math.pi * 0.25 * t);
        // 3. สัญญาณรบกวนจากกระแสไฟฟ้าบ้าน (Powerline Noise 12.0 µV)
        final double powerlineNoise = 12.0 * math.sin(2 * math.pi * notchFreq * t);
        // 4. สัญญาณรบกวนพื้นหลัง (White noise)
        final double whiteNoise = (math.Random(i).nextDouble() - 0.5) * 4.0;

        // หากข้อมูลเดิมมีขนาดใหญ่ (เชื่อมอุปกรณ์จริง) จะไม่บวกออฟเซ็ตจำลองเพิ่ม
        final isAlreadyOffset = original.abs() > 400.0;
        if (isAlreadyOffset) {
          return original + powerlineNoise + whiteNoise;
        } else {
          return original + dcOffset + drift + powerlineNoise + whiteNoise;
        }
      });

      // ประมวลผลสัญญาณคลื่นสมองเป็นลำดับขั้นตอนผ่าน EegPreprocessor
      // ขั้นตอนที่ 1: กำจัดค่า DC Offset & ลบแนวโน้มเชิงเส้น (Linear Detrend)
      step1Signal = preprocessor.removeDCOffset(rawSignal, linearDetrend: true);

      // ขั้นตอนที่ 2: กรองช่วงความถี่ผ่าน Band-pass Filter (1-45 Hz) ด้วยฟิลเตอร์ Butterworth
      step2Signal = preprocessor.bandpassFilter(step1Signal);

      // ขั้นตอนที่ 3: กรองกำจัดสัญญาณรบกวนระบบไฟฟ้าด้วย Notch Filter (50 Hz หรือ 60 Hz)
      step3Signal = preprocessor.notchFilter(step2Signal);

      // จำกัดรอบการแสดงผลข้อมูลสถิติที่ 500 มิลลิวินาทีเพื่อไม่ให้ตัวเลขกะพริบเร็วเกินไป
      final now = DateTime.now();
      if (now.difference(_lastStatsUpdateTime) > const Duration(milliseconds: 500) || _mean0 == 0) {
        _lastStatsUpdateTime = now;

        Map<String, double> computeStats(List<double> signal) {
          if (signal.isEmpty) return {'mean': 0, 'std': 0, 'latest': 0};
          double sum = 0;
          double sqSum = 0;
          for (final v in signal) {
            sum += v;
            sqSum += v * v;
          }
          final mean = sum / signal.length;
          final variance = (sqSum / signal.length) - mean * mean;
          final std = math.sqrt(variance.abs());
          return {'mean': mean, 'std': std, 'latest': signal.last};
        }

        final s0 = computeStats(rawSignal);
        _mean0 = s0['mean']!; _std0 = s0['std']!; _latest0 = s0['latest']!;

        final s1 = computeStats(step1Signal);
        _mean1 = s1['mean']!; _std1 = s1['std']!; _latest1 = s1['latest']!;

        final s2 = computeStats(step2Signal);
        _mean2 = s2['mean']!; _std2 = s2['std']!; _latest2 = s2['latest']!;

        final s3 = computeStats(step3Signal);
        _mean3 = s3['mean']!; _std3 = s3['std']!; _latest3 = s3['latest']!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDBDBD), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ส่วนหัวของแบนเนอร์ (เปิดปิดแบบยุบได้ด้วยการคลิก มีเอฟเฟกต์ InkWell)
          Material(
            color: const Color(0xFF1E3A8A), // สีน้ำเงินเนวี่ / น้ำเงินเข้มพรีเมียม
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(13),
              topRight: const Radius.circular(13),
              bottomLeft: EegPipelineVisualizer.isExpanded ? Radius.zero : const Radius.circular(13),
              bottomRight: EegPipelineVisualizer.isExpanded ? Radius.zero : const Radius.circular(13),
            ),
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(13),
                topRight: const Radius.circular(13),
                bottomLeft: EegPipelineVisualizer.isExpanded ? Radius.zero : const Radius.circular(13),
                bottomRight: EegPipelineVisualizer.isExpanded ? Radius.zero : const Radius.circular(13),
              ),
              onTap: () {
                setState(() {
                  EegPipelineVisualizer.isExpanded = !EegPipelineVisualizer.isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EEG Preprocessing Pipeline (การเตรียมสัญญาณ)',
                        style: GoogleFonts.prompt(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    // ไอคอนสัญลักษณ์เปิดหรือปิดแท็บพับเก็บ
                    Icon(
                      EegPipelineVisualizer.isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    // ตัวเลือกช่องสัญญาณคลื่นสมอง (ครอบด้วย GestureDetector เพื่อกันปัญหาการขัดแย้งการคลิกกับแถบยุบขยาย)
                    GestureDetector(
                      onTap: () {}, // บล็อกไม่ให้เกิดการ Tap Propagation ไปยังตัว Parent
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: EegPipelineVisualizer.selectedChannel,
                            dropdownColor: const Color(0xFF1E3A8A),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                            style: GoogleFonts.prompt(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  EegPipelineVisualizer.selectedChannel = newValue;
                                });
                              }
                            },
                            items: <String>['TP9', 'AF7', 'AF8', 'TP10']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: EegPipelineVisualizer.isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // แบนเนอร์อธิบายรายละเอียดภาพรวม
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFF8FAFC),
                        child: Text(
                          'กระบวนการขจัดสัญญาณรบกวน (Noise Artifacts) แบบเรียลไทม์ 3 ขั้นตอนเรียงลำดับ เพื่อเตรียมข้อมูลสำหรับโมเดลปัญญาประดิษฐ์ให้ได้ความแม่นยำระดับห้องวิจัย',
                          style: GoogleFonts.prompt(
                            fontSize: 11,
                            color: const Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      if (!widget.hasData || rawSignal.isEmpty) ...[
                        Container(
                          height: 180,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.hourglass_empty_rounded, color: Colors.grey.shade400, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'กำลังรอข้อมูลสัญญาณดิบ...',
                                style: GoogleFonts.prompt(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              // ขั้นตอนที่ 0: แสดงค่าสัญญาณดิบที่รับเข้ามาจากเซนเซอร์ของฮาร์ดแวร์
                              _buildPipelineStep(
                                stepNum: '0',
                                titleTh: 'สัญญาณดิบจากเซนเซอร์ (Messy Raw EEG Input)',
                                formula: 'x[n] = Signal + Offset + Drift + LineNoise',
                                descTh: 'สัญญาณสมองที่รับเข้ามายังปนเปื้อนด้วยไฟฟ้ากระแสตรง ไฟฟ้าสลับ 50 Hz และคลื่นลอยต่ำที่ไม่เกี่ยวข้อง',
                                data: rawSignal,
                                lineColor: Colors.grey.shade600,
                                yMinLabel: '0 µV',
                                yMaxLabel: '1682 µV',
                                isZeroCentered: false,
                                mean: _mean0,
                                std: _std0,
                                latest: _latest0,
                              ),

                              _buildConnectorLine(),

                              // ขั้นตอนที่ 1: การกำจัดค่า DC Offset ออกจากตัวสัญญาณ
                              _buildPipelineStep(
                                stepNum: '1',
                                titleTh: 'ลบแรงดันไฟฟ้าไฟตรง (DC Offset & Linear Detrend)',
                                formula: 'y₁[n] = x[n] - (a * n + b)   [โดย a, b คำนวณจาก Least-squares]',
                                descTh: 'กำจัดค่าเฉลี่ยขั้วแรงดันไฟฟ้าของฮาร์ดแวร์เพื่อปรับให้สมดุลสัญญาณแกว่งรอบแกน 0 µV',
                                data: step1Signal,
                                lineColor: Colors.orange.shade800,
                                yMinLabel: '-400 µV',
                                yMaxLabel: '+400 µV',
                                isZeroCentered: true,
                                mean: _mean1,
                                std: _std1,
                                latest: _latest1,
                              ),

                              _buildConnectorLine(),

                              // ขั้นตอนที่ 2: การกรองช่วงคลื่นความถี่หลักของสมอง
                              _buildPipelineStep(
                                stepNum: '2',
                                titleTh: 'กรองช่วงความถี่สมอง (Butterworth Band-pass 1-45 Hz)',
                                formula: 'y₂[n] = Σ(b_k * y₁[n-k]) - Σ(a_k * y₂[n-k])   [4th-Order Zero-phase]',
                                descTh: 'กรองเอาเฉพาะคลื่นสมองหลัก (Delta ถึง Gamma) และกรองคลื่นเดินช้าจากการขยับตัว หรือการกระพริบตาบางส่วนออก',
                                data: step2Signal,
                                lineColor: Colors.blue.shade700,
                                yMinLabel: '-100 µV',
                                yMaxLabel: '+100 µV',
                                isZeroCentered: true,
                                mean: _mean2,
                                std: _std2,
                                latest: _latest2,
                              ),

                              _buildConnectorLine(),

                              // ขั้นตอนที่ 3: การกำจัดความถี่กระแสไฟฟ้าบ้านด้วย Notch Filter
                              _buildPipelineStep(
                                stepNum: '3',
                                titleTh: 'กรองคลื่นไฟฟ้ารบกวนอาคาร (IIR Notch Filter ${notchFreq.toInt()} Hz)',
                                formula: 'y₃[n] = a₀(y₂[n] - 2cos(ω₀)y₂[n-1] + y₂[n-2]) - b₁y₃[n-1] - b₂y₃[n-2]',
                                descTh: 'ตัดสัญญาณไฟฟ้าสลับจากอาคารช่วงความถี่ ${notchFreq.toInt()} Hz ออกได้อย่างสมบูรณ์แบบ ได้เป็นสัญญาณคลื่นสมองที่สะอาดระดับแพทย์',
                                data: step3Signal,
                                lineColor: const Color(0xFF047857),
                                yMinLabel: '-50 µV',
                                yMaxLabel: '+50 µV',
                                isZeroCentered: true,
                                mean: _mean3,
                                std: _std3,
                                latest: _latest3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorLine() {
    return Container(
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Container(
          width: 2,
          color: Colors.blue.shade100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) => Container(width: 2, height: 2, color: Colors.blue.shade300)),
          ),
        ),
      ),
    );
  }

  Widget _buildValueChip(String label, String value, {bool highlight = false, Color? highlightColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? (highlightColor?.withValues(alpha: 0.08) ?? const Color(0xFFEFF6FF))
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight
              ? (highlightColor?.withValues(alpha: 0.3) ?? const Color(0xFFBFDBFE))
              : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.prompt(
              fontSize: 8.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(
            width: 58, // กำหนดความกว้างคงที่ของค่าเพื่อป้องกันข้อความสั่นไหว/เลื่อนขณะอัปเดตแบบเรียลไทม์
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.firaCode(
                fontSize: 8.5,
                color: highlight
                    ? (highlightColor ?? const Color(0xFF1D4ED8))
                    : const Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStep({
    required String stepNum,
    required String titleTh,
    required String formula,
    required String descTh,
    required List<double> data,
    required Color lineColor,
    required String yMinLabel,
    required String yMaxLabel,
    required bool isZeroCentered,
    required double mean,
    required double std,
    required double latest,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หัวข้อของขั้นตอนประมวลผล
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: lineColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNum,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleTh,
                      style: GoogleFonts.prompt(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descTh,
                      style: GoogleFonts.prompt(
                        fontSize: 10,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ส่วนแสดงสูตรทางคณิตศาสตร์ที่ใช้ประมวลผลสัญญาณ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                formula,
                style: GoogleFonts.firaCode(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // แถวแสดงผลค่าสถิติสัญญาณแบบเรียลไทม์ (Mean, Std, Current)
          if (data.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildValueChip('Mean', '${mean.toStringAsFixed(1)} µV'),
                const SizedBox(width: 6),
                _buildValueChip('Std', '${std.toStringAsFixed(1)} µV'),
                const SizedBox(width: 6),
                _buildValueChip('Current', '${latest.toStringAsFixed(1)} µV', highlight: true, highlightColor: lineColor),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // ส่วนวาดกราฟคลื่นสัญญาณ
          Row(
            children: [
              // ป้ายกำกับแกนแนวตั้ง Y
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(yMaxLabel, style: GoogleFonts.firaCode(fontSize: 7.5, color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  Text(isZeroCentered ? '0 µV' : 'Mid', style: GoogleFonts.firaCode(fontSize: 7.5, color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  Text(yMinLabel, style: GoogleFonts.firaCode(fontSize: 7.5, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(width: 8),
              // บอร์ดวาดเส้นคลื่นสมอง
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CustomPaint(
                    painter: EegPipelineStepPainter(
                      data: data,
                      lineColor: lineColor,
                      isZeroCentered: isZeroCentered,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EegPipelineStepPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool isZeroCentered;

  EegPipelineStepPainter({
    required this.data,
    required this.lineColor,
    required this.isZeroCentered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double yCenter = size.height / 2;

    // วาดเส้นแกนนอนตรงกลาง (Baseline)
    final baselinePaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, yCenter), Offset(size.width, yCenter), baselinePaint);

    // คำนวณอัตราส่วนการขยายสัญญาณ (Scaling)
    double mean = 0;
    if (!isZeroCentered) {
      double sum = 0;
      for (final v in data) {
        sum += v;
      }
      mean = sum / data.length;
    }

    double maxDev = 1e-5;
    for (final v in data) {
      final dev = (v - mean).abs();
      if (dev > maxDev) maxDev = dev;
    }
    maxDev *= 1.1; // เพิ่มระยะขอบบนล่าง 10% กันยอดกราฟตกขอบ

    final double xStep = size.width / (data.length <= 1 ? 1 : data.length - 1);
    final wavePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final double x = i * xStep;
      final double normalizedY = (data[i] - mean) / maxDev;
      // สลับทิศทางแกน Y เนื่องจากระบบพิกัดของ Canvas บน Flutter บนซ้ายคือจุด (0,0)
      final double y = yCenter - (normalizedY * (size.height / 2) * 0.85);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant EegPipelineStepPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor || oldDelegate.isZeroCentered != isZeroCentered;
  }
}
