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

  static const List<Map<String, dynamic>> _sessions = [
    {
      'name': 'Baseline',
      'emotion': 'neutral',
      'activity': 'baseline',
      'duration': 180,
      'icon': Icons.circle_outlined,
      'color': Color(0xFF9E9E9E),
      'gradient': [Color(0xFF757575), Color(0xFF9E9E9E)],
      'description': 'นั่งนิ่ง หลับตา ไม่คิดอะไร เพื่อเก็บค่า EEG พื้นฐาน',
      'instruction': 'จ้องมองจุดตรงกลางหน้าจอ หายใจปกติ',
    },
    {
      'name': 'ผ่อนคลาย',
      'emotion': 'calm',
      'activity': 'breathing',
      'duration': 300,
      'icon': Icons.self_improvement_rounded,
      'color': Color(0xFF4CAF50),
      'gradient': [Color(0xFF11998e), Color(0xFF38ef7d)],
      'description': 'หายใจลึกๆ ตามจังหวะ 4-7-8 เพื่อเพิ่ม Alpha wave',
      'instruction': 'หายใจเข้า 4 วิ → กลั้น 7 วิ → ออก 8 วิ',
    },
    {
      'name': 'มีความสุข',
      'emotion': 'happy',
      'activity': 'positive_recall',
      'duration': 300,
      'icon': Icons.favorite_rounded,
      'color': Color(0xFFFFC107),
      'gradient': [Color(0xFFf7971e), Color(0xFFffd200)],
      'description': 'นึกถึงความทรงจำที่มีความสุข ช่วงเวลาดีๆ ในชีวิต',
      'instruction': 'หลับตาแล้วนึกถึงเหตุการณ์ที่ทำให้มีความสุขที่สุด',
    },
    {
      'name': 'เครียด (เบา)',
      'emotion': 'stressed',
      'activity': 'mental_arithmetic',
      'duration': 300,
      'icon': Icons.calculate_rounded,
      'color': Color(0xFFF44336),
      'gradient': [Color(0xFFeb3349), Color(0xFFf45c43)],
      'description': 'นับถอยหลังจาก 1000 ลบ 7 ต่อเนื่อง เพื่อกระตุ้น Beta',
      'instruction': 'นับ: 1000, 993, 986, 979... ให้เร็วที่สุด',
    },
    {
      'name': 'เศร้า',
      'emotion': 'sad',
      'activity': 'sad_recall',
      'duration': 300,
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF2196F3),
      'gradient': [Color(0xFF4facfe), Color(0xFF00f2fe)],
      'description': 'นึกถึงเรื่องราวที่ทำให้เศร้าเล็กน้อย',
      'instruction': 'หลับตาแล้วนึกถึงช่วงเวลาที่ทำให้เศร้าใจ',
    },
    {
      'name': 'สมาธิสูง',
      'emotion': 'focused',
      'activity': 'focus_counting',
      'duration': 300,
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF9C27B0),
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
      'description': 'นับลมหายใจจาก 1-10 แล้วเริ่มใหม่ เพื่อกระตุ้น Gamma',
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

    _sampleTimer = Timer.periodic(const Duration(seconds: 5), (t) {
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

    ApiService.saveMuseBrainwave(
      userId: widget.user.id,
      alphaWave: data.alpha,
      betaWave: data.beta,
      thetaWave: data.theta,
      deltaWave: data.delta,
      gammaWave: data.gamma,
      attentionScore: data.attention,
      meditationScore: data.meditation,
      deviceName: widget.museService.deviceName ?? 'Muse 2',
      emotionLabel: session['emotion'],
      activityType: session['activity'],
      sessionPhase: 'stimulation',
    );

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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving
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
                    : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                label: Text(
                  _isSaving ? 'กำลังบันทึก...' : 'บันทึก',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: session['color'],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.primaryBlue),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
            final minutes = (s['duration'] as int) ~/ 60;

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
                                      '$minutes นาที',
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
                        'ควรทำ Baseline ก่อนทุกครั้ง และพัก 2 นาทีระหว่าง session เพื่อให้ข้อมูลแม่นยำ',
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
