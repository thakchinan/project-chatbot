import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import '../../services/api_service.dart';
import '../../widgets/eeg_pipeline_visualizer.dart';

/// EegSessionScreen เป็นหน้าจอสำหรับทดสอบบันทึกข้อมูลอารมณ์และสแกนคลื่นสมอง qEEG เรียลไทม์
/// มีเป้าหมาย 6 Sessions ย่อย (เช่น Baseline, ผ่อนคลาย, มีความสุข, เครียด, เศร้า, สมาธิสูง)
/// โดยใช้แบบการทดสอบ DEAP Protocol 60-90 วินาที พร้อมกราฟคลื่นสมอง และการขจัดสัญญาณรบกวน (Visualizer)
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
  static bool _isResearchWavesExpanded = true;
  bool _isRunning = false;
  int _currentSessionIndex = -1;
  int _elapsedSeconds = 0;
  int _samplesCollected = 0;
  Timer? _timer;
  Timer? _sampleTimer;

  double _totalAlpha = 0, _totalBeta = 0, _totalTheta = 0;
  double _totalDelta = 0, _totalGamma = 0;

  late AnimationController _pulseController;

  // Real-time scrolling oscilloscope state
  final Map<String, List<double>> _oscilloscopeBuffers = {
    'TP9': [],
    'AF7': [],
    'AF8': [],
    'TP10': [],
  };
  StreamSubscription? _rawEegSubscription;
  Timer? _simulationWaveTimer;

  void _startListeningToRawEeg() {
    _rawEegSubscription?.cancel();
    _rawEegSubscription = widget.museService.rawEegStream.listen((channelData) {
      if (!mounted || !_isRunning) return;
      setState(() {
        channelData.forEach((channel, samples) {
          for (final sample in samples) {
            _addOscilloscopeSample(channel, sample);
          }
        });
      });
    });
  }

  void _startSimulationWaves() {
    _simulationWaveTimer?.cancel();
    double time = 0;
    final random = Random();
    _simulationWaveTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_isRunning) {
        timer.cancel();
        return;
      }
      time += 0.03;
      setState(() {
        // Generate realistic synthetic EEG traces (base frequencies + minor noise)
        // Alpha: ~10 Hz
        final tp9Val = 15.0 * sin(2 * pi * 10 * time) + 4.0 * sin(2 * pi * 4 * time) + (random.nextDouble() - 0.5) * 6.0;
        // Beta: ~20 Hz
        final af7Val = 8.0 * sin(2 * pi * 20 * time) + 10.0 * sin(2 * pi * 8 * time) + (random.nextDouble() - 0.5) * 8.0;
        // Beta: ~18 Hz
        final af8Val = 7.0 * sin(2 * pi * 18 * time) + 9.0 * sin(2 * pi * 9 * time) + (random.nextDouble() - 0.5) * 7.5;
        // Theta/Delta: ~4 Hz
        final tp10Val = 10.0 * sin(2 * pi * 6 * time) + 15.0 * sin(2 * pi * 2 * time) + (random.nextDouble() - 0.5) * 5.0;

        _addOscilloscopeSample('TP9', tp9Val);
        _addOscilloscopeSample('AF7', af7Val);
        _addOscilloscopeSample('AF8', af8Val);
        _addOscilloscopeSample('TP10', tp10Val);
      });
    });
  }

  void _addOscilloscopeSample(String channel, double value) {
    final buffer = _oscilloscopeBuffers[channel];
    if (buffer != null) {
      buffer.add(value);
      if (buffer.length > 500) {
        buffer.removeAt(0);
      }
    }
  }

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
    _rawEegSubscription?.cancel();
    _simulationWaveTimer?.cancel();
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
      // Clear buffers
      _oscilloscopeBuffers.forEach((key, value) => value.clear());
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

    // Start wave collection/simulation
    if (widget.museService.isSimulating) {
      _startSimulationWaves();
    } else {
      _startListeningToRawEeg();
    }
  }

  void _collectSample() {
    final data = widget.museService.latestData;
    if (data == null) return;

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
    _rawEegSubscription?.cancel();
    _simulationWaveTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    if (!mounted) return;

    _showSelfReportDialog();

    setState(() => _isRunning = false);
  }

  void _showSelfReportDialog() {
    int valence = 5;
    int arousal = 5;
    bool isSaving = false;
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
                  color: isMatch ? Colors.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isMatch ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
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
                      }),
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
                  border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.5)),
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
                onPressed: (!isMatch || isSaving)
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);

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
                                              color: Colors.white.withValues(alpha: 0.85),
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
                icon: isSaving
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
                  isSaving
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
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
                            color: (session['color'] as Color).withValues(alpha: 0.4),
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
                _buildResearchWaveformCard(),
                const SizedBox(height: 16),
                EegPipelineVisualizer(
                  channels: _oscilloscopeBuffers,
                  hasData: _oscilloscopeBuffers.values.any((b) => b.isNotEmpty),
                ),
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
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
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
    final rawVals = [d.delta, d.theta, d.alpha, d.beta, d.gamma];
    final double sumRaw = rawVals.reduce((a, b) => a + b);
    final List<double> pctVals = sumRaw > 0
        ? rawVals.map((v) => (v / sumRaw) * 100.0).toList()
        : [0.0, 0.0, 0.0, 0.0, 0.0];

    // Apply Largest Remainder Method to get rounded integers that sum to exactly 100
    final List<int> roundedVals = List.filled(5, 0);
    if (sumRaw > 0) {
      final List<int> floors = pctVals.map((v) => v.floor()).toList();
      final int floorSum = floors.reduce((a, b) => a + b);
      final int diff = 100 - floorSum;

      final List<MapEntry<int, double>> remainders = List.generate(
        5,
        (i) => MapEntry(i, pctVals[i] - floors[i])
      );
      remainders.sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < 5; i++) {
        roundedVals[i] = floors[i];
      }
      for (int i = 0; i < diff; i++) {
        final idx = remainders[i].key;
        roundedVals[idx]++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildMiniBar('Delta', roundedVals[0].toDouble(), Colors.purple),
          _buildMiniBar('Theta', roundedVals[1].toDouble(), Colors.green),
          _buildMiniBar('Alpha', roundedVals[2].toDouble(), Colors.blue),
          _buildMiniBar('Beta', roundedVals[3].toDouble(), Colors.orange),
          _buildMiniBar('Gamma', roundedVals[4].toDouble(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(
            width: 55,
            child: Text('${value.round()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
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
                      color: (isConnected ? colors.first : Colors.grey).withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.08),
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
                              color: Colors.white.withValues(alpha: 0.2),
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
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.timer, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      durationStr,
                                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.label, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      s['emotion'],
                                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
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

  Widget _buildResearchWaveformCard() {
    // Calculate real-time statistics for each channel (raw values)
    final Map<String, Map<String, double>> channelStats = {};
    for (final entry in _oscilloscopeBuffers.entries) {
      final data = entry.value;
      if (data.isNotEmpty) {
        double sum = 0, sqSum = 0;
        double minVal = data.first, maxVal = data.first;
        for (final v in data) {
          sum += v;
          sqSum += v * v;
          if (v < minVal) minVal = v;
          if (v > maxVal) maxVal = v;
        }
        final mean = sum / data.length;
        final variance = (sqSum / data.length) - mean * mean;
        final std = sqrt(variance.abs());
        channelStats[entry.key] = {
          'mean': mean,
          'std': std,
          'min': minVal,
          'max': maxVal,
          'pp': maxVal - minVal,
        };
      }
    }

    final bool hasData = _oscilloscopeBuffers.values.any((b) => b.isNotEmpty);
    final int totalSamples = _oscilloscopeBuffers['TP9']?.length ?? 0;
    final String sourceLabel = widget.museService.isSimulating
        ? 'Simulation Mode'
        : 'Muse 2 (Live)';
    final now = DateTime.now();
    final String timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    const channelColors = {
      'TP9': Color(0xFF1565C0),
      'AF7': Color(0xFF2E7D32),
      'AF8': Color(0xFFE65100),
      'TP10': Color(0xFF6A1B9A),
    };

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
          // ── Header Banner (Collapsible with Material InkWell ripple feedback) ──
          Material(
            color: const Color(0xFF1A237E),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(13),
              topRight: const Radius.circular(13),
              bottomLeft: _isResearchWavesExpanded ? Radius.zero : const Radius.circular(13),
              bottomRight: _isResearchWavesExpanded ? Radius.zero : const Radius.circular(13),
            ),
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(13),
                topRight: const Radius.circular(13),
                bottomLeft: _isResearchWavesExpanded ? Radius.zero : const Radius.circular(13),
                bottomRight: _isResearchWavesExpanded ? Radius.zero : const Radius.circular(13),
              ),
              onTap: () {
                setState(() {
                  _isResearchWavesExpanded = !_isResearchWavesExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Raw EEG Multi-Channel Traces',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Icon(
                      _isResearchWavesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasData ? const Color(0xFF4CAF50) : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasData ? 'LIVE' : 'IDLE',
                            style: TextStyle(
                              color: hasData ? const Color(0xFF81C784) : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
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
            child: _isResearchWavesExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Device Metadata Row ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        color: const Color(0xFFF5F5F5),
                        child: Row(
                          children: [
                            _metaChip('Source', sourceLabel),
                            const SizedBox(width: 12),
                            _metaChip('Fs', '256 Hz'),
                            const SizedBox(width: 12),
                            _metaChip('Ref', 'FPz (Forehead)'),
                            const Spacer(),
                            Text(
                              timestamp,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 9,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Montage Info ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        color: const Color(0xFFFAFAFA),
                        child: Row(
                          children: [
                            Text(
                              'Montage: International 10-20 System  •  Channels: 4',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 9.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'N = $totalSamples pts',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 9,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE0E0E0)),

                      // ── Channel Color Legend ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          children: channelColors.entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10, height: 3,
                                    decoration: BoxDecoration(
                                      color: e.value,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      color: e.value,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // ── Waveform Plot ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: const Color(0xFFFCFCFC),
                            height: 220,
                            child: CustomPaint(
                              painter: EegResearchTracePainter(
                                channels: _oscilloscopeBuffers,
                                channelColors: channelColors,
                              ),
                              child: Container(),
                            ),
                          ),
                        ),
                      ),

                      // ── Scale Bar ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: Row(
                          children: [
                            // Time scale
                            Container(
                              width: 40, height: 2,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '~${(totalSamples / 33.3).toStringAsFixed(1)}s',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.black54,
                                fontFamily: 'Courier',
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Amplitude scale
                            Container(width: 2, height: 12, color: Colors.black54),
                            const SizedBox(width: 4),
                            const Text(
                              'Auto µV',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.black54,
                                fontFamily: 'Courier',
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Filter: 0.5 – 50 Hz  •  Notch: 50 Hz',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade500,
                                fontFamily: 'Courier',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),

                      // ── Per-Channel Statistics ──
                      if (channelStats.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Channel Statistics — Raw (Real-time)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Table(
                                columnWidths: const {
                                  0: FixedColumnWidth(50),
                                  1: FlexColumnWidth(),
                                  2: FlexColumnWidth(),
                                  3: FlexColumnWidth(),
                                  4: FlexColumnWidth(),
                                },
                                border: TableBorder.all(color: Colors.grey.shade200, width: 0.5),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: Colors.grey.shade100),
                                    children: const [
                                      _StatHeader('Ch'),
                                      _StatHeader('Mean'),
                                      _StatHeader('Std'),
                                      _StatHeader('Min'),
                                      _StatHeader('Max'),
                                    ],
                                  ),
                                  ...['TP9', 'AF7', 'AF8', 'TP10'].map((ch) {
                                    final s = channelStats[ch];
                                    return TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Text(
                                            ch,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: channelColors[ch],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        _StatCell(s?['mean']),
                                        _StatCell(s?['std']),
                                        _StatCell(s?['min']),
                                        _StatCell(s?['max']),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                    ],
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Stat table helper widgets ──
class _StatHeader extends StatelessWidget {
  final String text;
  const _StatHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final double? value;
  const _StatCell(this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        value != null ? value!.toStringAsFixed(2) : '—',
        style: const TextStyle(
          fontSize: 9,
          fontFamily: 'Courier',
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Research-grade EEG Trace Painter with grid, scale, and per-channel colors
// Designed to match clinical/research EEG viewer conventions
// ═══════════════════════════════════════════════════════════════════
class EegResearchTracePainter extends CustomPainter {
  final Map<String, List<double>> channels;
  final Map<String, Color> channelColors;
  final List<String> channelNames = const ['TP9', 'AF7', 'AF8', 'TP10'];

  EegResearchTracePainter({
    required this.channels,
    required this.channelColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFFFCFCFC)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final double channelHeight = size.height / channelNames.length;
    const double labelWidth = 52.0;
    const double rightPadding = 8.0;
    final double plotWidth = size.width - labelWidth - rightPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;

    final gridPaintMajor = Paint()
      ..color = const Color(0xFFD0D0D0)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final baselinePaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Dashed baseline helper
    void drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final totalLength = sqrt(dx * dx + dy * dy);
      final dirX = dx / totalLength;
      final dirY = dy / totalLength;
      double drawn = 0;
      while (drawn < totalLength) {
        final segEnd = (drawn + dashWidth).clamp(0.0, totalLength);
        canvas.drawLine(
          Offset(start.dx + dirX * drawn, start.dy + dirY * drawn),
          Offset(start.dx + dirX * segEnd, start.dy + dirY * segEnd),
          paint,
        );
        drawn += dashWidth + dashSpace;
      }
    }

    for (int i = 0; i < channelNames.length; i++) {
      final name = channelNames[i];
      final yOffset = i * channelHeight;
      final yCenter = yOffset + channelHeight / 2;
      final chColor = channelColors[name] ?? const Color(0xFF1565C0);

      // Alternating background
      if (i % 2 == 1) {
        canvas.drawRect(
          Rect.fromLTWH(0, yOffset, size.width, channelHeight),
          Paint()..color = const Color(0xFFF7F7FA),
        );
      }

      // Grid lines (3 minor lines per channel)
      for (int g = 1; g <= 3; g++) {
        final gy = yOffset + channelHeight * g / 4;
        canvas.drawLine(
          Offset(labelWidth, gy),
          Offset(size.width - rightPadding, gy),
          gridPaint,
        );
      }

      // Vertical grid lines (8 segments)
      for (int v = 1; v < 8; v++) {
        final vx = labelWidth + plotWidth * v / 8;
        canvas.drawLine(
          Offset(vx, yOffset),
          Offset(vx, yOffset + channelHeight),
          v == 4 ? gridPaintMajor : gridPaint,
        );
      }

      // Zero baseline (dashed)
      drawDashedLine(
        canvas,
        Offset(labelWidth, yCenter),
        Offset(size.width - rightPadding, yCenter),
        baselinePaint,
      );

      // Channel border
      canvas.drawLine(
        Offset(0, yOffset + channelHeight),
        Offset(size.width, yOffset + channelHeight),
        Paint()
          ..color = const Color(0xFFCCCCCC)
          ..strokeWidth = 0.8,
      );

      // Vertical divider
      canvas.drawLine(
        Offset(labelWidth, yOffset),
        Offset(labelWidth, yOffset + channelHeight),
        Paint()
          ..color = const Color(0xFFCCCCCC)
          ..strokeWidth = 0.8,
      );

      // ── Channel Label ──
      canvas.save();
      canvas.translate(labelWidth / 2, yCenter);
      canvas.rotate(-pi / 2);
      final labelSpan = TextSpan(
        text: name,
        style: TextStyle(
          color: chColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(-labelPainter.width / 2, -labelPainter.height / 2));
      canvas.restore();

      // ── Electrode position sub-label ──
      final posMap = {
        'TP9': 'L-Temporal',
        'AF7': 'L-Frontal',
        'AF8': 'R-Frontal',
        'TP10': 'R-Temporal',
      };
      final posSpan = TextSpan(
        text: posMap[name] ?? '',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 7,
          fontStyle: FontStyle.italic,
        ),
      );
      final posPainter = TextPainter(
        text: posSpan,
        textDirection: TextDirection.ltr,
      );
      posPainter.layout();
      posPainter.paint(
        canvas,
        Offset(
          (labelWidth - posPainter.width) / 2,
          yCenter + 9,
        ),
      );

      // ── Plot data ──
      final data = channels[name] ?? [];
      if (data.isEmpty) {
        final noDataSpan = TextSpan(
          text: 'Waiting for signal…',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        );
        final noDataPainter = TextPainter(
          text: noDataSpan,
          textDirection: TextDirection.ltr,
        );
        noDataPainter.layout();
        noDataPainter.paint(
          canvas,
          Offset(
            labelWidth + (plotWidth - noDataPainter.width) / 2,
            yCenter - noDataPainter.height / 2,
          ),
        );
        continue;
      }

      // Detrend: remove mean
      double sum = 0;
      for (final val in data) {
        sum += val;
      }
      final mean = sum / data.length;

      // Auto-scale: find max absolute deviation
      double maxDev = 5.0;
      for (final val in data) {
        final dev = (val - mean).abs();
        if (dev > maxDev) maxDev = dev;
      }
      maxDev *= 1.15;

      // Draw waveform
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = chColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final double xStep = plotWidth / (data.length <= 1 ? 1 : data.length - 1);

      for (int k = 0; k < data.length; k++) {
        final double x = labelWidth + k * xStep;
        final double normalizedVal = (data[k] - mean) / maxDev;
        final double y = yCenter - (normalizedVal * (channelHeight / 2) * 0.82);

        if (k == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, wavePaint);

      // ── µV scale indicator (right side) ──
      final scaleBarHeight = channelHeight * 0.3;
      final scaleX = size.width - 5;
      final scaleTop = yCenter - scaleBarHeight / 2;
      final scaleBottom = yCenter + scaleBarHeight / 2;
      final scalePaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(scaleX, scaleTop), Offset(scaleX, scaleBottom), scalePaint);
      canvas.drawLine(Offset(scaleX - 2, scaleTop), Offset(scaleX + 2, scaleTop), scalePaint);
      canvas.drawLine(Offset(scaleX - 2, scaleBottom), Offset(scaleX + 2, scaleBottom), scalePaint);
    }

    // Top border
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, 0),
      Paint()
        ..color = const Color(0xFFCCCCCC)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant EegResearchTracePainter oldDelegate) => true;
}
