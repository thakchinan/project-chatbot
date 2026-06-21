import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import '../../services/api_service.dart';

class EegSessionScreen extends StatefulWidget {
  final User user;
  final MuseService museService;

  const EegSessionScreen({
    super.key,
    required this.user,
    required this.museService,
  });

  @override
  State<EegSessionScreen> createState() => _EegSessionScreenState();
}

class _EegSessionScreenState extends State<EegSessionScreen>
    with TickerProviderStateMixin {
  bool _isRunning = false;
  int _currentSessionIndex = -1;
  int _elapsedSeconds = 0;
  int _samplesCollected = 0;
  Timer? _timer;
  Timer? _sampleTimer;

  double _totalAlpha = 0, _totalBeta = 0, _totalTheta = 0;
  double _totalDelta = 0, _totalGamma = 0;

  late AnimationController _pulseController;

  // ═══════════════════════════════════════════════════════════════════
  // Protocol Duration Justification (Research-Backed)
  // ─────────────────────────────────────────────────────────────────
  // • DEAP Dataset (Koelstra et al., 2012): 60s per emotion trial
  //   → 32 participants × 40 trials × 60s = gold-standard protocol
  // • Optimal Time Window: 2-15s segments for feature extraction
  //   (García-Martínez et al., 2019, RMIB)
  // • 60s artifact-free data = stable PSD/DE features (Zheng & Lu, 2015)
  // • 90s provides ~50% margin for artifact rejection
  // • Sampling @ 1s interval → 60-90 data points per session
  //   (vs. 12-36 points @ 5s interval previously)
  // • Consumer-grade Muse: alpha power reliable at 60s+
  //   (Krigolson et al., 2017)
  // ═══════════════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _sessions = [
    {
      'name': 'Baseline',
      'emotion': 'neutral',
      'activity': 'baseline',
      'duration': 60, // DEAP: 3-60s baseline; 60s = standard
      'icon': Icons.circle_outlined,
      'color': Color(0xFF9E9E9E),
      'gradient': [Color(0xFF757575), Color(0xFF9E9E9E)],
      'description': 'นั่งนิ่ง หลับตา 1 นาที เก็บค่า EEG พื้นฐาน (DEAP Protocol)',
      'instruction': 'จ้องมองจุดตรงกลางหน้าจอ หายใจปกติ',
    },
    {
      'name': 'ผ่อนคลาย',
      'emotion': 'calm',
      'activity': 'breathing',
      'duration': 90, // 60s DEAP + 30s margin for artifact rejection
      'icon': Icons.self_improvement_rounded,
      'color': Color(0xFF4CAF50),
      'gradient': [Color(0xFF11998e), Color(0xFF38ef7d)],
      'description': 'หายใจลึกๆ 1.5 นาที ตามจังหวะ 4-7-8 เพื่อเพิ่ม Alpha wave',
      'instruction': 'หายใจเข้า 4 วิ → กลั้น 7 วิ → ออก 8 วิ',
    },
    {
      'name': 'มีความสุข',
      'emotion': 'happy',
      'activity': 'positive_recall',
      'duration': 90, // 60s DEAP + 30s margin for artifact rejection
      'icon': Icons.favorite_rounded,
      'color': Color(0xFFFFC107),
      'gradient': [Color(0xFFf7971e), Color(0xFFffd200)],
      'description': 'นึกถึงความทรงจำที่มีความสุข 1.5 นาที',
      'instruction': 'หลับตาแล้วนึกถึงเหตุการณ์ที่ทำให้มีความสุขที่สุด',
    },
    {
      'name': 'เครียด (เบา)',
      'emotion': 'stressed',
      'activity': 'mental_arithmetic',
      'duration': 90, // Trier Social Stress Test adapted: 60-120s
      'icon': Icons.calculate_rounded,
      'color': Color(0xFFF44336),
      'gradient': [Color(0xFFeb3349), Color(0xFFf45c43)],
      'description': 'นับถอยหลัง 1.5 นาที จาก 1000 ลบ 7 กระตุ้น Beta wave',
      'instruction': 'นับ: 1000, 993, 986, 979... ให้เร็วที่สุด',
    },
    {
      'name': 'เศร้า',
      'emotion': 'sad',
      'activity': 'sad_recall',
      'duration': 90, // 60s DEAP + 30s margin for artifact rejection
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF2196F3),
      'gradient': [Color(0xFF4facfe), Color(0xFF00f2fe)],
      'description': 'นึกถึงเรื่องราวที่ทำให้เศร้าเล็กน้อย 1.5 นาที',
      'instruction': 'หลับตาแล้วนึกถึงช่วงเวลาที่ทำให้เศร้าใจ',
    },
    {
      'name': 'สมาธิสูง',
      'emotion': 'focused',
      'activity': 'focus_counting',
      'duration': 90, // Consistent 90s across all emotion sessions
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF9C27B0),
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
      'description': 'นับลมหายใจ 1.5 นาที จาก 1-10 แล้วเริ่มใหม่ กระตุ้น Gamma',
      'instruction': 'นับลมหายใจ 1...2...3... ถึง 10 แล้วเริ่มใหม่',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sampleTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startSession(int index) {
    if (!widget.museService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเชื่อมต่อ Muse ก่อนเริ่ม Session'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _currentSessionIndex = index;
      _isRunning = true;
      _elapsedSeconds = 0;
      _samplesCollected = 0;
      _totalAlpha = 0;
      _totalBeta = 0;
      _totalTheta = 0;
      _totalDelta = 0;
      _totalGamma = 0;
    });

    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final duration = _sessions[index]['duration'] as int;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= duration) _stopSession();
    });

    // Sampling @ 1s → 60-90 samples per session (was 5s → 12-36 samples)
    // Higher density enables 2-5s windowed PSD analysis
    // (García-Martínez et al., 2019: optimal TW = 2-15s)
    _sampleTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _collectSample();
    });
  }

  void _collectSample() {
    final data = widget.museService.latestData;
    if (data == null) return;

    final session = _sessions[_currentSessionIndex];

    _totalAlpha += data.alpha;
    _totalBeta += data.beta;
    _totalTheta += data.theta;
    _totalDelta += data.delta;
    _totalGamma += data.gamma;
    _samplesCollected++;



    if (mounted) setState(() {});
  }

  Future<void> _stopSession() async {
    _timer?.cancel();
    _sampleTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    if (!mounted) return;

    _showSelfReportDialog();

    setState(() => _isRunning = false);
  }

  void _showSelfReportDialog() {
    int valence = 5;
    int arousal = 5;
    bool _isSaving = false;
    final session = _sessions[_currentSessionIndex];

    final n = _samplesCollected > 0 ? _samplesCollected : 1;
    final avgA = _totalAlpha / n;
    final avgB = _totalBeta / n;
    final avgT = _totalTheta / n;
    final avgD = _totalDelta / n;
    final avgG = _totalGamma / n;

    final eval = _evaluateEEG(session['emotion'], avgA, avgB, avgT, avgD, avgG);
    final isMatch = eval['isMatch'] as bool;
    final feedback = eval['feedback'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: session['color'], size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Session "${session['name']}" เสร็จสิ้น',
                    style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เก็บได้ $_samplesCollected samples ใน $_elapsedSeconds วินาที',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 12),
              
              // ─── การตรวจสอบผลลัพธ์คลื่นสมองเบื้องต้น ───
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMatch ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isMatch ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          isMatch ? Icons.check_circle_outline : Icons.info_outline,
                          color: isMatch ? Colors.green[700] : Colors.orange[800],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isMatch ? 'สรุป: ตรงตามเป้าหมาย ($feedback)' : 'สรุป: ยังไม่ตรงเป้า ($feedback)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMatch ? Colors.green[800] : Colors.orange[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((eval['details'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1, thickness: 0.5),
                      const SizedBox(height: 8),
                      ...(eval['details'] as List).map((d) {
                        final p = d['pass'] as bool;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1.5),
                                child: Icon(
                                  p ? Icons.check_circle : Icons.cancel,
                                  color: p ? Colors.green[600] : Colors.red[400],
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  d['text'] as String,
                                  style: TextStyle(
                                    fontSize: 11.5, 
                                    color: Colors.grey[800],
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ]
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text('ตอนนี้คุณรู้สึกอย่างไร?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('เศร้า', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: valence.toDouble(),
                      min: 1, max: 9,
                      divisions: 8,
                      label: '$valence',
                      onChanged: (v) => setDialogState(() => valence = v.round()),
                    ),
                  ),
                  const Text('สุข', style: TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                children: [
                  const Text('สงบ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: arousal.toDouble(),
                      min: 1, max: 9,
                      divisions: 8,
                      label: '$arousal',
                      onChanged: (v) => setDialogState(() => arousal = v.round()),
                    ),
                  ),
                  const Text('ตื่นเต้น', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('ไม่ได้บันทึก Session นี้',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      backgroundColor: Colors.grey[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Text('ไม่บันทึก',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ),
            const SizedBox(height: 8),

            // Warning when results don't match session target
            if (!isMatch) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Color(0xFFE65100), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ผลคลื่นสมองยังไม่ตรงตาม Session "${ session['name'] }" ไม่สามารถบันทึกได้ — ลองทำ Session ใหม่อีกครั้ง',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!isMatch || _isSaving)
                    ? null
                    : () async {
                        setDialogState(() => _isSaving = true);

                        final n = _samplesCollected > 0 ? _samplesCollected : 1;
                        final result = await ApiService.saveEmotionSession(
                          userId: widget.user.id,
                          targetEmotion: session['emotion'],
                          activityType: session['activity'],
                          sessionName: session['name'],
                          durationSeconds: _elapsedSeconds,
                          samplesCollected: _samplesCollected,
                          avgAlpha: _totalAlpha / n,
                          avgBeta: _totalBeta / n,
                          avgTheta: _totalTheta / n,
                          avgDelta: _totalDelta / n,
                          avgGamma: _totalGamma / n,
                          selfReportValence: valence,
                          selfReportArousal: arousal,
                          isCompleted: _elapsedSeconds >= (session['duration'] as int),
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (mounted) {
                          final success = result['success'] == true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    success ? Icons.check_circle_rounded : Icons.error_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          success
                                              ? 'บันทึก Session "${session['name']}" สำเร็จ!'
                                              : 'บันทึกไม่สำเร็จ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (success)
                                          Text(
                                            '$_samplesCollected samples · Valence: $valence · Arousal: $arousal',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withOpacity(0.85),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: success
                                  ? const Color(0xFF11998e)
                                  : Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isMatch ? Icons.save_rounded : Icons.lock_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                label: Text(
                  _isSaving
                      ? 'กำลังบันทึก...'
                      : isMatch
                          ? 'บันทึก'
                          : 'ไม่สามารถบันทึกได้',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMatch ? session['color'] : Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _evaluateEEG(String emotion, double alpha, double beta, double theta, double delta, double gamma) {
    bool isMatch = false;
    String feedback = '';
    List<Map<String, dynamic>> details = [];

    void addDetail(bool pass, String text) {
      details.add({'pass': pass, 'text': text});
    }

    final totalPower = alpha + beta + theta + delta + gamma;
    if (totalPower <= 0) {
      return {'isMatch': false, 'feedback': 'ไม่พบสัญญาณสมอง', 'details': []};
    }

    switch (emotion) {
      case 'neutral':
        isMatch = true;
        feedback = 'เส้นฐาน (Baseline) สมบูรณ์แบบ';
        addDetail(true, 'เก็บข้อมูลคลื่นสมองได้ครบถ้วน (Baseline)');
        break;
        
      case 'calm':
        final baRatio = beta / (alpha > 0 ? alpha : 1);
        if (baRatio < 3.5) {
          isMatch = true;
          feedback = 'ผ่อนคลายได้ดีมาก';
          addDetail(true, 'คลื่นความเครียด (Beta) อยู่ในระดับต่ำ');
        } else {
          feedback = 'สมองยังมีความตื่นตัวสูง';
          addDetail(false, 'คลื่น Beta ยังค่อนข้างสูง (สัดส่วน Beta/Alpha = ${baRatio.toStringAsFixed(1)})');
        }
        
        if (alpha > 6.5) {
          addDetail(true, 'คลื่นผ่อนคลาย (Alpha) ทำงานได้ดี (${alpha.toStringAsFixed(1)})');
        } else {
          addDetail(false, 'คลื่น Alpha ยังค่อนข้างต่ำ ลองหลับตาและหายใจลึกๆ');
        }
        break;
        
      case 'focused':
        if (beta > 25.0) {
          isMatch = true;
          feedback = 'สมาธิดีมาก (จดจ่อสูง)';
          addDetail(true, 'คลื่น Beta พุ่งสูงสะท้อนการคิดวิเคราะห์ (${beta.toStringAsFixed(1)})');
        } else {
          feedback = 'สมาธิอยู่ในระดับปานกลาง';
          addDetail(false, 'คลื่น Beta ยังไม่สูงมาก อาจจะหลุดโฟกัส');
        }
        if (gamma > 10.0) {
          addDetail(true, 'คลื่น Gamma (การประมวลผลขั้นสูง) ทำงานได้ดี (${gamma.toStringAsFixed(1)})');
        } else {
          addDetail(false, 'คลื่น Gamma ยังอยู่ในระดับปกติ');
        }
        break;
        
      case 'stressed':
        if (beta > 20.0 && delta > 30.0) {
          isMatch = true;
          feedback = 'พบรูปแบบความเครียดชัดเจน';
          addDetail(true, 'คลื่นความเครียด (Beta) พุ่งสูง (${beta.toStringAsFixed(1)})');
          addDetail(true, 'พบการเกร็งกล้ามเนื้อ/หน้าเครียด (Delta = ${delta.toStringAsFixed(1)})');
        } else if (beta > 25.0) {
          isMatch = true;
          feedback = 'มีความเครียดทางจิตใจ (Cognitive Stress)';
          addDetail(true, 'คลื่น Beta พุ่งสูง (${beta.toStringAsFixed(1)})');
          addDetail(false, 'ไม่พบการเกร็งกล้ามเนื้อรุนแรง');
        } else {
          feedback = 'คุณดูผ่อนคลายกว่าที่คิด';
          addDetail(false, 'คลื่นความเครียดยังอยู่ในเกณฑ์ปกติ');
          addDetail(false, 'ไม่มีสัญญาณการเกร็งหน้าหรือขมวดคิ้ว');
        }
        break;
        
      case 'happy':
        if (alpha > 5.5 && beta > 20.0) {
          isMatch = true;
          feedback = 'อารมณ์เบิกบาน/ตื่นตัวในทางบวก';
          addDetail(true, 'Beta ทำงานดี แสดงถึงความตื่นตัว (Arousal)');
          addDetail(true, 'Alpha อยู่ในเกณฑ์ดี สะท้อนอารมณ์ผ่อนคลาย (Positive Valence)');
        } else {
          feedback = 'อารมณ์ยังค่อนข้างเป็นกลาง';
          addDetail(false, 'ระดับความตื่นตัวทางบวกยังไม่เด่นชัด');
        }
        break;
        
      case 'sad':
        if (delta > 35.0 || theta > 18.0) {
          isMatch = true;
          feedback = 'พบความถี่ต่ำสอดคล้องกับความเศร้า';
          if (delta > 35.0) addDetail(true, 'Delta พุ่งสูง (อาจมีการขมวดคิ้ว/น้ำตาคลอ/สะอื้น)');
          if (theta > 18.0) addDetail(true, 'Theta สูง (${theta.toStringAsFixed(1)}) สะท้อนความรู้สึกเครียดลึก');
        } else {
          feedback = 'ควบคุมอารมณ์ได้ดี ไม่ค่อยเครียด';
          addDetail(false, 'ไม่พบคลื่นความถี่ต่ำที่บ่งชี้ความเศร้ารุนแรง');
        }
        break;
        
      default:
        isMatch = true;
        feedback = 'เก็บข้อมูลสำเร็จ';
    }
    
    return {'isMatch': isMatch, 'feedback': feedback, 'details': details};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryBlue),
          onPressed: () {
            if (_isRunning) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('หยุด Session?'),
                  content: const Text('ข้อมูลที่เก็บแล้วจะถูกบันทึก'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _stopSession();
                        Navigator.pop(context);
                      },
                      child: const Text('หยุดและออก', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'เก็บข้อมูลอารมณ์',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _isRunning ? _buildRunningSession() : _buildSessionList(),
    );
  }

  Widget _buildRunningSession() {
    final session = _sessions[_currentSessionIndex];
    final duration = session['duration'] as int;
    final progress = _elapsedSeconds / duration;
    final remaining = duration - _elapsedSeconds;
    final colors = session['gradient'] as List<Color>;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      boxShadow: [
                        BoxShadow(
                          color: (session['color'] as Color).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(session['icon'], color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            Text(
              session['name'],
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: session['color']),
            ),
            const SizedBox(height: 8),
            Text(
              session['instruction'],
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(session['color']),
                minHeight: 10,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatChip(Icons.timeline, '$_samplesCollected samples'),
                _buildStatChip(Icons.timer, '$_elapsedSeconds s'),
                _buildStatChip(Icons.label, session['emotion']),
              ],
            ),

            if (widget.museService.latestData != null) ...[
              const SizedBox(height: 24),
              _buildLiveWaveCard(),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _stopSession,
                icon: const Icon(Icons.stop_rounded, color: Colors.white),
                label: const Text('หยุด Session', style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLiveWaveCard() {
    final d = widget.museService.latestData!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildMiniBar('Alpha', d.alpha, Colors.blue),
          _buildMiniBar('Beta', d.beta, Colors.orange),
          _buildMiniBar('Theta', d.theta, Colors.green),
          _buildMiniBar('Delta', d.delta, Colors.purple),
          _buildMiniBar('Gamma', d.gamma, Colors.red),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text('${value.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 10), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    final isConnected = widget.museService.isConnected;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isConnected)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_disabled, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'กรุณาเชื่อมต่อ Muse ก่อนเริ่มเก็บข้อมูล',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          const Text(
            'เลือก Session',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'แต่ละ session จะกระตุ้นอารมณ์ที่แตกต่างกัน พร้อมบันทึก EEG',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          ...List.generate(_sessions.length, (i) {
            final s = _sessions[i];
            final colors = s['gradient'] as List<Color>;
            final durationSecs = s['duration'] as int;
            final durationStr = durationSecs % 60 == 0 
                ? '${durationSecs ~/ 60} นาที' 
                : '${durationSecs / 60} นาที';

            return GestureDetector(
              onTap: isConnected ? () => _startSession(i) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isConnected ? colors : [Colors.grey.shade300, Colors.grey.shade400],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? colors.first : Colors.grey).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -15, top: -15,
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(s['icon'], color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'],
                                  style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s['description'],
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.timer, size: 12, color: Colors.white.withOpacity(0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      durationStr,
                                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.label, size: 12, color: Colors.white.withOpacity(0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      s['emotion'],
                                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('คำแนะนำ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                        'ควรทำ Baseline ก่อนทุกครั้ง และพัก 1-2 นาทีระหว่าง session\nอ้างอิง: DEAP Dataset Protocol (60s/trial), Krigolson et al. 2017',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
