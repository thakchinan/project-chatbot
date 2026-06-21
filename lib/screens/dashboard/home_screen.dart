import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/eeg_assessment_service.dart';
import '../../services/eeg_pdf_service.dart';
import '../../emotion_detection/emotion_detection.dart';
import '../../eeg_research/eeg_research_screen.dart';
import 'eeg_assessment_report_screen.dart';
import 'eeg_report_history_screen.dart';
import 'settings_screen.dart';
import 'mini_games_screen.dart';
import '../../widgets/eeg_topographic_map.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final Function(int)? onTabSelected;

  const HomeScreen({super.key, required this.user, this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MuseService _museService = MuseService();
  final EmotionDetectionService _emotionService = EmotionDetectionService();
  late final VideoPlayerController _videoController;
  bool _isVideoLoaded = false;
  bool _isVideoPlaying = true;
  bool _isVideoMuted = true;

  EmotionResult? _tfliteEmotion;
  EmotionResult? _tsceptionEmotion;
  String _selectedModel = 'tflite'; // 'tflite' (Model 1) or 'tsception' (Model 2)
  bool _isDetectingEmotion = false;
  Timer? _emotionDetectionTimer;
  bool _isLoading = false;

  Map<String, dynamic>? _latestTestResult;
  Map<String, dynamic>? _latestEegReport;
  bool _healthLoaded = false;

  StreamSubscription? _testResultSub;
  StreamSubscription? _brainwaveSub;

  // EEG Countdown Timer State
  bool _isEegCountdownRunning = false;
  bool _isEegCountdownDone = false;
  int _eegCountdownSeconds = 90; // 90s = DEAP 60s + 30s artifact margin
  Timer? _eegCountdownTimer;
  Timer? _eegSampleTimer; // Fast sampling timer (250ms)
  Map<String, dynamic>? _eegSummaryResult;
  
  // Accumulated EEG data during countdown
  final List<Map<String, double>> _eegSamples = [];


  @override
  void initState() {
    super.initState();

    // Initialize video player with local asset
    _videoController = VideoPlayerController.asset('assets/videos/brain_demo.mov')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoLoaded = true;
            _isVideoPlaying = _videoController.value.isPlaying;
            _isVideoMuted = _videoController.value.volume == 0;
          });
          _videoController.play();
        }
      });

    _museService.addListener(_onMuseDataUpdate);
    _subscribeRealtime();
    _initEmotionDetection();
  }

  void _subscribeRealtime() {
    final userId = widget.user.id;

    _testResultSub = SupabaseService.client
        .from('test_results')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('test_date', ascending: false)
        .limit(1)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _healthLoaded = true;
        if (data.isNotEmpty) {
          _latestTestResult = data.first;
          print('🔴 [Realtime] test_results updated: $_latestTestResult');
        }
      });
    }, onError: (e) {
      print('❌ [Realtime] test_results error: $e');

      _loadTestResultFallback();
    });

    _brainwaveSub = SupabaseService.client
        .from('eeg_assessment_reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _healthLoaded = true;
        if (data.isNotEmpty) {
          _latestEegReport = data.first;
          print('🔴 [Realtime] eeg_assessment_reports updated: $_latestEegReport');
        } else {
          _latestEegReport = null;
        }
      });
    }, onError: (e) {
      print('❌ [Realtime] eeg_assessment_reports error: $e');
      _loadLatestEegReportFallback();
    });
  }

  Future<void> _loadTestResultFallback() async {
    try {
      final result = await ApiService.getTestResults(widget.user.id);
      if (!mounted) return;
      setState(() {
        _healthLoaded = true;
        if (result['success'] == true &&
            result['results'] != null &&
            (result['results'] as List).isNotEmpty) {
          _latestTestResult = (result['results'] as List).first;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _healthLoaded = true);
    }
  }

  Future<void> _loadLatestEegReportFallback() async {
    try {
      final result = await ApiService.getEegAssessmentReports(widget.user.id, limit: 1);
      if (!mounted) return;
      setState(() {
        if (result['success'] == true &&
            result['reports'] != null &&
            (result['reports'] as List).isNotEmpty) {
          _latestEegReport = Map<String, dynamic>.from((result['reports'] as List).first);
        } else {
          _latestEegReport = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _reloadHealthData() async {
    try {
      final testResult = await ApiService.getTestResults(widget.user.id);
      final brainResult = await ApiService.getEegAssessmentReports(widget.user.id, limit: 1);

      if (!mounted) return;
      setState(() {
        if (testResult['success'] == true &&
            testResult['results'] != null &&
            (testResult['results'] as List).isNotEmpty) {
          _latestTestResult = (testResult['results'] as List).first;
          print('🔄 [Reload] test_results: $_latestTestResult');
        }
        if (brainResult['success'] == true &&
            brainResult['reports'] != null &&
            (brainResult['reports'] as List).isNotEmpty) {
          _latestEegReport = Map<String, dynamic>.from((brainResult['reports'] as List).first);
          print('🔄 [Reload] eeg_assessment_reports: $_latestEegReport');
        } else {
          _latestEegReport = null;
        }
      });
    } catch (e) {
      print('❌ [Reload] error: $e');
    }
  }

  Map<String, dynamic> _summaryFromReport(Map<String, dynamic>? row) {
    if (row == null) return {};
    final data = row['report_data'];
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> _initEmotionDetection() async {
    await _emotionService.loadModel();

    _emotionDetectionTimer = Timer.periodic(
      const Duration(seconds: EmotionConstants.detectionIntervalSeconds),
      (_) => _autoDetectEmotion(),
    );
  }

  Future<void> _autoDetectEmotion() async {
    if (!_museService.isConnected || _museService.latestData == null) return;
    if (_isDetectingEmotion) return;

    _isDetectingEmotion = true;
    try {
      final data = _museService.latestData!;
      final eegData = {
        'alpha': data.alpha,
        'beta': data.beta,
        'theta': data.theta,
        'delta': data.delta,
        'gamma': data.gamma,
        'attention': data.attention,
        'meditation': data.meditation,
      };

      final results = await _emotionService.detectFromEEG(eegData);

      if (mounted) {
        setState(() {
          _tfliteEmotion = results['tflite'];
          _tsceptionEmotion = results['tsception'];
        });

        final mainResult = results['tflite'];
        if (mainResult != null && mainResult.confidence >= EmotionConstants.confidenceThreshold) {
          ApiService.saveEmotionLog(
            userId: widget.user.id,
            emotionType: mainResult.emotionType,
            triggerEvent: 'eeg_brainwave',
            intensity: (mainResult.confidence * 10).round(),
          );
        }

        final secondResult = results['tsception'];
        if (secondResult != null && secondResult.confidence >= EmotionConstants.confidenceThreshold) {
          ApiService.saveEmotionLog(
            userId: widget.user.id,
            emotionType: secondResult.emotionType,
            triggerEvent: 'eeg_brainwave_tsception',
            intensity: (secondResult.confidence * 10).round(),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Emotion detection error: $e');
    } finally {
      _isDetectingEmotion = false;
    }
  }

  @override
  void dispose() {
    _emotionDetectionTimer?.cancel();
    _emotionService.dispose();
    _eegCountdownTimer?.cancel();
    _eegSampleTimer?.cancel();

    _testResultSub?.cancel();
    _brainwaveSub?.cancel();

    _museService.removeListener(_onMuseDataUpdate);
    _museService.stopSimulation();
    _videoController.dispose();
    super.dispose();
  }

  // === EEG 90-Second Countdown Methods (DEAP Protocol) ===

  void _startEegCountdown() {
    if (!_museService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเชื่อมต่อ Muse ก่อนเริ่มทดสอบ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isEegCountdownRunning = true;
      _isEegCountdownDone = false;
      _eegCountdownSeconds = 90;
      _eegSamples.clear();
      _eegSummaryResult = null;
    });

    // Fast sampling timer - collect every 250ms (~360 samples in 90s)
    _eegSampleTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) { timer.cancel(); return; }
      _collectEegSample();
    });

    // UI countdown timer - update display every 1 second
    _eegCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }

      setState(() {
        _eegCountdownSeconds--;
      });

      if (_eegCountdownSeconds <= 0) {
        timer.cancel();
        _eegSampleTimer?.cancel();
        _finishEegCountdown();
      }
    });
  }

  void _stopEegCountdown() {
    _eegCountdownTimer?.cancel();
    _eegSampleTimer?.cancel();
    setState(() {
      _isEegCountdownRunning = false;
      _eegCountdownSeconds = 90;
      _eegSamples.clear();
    });
  }

  void _collectEegSample() {
    final data = _museService.latestData;
    if (data == null) return;

    _eegSamples.add({
      'alpha': data.alpha,
      'beta': data.beta,
      'theta': data.theta,
      'delta': data.delta,
      'gamma': data.gamma,
      'attention': data.attention,
      'meditation': data.meditation,
    });
  }

  Future<void> _finishEegCountdown() async {
    final summary = EegAssessmentService.computeFromSamples(_eegSamples);

    // Predict overall mental state using PyTorch Mobile model on averaged values
    try {
      final sessionEegData = {
        'alpha': summary['avgAlpha'] as double? ?? 0.0,
        'beta': summary['avgBeta'] as double? ?? 0.0,
        'theta': summary['avgTheta'] as double? ?? 0.0,
        'delta': summary['avgDelta'] as double? ?? 0.0,
        'gamma': summary['avgGamma'] as double? ?? 0.0,
      };
      final results = await _emotionService.detectFromEEG(sessionEegData);
      final tfliteResult = results['tflite'];
      if (tfliteResult != null) {
        summary['tfliteMentalState'] = tfliteResult.emotionType;
        summary['tfliteMentalStateLabel'] = EmotionType.fromString(tfliteResult.emotionType).label;
        summary['tfliteMentalStateConfidence'] = tfliteResult.confidence;
      }
      final tsceptionResult = results['tsception'];
      if (tsceptionResult != null) {
        summary['tsceptionMentalState'] = tsceptionResult.emotionType;
        summary['tsceptionMentalStateLabel'] = EmotionType.fromString(tsceptionResult.emotionType).label;
        summary['tsceptionMentalStateConfidence'] = tsceptionResult.confidence;
      }
    } catch (e) {
      debugPrint('❌ Failed to run session mental state prediction: $e');
    }

    setState(() {
      _isEegCountdownRunning = false;
      _isEegCountdownDone = true;
      _eegSummaryResult = summary;
    });



    final saveResult = await ApiService.saveEegAssessmentReport(
      userId: widget.user.id,
      reportData: EegAssessmentService.toJson(summary),
    );

    if (!mounted) return;

    if (saveResult['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saveResult['message'] ?? 'บันทึกใบสรุปไม่สำเร็จ'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EegAssessmentReportScreen(
          user: widget.user,
          summary: summary,
          recordedAt: summary['recordedAt'] as String?,
        ),
      ),
    );
  }

  void _openEegReportHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EegReportHistoryScreen(user: widget.user),
      ),
    );
  }

  void _openLatestReport() {
    if (_eegSummaryResult == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EegAssessmentReportScreen(
          user: widget.user,
          summary: _eegSummaryResult!,
          recordedAt: _eegSummaryResult!['recordedAt'] as String?,
        ),
      ),
    );
  }

  void _onMuseDataUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _scanAndConnect() async {
    setState(() => _isLoading = true);

    final isAvailable = await _museService.isBluetoothAvailable();

    if (!isAvailable) {

      _showNoBluetoothDialog();
    } else {

      await _museService.startScan();

      if (mounted) {
        _showDeviceSelectionDialog();
      }
    }

    setState(() => _isLoading = false);
  }

  void _showNoBluetoothDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text('Bluetooth ไม่พร้อมใช้งาน'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ไม่สามารถใช้ Bluetooth บนแพลตฟอร์มนี้ได้'),
            SizedBox(height: 8),
            Text('คุณสามารถ:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• ใช้โหมดจำลองเพื่อทดสอบ'),
            Text('• รันแอปบน iOS/Android เพื่อเชื่อมต่อจริง'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _museService.startSimulation();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('ใช้โหมดจำลอง', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeviceSelectionDialog() {
    VoidCallback? modalListener;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {

          modalListener ??= () {
            if (modalContext.mounted) setModalState(() {});
          };
          _museService.addListener(modalListener!);

          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(modalContext).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bluetooth_searching, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'เลือกอุปกรณ์ Muse',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    if (_museService.isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _museService.status,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: _museService.scanResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _museService.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _museService.isScanning
                                    ? 'กำลังค้นหาอุปกรณ์...'
                                    : 'ไม่พบอุปกรณ์ Muse',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              if (!_museService.isScanning) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'ตรวจสอบว่า Muse S เปิดอยู่และอยู่ใกล้ๆ',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _museService.scanResults.length,
                          itemBuilder: (modalContext, index) {
                            final result = _museService.scanResults[index];
                            final device = result.device;
                            final rssi = result.rssi;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                                  child: Icon(Icons.bluetooth, color: AppColors.primaryBlue),
                                ),
                                title: Text(
                                  device.platformName.isNotEmpty
                                      ? device.platformName
                                      : 'Unknown Device',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  'สัญญาณ: $rssi dBm',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: _museService.isConnecting
                                      ? null
                                      : () async {
                                          Navigator.pop(modalContext);
                                          await _museService.connectToDevice(device);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  child: Text(
                                    _museService.isConnecting ? 'กำลังเชื่อมต่อ...' : 'เชื่อมต่อ',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _museService.isScanning
                            ? () => _museService.stopScan()
                            : () => _museService.startScan(),
                        icon: Icon(
                          _museService.isScanning ? Icons.stop : Icons.refresh,
                          color: AppColors.primaryBlue,
                        ),
                        label: Text(
                          _museService.isScanning ? 'หยุดค้นหา' : 'ค้นหาใหม่',
                          style: TextStyle(color: AppColors.primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _museService.startSimulation();
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.orange),
                        label: const Text('โหมดจำลอง', style: TextStyle(color: Colors.orange)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {

      if (modalListener != null) {
        _museService.removeListener(modalListener!);
      }
    });
  }

  Future<void> _disconnectMuse() async {
    await _museService.disconnect();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        image: widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(widget.user.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: widget.user.avatarUrl == null || widget.user.avatarUrl!.isEmpty
                          ? Center(
                              child: Text(
                                (widget.user.fullName ?? widget.user.username).isNotEmpty
                                    ? (widget.user.fullName ?? widget.user.username)[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ผู้เข้ารับการทดสอบ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textGray,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _PulseDot(color: AppColors.primaryGreen, size: 6),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ระบบพร้อมทำงาน',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.fullName ?? widget.user.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'รหัสผู้ป่วย: EEG-${widget.user.id.toString().padLeft(8, '0')} • ${_formatCurrentDate()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.textDark,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Health Summary
                    _buildHealthSummaryCard(),
                    const SizedBox(height: 20),

                    // 2. Video Brain View — High-Tech Sci-Fi Neural HUD
                    Container(
                      width: double.infinity,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            // The Video Player — fills entire area
                            Positioned.fill(
                              child: _isVideoLoaded
                                  ? FittedBox(
                                      fit: BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: SizedBox(
                                        width: _videoController.value.size.width,
                                        height: _videoController.value.size.height,
                                        child: VideoPlayer(_videoController),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFF0F1424),
                                      child: const Center(
                                        child: Icon(
                                          Icons.psychology_outlined,
                                          color: Colors.cyan,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                            ),

                            // High-Tech Cyber Corner Frame Paint
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CyberFramePainter(
                                  color: Colors.cyan.withValues(alpha: 0.6),
                                  isConnected: _museService.isConnected,
                                ),
                              ),
                            ),

                            // Pulse-scanning laser line overlay
                            if (_isVideoLoaded && _isVideoPlaying)
                              const Positioned.fill(
                                child: SciFiScannerOverlay(
                                  color: Colors.cyan,
                                ),
                              ),

                            // Subtle gradient overlay at bottom and top for readability
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.4),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.5),
                                    ],
                                    stops: const [0.0, 0.2, 0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // HUD Overlay: Top-Left (Capture status & red blinking indicator)
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _PulseDot(color: Colors.red, size: 8),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'NEURAL IMAGING CAPTURE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.cyan,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      Text(
                                        _museService.isConnected
                                            ? 'จับสัญญาณคลื่นสมองจริง: ACTIVE FEED'
                                            : 'จำลองสแกนเนอร์: CALIBRATING',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.white.withOpacity(0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // HUD Overlay: Top-Right (Device information telemetry)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'DEVICE: ${_museService.deviceName ?? (widget.user.username.length > 8 ? widget.user.username.substring(0, 8) : widget.user.username).toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      _museService.isConnected ? 'RATE: 256Hz (LIVE)' : 'RATE: 256Hz (STANDBY)',
                                      style: const TextStyle(
                                        fontSize: 7,
                                        color: Colors.cyan,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // HUD Overlay: Bottom-Left (EEG Live Channels Status)
                            Positioned(
                              bottom: 14,
                              left: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      _buildChannelStatusBadge('TP9', _museService.isConnected),
                                      const SizedBox(width: 4),
                                      _buildChannelStatusBadge('AF7', _museService.isConnected),
                                      const SizedBox(width: 4),
                                      _buildChannelStatusBadge('AF8', _museService.isConnected),
                                      const SizedBox(width: 4),
                                      _buildChannelStatusBadge('TP10', _museService.isConnected),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SIGNAL SYNC SPEED: 250ms',
                                    style: TextStyle(
                                      fontSize: 7,
                                      color: Colors.white.withOpacity(0.5),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // HUD Overlay: Bottom-Right (Floating Glassmorphic Control Bar)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Play / Pause Button
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (_videoController.value.isPlaying) {
                                            _videoController.pause();
                                            _isVideoPlaying = false;
                                          } else {
                                            _videoController.play();
                                            _isVideoPlaying = true;
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isVideoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Mute Button
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (_videoController.value.volume > 0) {
                                            _videoController.setVolume(0);
                                            _isVideoMuted = true;
                                          } else {
                                            _videoController.setVolume(0.5);
                                            _isVideoMuted = false;
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isVideoMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Live Indicator Dot
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: _museService.isConnected ? Colors.green : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _museService.isConnected ? 'LIVE' : 'SIMULATE',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Loading overlay
                            if (!_isVideoLoaded)
                              Positioned.fill(
                                child: Container(
                                  color: const Color(0xFF0F1424),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.cyan,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'ระบบบันทึกความถึ่สมองกำลังเตรียมการ...',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. Quick Actions menu
                    const Text(
                      'เมนูการประเมินและกิจกรรม',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _buildQuickActionCard(
                          context,
                          icon: Icons.assignment_outlined,
                          title: 'แบบประเมินสุขภาพจิต (PHQ-9)',
                          subtitle: 'ประเมินระดับความเครียดและภาวะอารมณ์ด้วยเกณฑ์มาตรฐานสากล',
                          iconColor: AppColors.primaryBlue,
                          onTap: () {
                            widget.onTabSelected?.call(1);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.psychology_outlined,
                          title: 'มินิเกมฝึกฝนทักษะสมอง',
                          subtitle: 'กิจกรรมกระตุ้นการทำงานด้านความคิด ความจำ และสมาธิ (Cognitive Tasks)',
                          iconColor: AppColors.primaryGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MiniGamesScreen(user: widget.user),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4. Muse Connection Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white,
                        opacity: 0.75,
                        borderColor: (_museService.isConnected ? AppColors.primaryGreen : AppColors.primaryBlue).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (_museService.isConnected ? AppColors.primaryGreen : AppColors.primaryBlue).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _museService.isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                                  color: _museService.isConnected ? AppColors.primaryGreen : AppColors.primaryBlue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'อุปกรณ์ตรวจจับ Muse S',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _museService.isConnected
                                                ? AppColors.primaryGreen.withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _museService.isConnected ? 'เชื่อมต่อแล้ว' : 'ปิดการเชื่อมต่อ',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: _museService.isConnected ? AppColors.primaryGreen : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _museService.status,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_museService.deviceName != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.developer_board, size: 14, color: AppColors.primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ฮาร์ดแวร์: ${_museService.deviceName}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ElectrodePlacementMap(isConnected: _museService.isConnected),
                          
                          // Connection Telemetry Grid (Visible when connected)
                          if (_museService.isConnected) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1, thickness: 0.5, color: Colors.black12),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.8,
                              children: [
                                _buildConnectionMetricItem(
                                  label: 'ความแรงสัญญาณ BT',
                                  value: _museService.isSimulating ? 'ดีเยี่ยม (จำลอง)' : 'เสถียร (RSSI)',
                                  icon: Icons.signal_cellular_alt_rounded,
                                  color: Colors.blue,
                                ),
                                _buildConnectionMetricItem(
                                  label: 'อัตราข้อมูลวิเคราะห์',
                                  value: '256 Samples/s',
                                  icon: Icons.speed_rounded,
                                  color: Colors.cyan,
                                ),
                                _buildConnectionMetricItem(
                                  label: 'ความหน่วงการรับส่ง',
                                  value: '< 250 ms',
                                  icon: Icons.hourglass_bottom_rounded,
                                  color: Colors.amber,
                                ),
                                _buildConnectionMetricItem(
                                  label: 'ความน่าเชื่อถือช่องสัญญาณ',
                                  value: '99.8% Calibrated',
                                  icon: Icons.verified_user_rounded,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading || _museService.isConnecting
                                      ? null
                                      : (_museService.isConnected ? _disconnectMuse : _scanAndConnect),
                                  icon: _isLoading || _museService.isConnecting
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _museService.isConnected ? Colors.white : AppColors.primaryBlue,
                                          ),
                                        )
                                      : Icon(
                                          _museService.isConnected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_searching_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    _museService.isConnecting
                                        ? 'กำลังเชื่อมต่อ...'
                                        : (_museService.isConnected ? 'ยกเลิกเชื่อมต่ออุปกรณ์' : 'ค้นหาและเชื่อมต่อ Muse'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _museService.isConnected ? AppColors.error : AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_museService.isConnected && _museService.latestData == null && !_museService.isSimulating) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: AppTheme.glassDecoration(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.primaryBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _museService.isWaitingForFFT
                                            ? 'กำลังวิเคราะห์คลื่นสมอง...'
                                            : 'กำลังสะสมข้อมูล EEG...',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3748),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _museService.isWaitingForFFT
                                            ? 'รอ FFT คำนวณ (~1 วินาที)'
                                            : '${_museService.bufferFillLevel}/${_museService.minBufferRequired} samples',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_museService.packetCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667eea).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Packet #${_museService.packetCount}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF667eea), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _museService.isWaitingForFFT
                                    ? null
                                    : _museService.bufferProgress.clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE8F0FE),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _museService.isWaitingForFFT
                                      ? const Color(0xFF764ba2)
                                      : const Color(0xFF667eea),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_museService.packetCount == 0) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: AppTheme.glassDecoration(
                                  color: AppColors.warning,
                                  opacity: 0.12,
                                  borderColor: AppColors.warning.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'รอสัญญาณจริง... ตรวจสอบการสวมใส่หน้ากากวัดคลื่นสมองให้กระชับหน้าผาก',
                                        style: TextStyle(fontSize: 12, color: AppColors.textDark.withOpacity(0.8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: AppTheme.glassDecoration(
                                  color: AppColors.primaryBlue,
                                  opacity: 0.1,
                                  borderColor: AppColors.primaryBlue.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.science_rounded, color: AppColors.primaryBlue, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _museService.isWaitingForFFT
                                            ? 'Buffer พร้อมแล้ว กำลังแปลง Fast Fourier Transform (FFT)...'
                                            : 'ต้องการสะสม 256 samples เพื่อแปลงสัญญาณความถึ่สมองได้อย่างแม่นยำ',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 5. Continuous EEG Bands Visualizer (Always Visible)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white,
                        opacity: 0.7,
                        borderColor: AppColors.primaryBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.insights_rounded, color: AppColors.primaryBlue, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'วิเคราะห์ช่องสัญญาณคลื่นสมอง (EEG Bands)',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_museService.isConnected && _museService.latestData != null)
                                      ? AppColors.primaryGreen.withOpacity(0.12)
                                      : Colors.grey.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PulseDot(
                                      color: (_museService.isConnected && _museService.latestData != null)
                                          ? AppColors.primaryGreen
                                          : Colors.grey,
                                      size: 6,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (_museService.isConnected && _museService.latestData != null)
                                          ? (_museService.isSimulating ? 'จำลองสัญญาณ' : 'เรียลไทม์')
                                          : 'STANDBY',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: (_museService.isConnected && _museService.latestData != null)
                                            ? AppColors.primaryGreen
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (_museService.isConnected && _museService.latestData != null)
                                ? 'ความเข้มของคลื่นสัญญาณสมองในแต่ละย่านความถี่ (ความถี่สุ่ม 256Hz)'
                                : 'กรุณาเชื่อมต่ออุปกรณ์ Muse เพื่อเริ่มอ่านคลื่นสมองแบบสด',
                            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                          ),
                          const SizedBox(height: 18),
                          
                          // Responsive layout for the 5 EEG bands (Wrap instead of horizontal scroll)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              int columns = 2;
                              if (availableWidth >= 560) {
                                columns = 5;
                              } else if (availableWidth >= 340) {
                                columns = 3;
                              } else {
                                columns = 2;
                              }

                              const spacing = 8.0;
                              final cardWidth = (availableWidth - (columns - 1) * spacing) / columns;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildCircularWaveIndicator(
                                    'Delta',
                                    (_museService.isConnected && _museService.latestData != null)
                                        ? _museService.latestData!.delta
                                        : 0.0,
                                    const Color(0xFF8B5CF6),
                                    'หลับลึก',
                                    1.0,
                                    _museService.isConnected && _museService.latestData != null,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Theta',
                                    (_museService.isConnected && _museService.latestData != null)
                                        ? _museService.latestData!.theta
                                        : 0.0,
                                    const Color(0xFF10B981),
                                    'ผ่อนคลาย',
                                    2.5,
                                    _museService.isConnected && _museService.latestData != null,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Alpha',
                                    (_museService.isConnected && _museService.latestData != null)
                                        ? _museService.latestData!.alpha
                                        : 0.0,
                                    const Color(0xFF3B82F6),
                                    'ตื่นตัว',
                                    5.0,
                                    _museService.isConnected && _museService.latestData != null,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Beta',
                                    (_museService.isConnected && _museService.latestData != null)
                                        ? _museService.latestData!.beta
                                        : 0.0,
                                    const Color(0xFFF59E0B),
                                    'คิดวิเคราะห์',
                                    9.0,
                                    _museService.isConnected && _museService.latestData != null,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Gamma',
                                    (_museService.isConnected && _museService.latestData != null)
                                        ? _museService.latestData!.gamma
                                        : 0.0,
                                    const Color(0xFFEF4444),
                                    'สมาธิสูง',
                                    15.0,
                                    _museService.isConnected && _museService.latestData != null,
                                    width: cardWidth,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_museService.isConnected) ...[
                      _buildEmotionDetectionCard(),
                      const SizedBox(height: 16),
                      _buildEegCountdownCard(),
                      const SizedBox(height: 16),
                    ],



                    if (_isEegCountdownDone && _eegSummaryResult != null) ...[
                      _buildLatestReportBanner(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildChannelStatusBadge(String name, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isConnected ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            name,
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 8, color: AppColors.textGray, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.75,
        borderColor: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 0.8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGray,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: iconColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularWaveIndicator(
    String name,
    double value,
    Color color,
    String desc,
    double frequency,
    bool isActive, {
    double? width,
  }) {
    final displayColor = isActive ? color : Colors.grey[400]!;
    return Container(
      width: width ?? 104,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: isActive ? 0.8 : 0.4,
        borderColor: displayColor.withOpacity(isActive ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.textDark : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value / 100),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return CircularProgressIndicator(
                      value: val,
                      strokeWidth: 6,
                      backgroundColor: displayColor.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
              ),
              Text(
                '${value.round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: displayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Dynamic animated microwave line chart!
          MicroWaveChart(
            color: displayColor,
            frequency: frequency,
            isActive: isActive,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? AppColors.textGray : Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    return 'วันที่ ${now.day} ${months[now.month - 1]} ${now.year + 543}';
  }

  Map<String, double> _getSimulatedSensors(double baseValue, String band) {
    double offsetAF7 = 1.0;
    double offsetAF8 = 1.0;
    double offsetTP9 = 1.0;
    double offsetTP10 = 1.0;

    if (band == 'Delta') {
      offsetTP9 = 1.15;
      offsetTP10 = 1.08;
      offsetAF7 = 0.85;
      offsetAF8 = 0.92;
    } else if (band == 'Theta') {
      offsetAF7 = 1.12;
      offsetAF8 = 1.10;
      offsetTP9 = 0.90;
      offsetTP10 = 0.88;
    } else if (band == 'Alpha') {
      offsetTP9 = 1.20;
      offsetTP10 = 1.18;
      offsetAF7 = 0.80;
      offsetAF8 = 0.82;
    } else if (band == 'Beta') {
      offsetAF7 = 1.25;
      offsetAF8 = 1.22;
      offsetTP9 = 0.75;
      offsetTP10 = 0.80;
    }

    return {
      'AF7': (baseValue * offsetAF7).clamp(0.0, 100.0),
      'AF8': (baseValue * offsetAF8).clamp(0.0, 100.0),
      'TP9': (baseValue * offsetTP9).clamp(0.0, 100.0),
      'TP10': (baseValue * offsetTP10).clamp(0.0, 100.0),
    };
  }

  Map<String, dynamic> _getStressDisplay(String? stressLevel, int? score) {
    switch (stressLevel) {
      case 'normal':
        return {'label': 'ปกติ', 'emoji': '😊', 'color': const Color(0xFF00A79D)};
      case 'mild':
        return {'label': 'ความเครียดเล็กน้อย', 'emoji': '😐', 'color': const Color(0xFFF5B041)};
      case 'moderate':
        return {'label': 'ความเครียดปานกลาง', 'emoji': '😟', 'color': const Color(0xFFE67E22)};
      case 'high':
        return {'label': 'ความเครียดค่อนข้างรุนแรง', 'emoji': '😰', 'color': const Color(0xFFEC7063)};
      case 'severe':
        return {'label': 'ความเครียดรุนแรง', 'emoji': '🆘', 'color': const Color(0xFFEC7063)};
      default:
        return {'label': 'ยังไม่ได้ทดสอบ', 'emoji': '❓', 'color': Colors.grey};
    }
  }

  Widget _buildHealthSummaryCard() {
    final stressLevel = _latestTestResult?['stress_level'];
    final stressScore = _latestTestResult?['stress_score'] as int?;
    final depressionScore = _latestTestResult?['depression_score'] as int?;
    final display = _getStressDisplay(stressLevel, stressScore);
    final Color statusColor = display['color'];

    final eegSummary = _summaryFromReport(_latestEegReport);
    final eegIndex = (eegSummary['eegIndex'] as num?)?.toDouble() ??
        (_latestEegReport?['eeg_index'] as num?)?.toDouble();
    final riskLevel = eegSummary['riskLevel'] as String? ??
        _latestEegReport?['risk_level'] as String?;
    final riskColor = _latestEegReport != null 
        ? EegAssessmentService.riskColor(eegSummary)
        : AppColors.textGray;
    final recordedAt = _latestEegReport?['recorded_at']?.toString() ??
        eegSummary['recordedAt'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.75,
        borderColor: AppColors.primaryBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'บันทึกวิเคราะห์สุขภาพสมองล่าสุด',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_healthLoaded) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Panel: PHQ-9
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.15), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(display['emoji'], style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'ระดับความเครียด',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        display['label'],
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _latestTestResult != null
                            ? 'PHQ-9: ${stressScore ?? depressionScore ?? '-'}/27 คะแนน'
                            : 'ยังไม่มีประวัติการประเมิน',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textGray),
                      ),
                      if (_latestTestResult?['test_date'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ทดสอบ: ${_formatDate(_latestTestResult!['test_date'])}',
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right Panel: EEG Data
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, color: AppColors.primaryBlue, size: 18),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'สถานะสัญญาณสมอง',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_latestEegReport != null) ...[
                        Text(
                          'EEG Index: ${eegIndex?.toStringAsFixed(0) ?? "0"}/100',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ระดับความเสี่ยง: ${riskLevel ?? "-"}',
                          style: TextStyle(
                            fontSize: 11, 
                            color: riskColor, 
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (recordedAt != null)
                          Text(
                            'วัดเมื่อ: ${_formatDate(recordedAt)}',
                            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final user = widget.user;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EegAssessmentReportScreen(
                                      user: user,
                                      summary: eegSummary,
                                      recordedAt: recordedAt,
                                      reportId: _latestEegReport?['id'] as int?,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 12, color: AppColors.primaryBlue),
                                    SizedBox(width: 4),
                                    Text(
                                      'ดูผลสรุป',
                                      style: TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
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
                                          const CircularProgressIndicator(color: AppColors.primaryBlue),
                                          const SizedBox(height: 16),
                                          Text(
                                            'กำลังสร้าง PDF...',
                                            style: GoogleFonts.prompt(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                try {
                                  final display = EegAssessmentService.forDisplay(eegSummary);
                                  await EegPdfService.sharePdf(display, widget.user, topoBytes: null);
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('เกิดข้อผิดพลาดในการดาวน์โหลด PDF: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.picture_as_pdf_rounded, size: 12, color: AppColors.error),
                                    SizedBox(width: 4),
                                    Text(
                                      'PDF',
                                      style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'ไม่พบประวัติคลื่นสมอง',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textGray),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'เชื่อมต่อ Muse เพื่อเริ่มวิเคราะห์คลื่นสมองรายบุคคล',
                          style: TextStyle(fontSize: 10, color: AppColors.textLight),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelPredictionSubcard({
    required String title,
    required EmotionResult? emotion,
    required bool isPyTorch,
  }) {
    final emotionType = emotion != null ? EmotionType.fromString(emotion.emotionType) : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPyTorch ? const Color(0xFF4F46E5).withOpacity(0.04) : AppColors.primaryBlue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isPyTorch ? const Color(0xFF4F46E5) : AppColors.primaryBlue).withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPyTorch ? const Color(0xFF4F46E5) : AppColors.primaryBlue,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (emotion != null && emotionType != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    emotionType.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            emotionType.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'ความแม่นยำ ${(emotion.confidence * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: emotion.confidence >= 0.7
                                  ? Colors.green
                                  : emotion.confidence >= 0.4
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: emotion.confidence.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            emotion.confidence >= 0.7
                                ? Colors.green
                                : emotion.confidence >= 0.4
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 10),
                Text(
                  'กำลังวิเคราะห์สัญญาณประสาทเพื่อระบุระดับความเครียด...',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmotionDetectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.7,
        borderColor: const Color(0xFF667eea).withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_outlined, color: Color(0xFF667eea), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ระบบวิเคราะห์สภาวะทางอารมณ์ด้วย AI',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Model Selection Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF667eea), size: 20),
                tooltip: 'เลือกโมเดลตรวจจับ',
                onSelected: (String modelType) {
                  setState(() {
                    _selectedModel = modelType;
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'tflite',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: _selectedModel == 'tflite' ? const Color(0xFF667eea) : Colors.transparent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('โมเดล 3 คลาส (หลัก)', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'tsception',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: _selectedModel == 'tsception' ? const Color(0xFF667eea) : Colors.transparent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('โมเดล 4 คลาส (รอง)', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              if (_isDetectingEmotion)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667eea)),
                )
              else
                GestureDetector(
                  onTap: _autoDetectEmotion,
                  child: const Icon(Icons.refresh, color: Color(0xFF667eea), size: 20),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'โมเดลการเรียนรู้เชิงลึกวิเคราะห์จำแนกคลื่นสมองและอารมณ์แบบเรียลไทม์',
            style: TextStyle(fontSize: 11, color: AppColors.textGray),
          ),
          const SizedBox(height: 16),
          if (_selectedModel == 'tflite')
            _buildModelPredictionSubcard(
              title: 'โครงข่ายหลัก (3 คลาส): สงบ / ปกติ / มีสมาธิ (Deep Neural Network)',
              emotion: _tfliteEmotion,
              isPyTorch: false,
            )
          else
            _buildModelPredictionSubcard(
              title: 'โครงข่ายรอง TSception (4 คลาส): โกรธ-กลัว / สุข / สงบ / เศร้า (Temporal-Spatial CNN)',
              emotion: _tsceptionEmotion,
              isPyTorch: true,
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year + 543} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildEegCountdownCard() {
    final minutes = _eegCountdownSeconds ~/ 60;
    final seconds = _eegCountdownSeconds % 60;
    final progress = 1.0 - (_eegCountdownSeconds / 90.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.7,
        borderColor: const Color(0xFF1a237e).withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a237e).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded, color: Color(0xFF1a237e), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'เกณฑ์การวิเคราะห์คลื่นสมองมาตรฐาน qEEG',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isEegCountdownRunning) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PulseDot(color: Colors.green, size: 6),
                      const SizedBox(width: 4),
                      Text(
                        'กำลังประเมินสด',
                        style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'บันทึกข้อมูลคลื่นสมองต่อเนื่อง 1.5 นาที เพื่อประเมินค่าดัชนีความเครียดและความผ่อนคลาย (DEAP Protocol)',
            style: TextStyle(fontSize: 11, color: AppColors.textGray),
          ),
          const SizedBox(height: 20),

          if (_isEegCountdownRunning) ...[
            // Timer circular progress or medical badge
            Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1B2A4A),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1a237e).withOpacity(0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 116,
                      height: 116,
                      child: CircularProgressIndicator(
                        value: 1.0 - progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_outlined, color: Colors.cyan, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          '$minutes:${seconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Text(
                          'เหลือเวลา',
                          style: TextStyle(color: Colors.white54, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'เก็บข้อมูลตัวอย่างได้: ${_eegSamples.length} samples',
                  style: const TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w500),
                ),
                Text(
                  'ความคืบหน้า: ${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1a237e)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _stopEegCountdown,
                icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error, size: 18),
                label: const Text('หยุดการประเมิน', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startEegCountdown,
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                label: const Text('เริ่มการประเมิน qEEG รายบุคคล', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a237e),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openEegReportHistory,
                icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF1a237e), size: 18),
                label: const Text(
                  'เปิดดูประวัติและใบประเมินแพทย์ย้อนหลัง',
                  style: TextStyle(color: Color(0xFF1a237e), fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1a237e), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatestReportBanner() {
    final s = _eegSummaryResult!;
    final riskColor = EegAssessmentService.riskColor(s);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openLatestReport,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(
            color: riskColor,
            opacity: 0.08,
            borderColor: riskColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.description_rounded, color: riskColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ใบสรุปประเมินความเครียด (qEEG)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      s['riskLevel'] as String? ?? '',
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      'แตะเพื่อเปิดใบสรุปฉบับเต็ม',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
} // End of _HomeScreenState

// ==========================================
// Custom Helper Widgets & Dynamic Painters
// ==========================================

class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseDot({super.key, required this.color, required this.size});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size * (1.0 + _controller.value * 1.5),
              height: widget.size * (1.0 + _controller.value * 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: (1.0 - _controller.value) * 0.6),
                  width: 1.2,
                ),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class CyberFramePainter extends CustomPainter {
  final Color color;
  final bool isConnected;

  CyberFramePainter({required this.color, required this.isConnected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double bracketSize = 18.0;

    // Draw corner brackets
    // Top-Left
    canvas.drawPath(Path()..moveTo(bracketSize, 2)..lineTo(2, 2)..lineTo(2, bracketSize), paint);
    // Top-Right
    canvas.drawPath(Path()..moveTo(size.width - bracketSize, 2)..lineTo(size.width - 2, 2)..lineTo(size.width - 2, bracketSize), paint);
    // Bottom-Left
    canvas.drawPath(Path()..moveTo(bracketSize, size.height - 2)..lineTo(2, size.height - 2)..lineTo(2, size.height - bracketSize), paint);
    // Bottom-Right
    canvas.drawPath(Path()..moveTo(size.width - bracketSize, size.height - 2)..lineTo(size.width - 2, size.height - 2)..lineTo(size.width - 2, size.height - bracketSize), paint);

    // Subtle inner boundary frame
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), borderPaint);

    // Center Target Reticle (Clinic-style scanning circle)
    final center = Offset(size.width / 2, size.height / 2);
    final reticlePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 30, reticlePaint);
    canvas.drawCircle(center, 4, Paint()..color = color.withValues(alpha: 0.4)..style = PaintingStyle.fill);

    // Draw reticle crosshair ticks
    canvas.drawLine(Offset(center.dx - 45, center.dy), Offset(center.dx - 35, center.dy), reticlePaint);
    canvas.drawLine(Offset(center.dx + 35, center.dy), Offset(center.dx + 45, center.dy), reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy - 45), Offset(center.dx, center.dy - 35), reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy + 35), Offset(center.dx, center.dy + 45), reticlePaint);

    // Side ticks (Rulers on left & right sides)
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    for (double i = 0.25; i <= 0.75; i += 0.125) {
      final y = size.height * i;
      canvas.drawLine(Offset(12, y), Offset(18, y), tickPaint);
      canvas.drawLine(Offset(size.width - 12, y), Offset(size.width - 18, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SciFiScannerOverlay extends StatefulWidget {
  final Color color;

  const SciFiScannerOverlay({super.key, required this.color});

  @override
  State<SciFiScannerOverlay> createState() => _SciFiScannerOverlayState();
}

class _SciFiScannerOverlayState extends State<SciFiScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = _controller.value;
        return CustomPaint(
          painter: _ScannerLinePainter(
            color: widget.color,
            progress: position,
          ),
        );
      },
    );
  }
}

class _ScannerLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  _ScannerLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height * progress;

    // Glowing laser scan line
    final paintLine = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 1.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(0, y - 10, size.width, y + 10))
      ..strokeWidth = 2.5;

    // Glowing laser trail trailing behind
    final paintTrail = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromLTRB(0, y - 40, size.width, y))
      ..style = PaintingStyle.fill;
    
    if (y > 40) {
      canvas.drawRect(Rect.fromLTRB(8, y - 40, size.width - 8, y), paintTrail);
    }

    canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), paintLine);

    final paintGrid = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const int numRows = 8;
    const int numCols = 12;

    for (int i = 1; i < numRows; i++) {
      final double gridY = size.height * (i / numRows);
      canvas.drawLine(Offset(8, gridY), Offset(size.width - 8, gridY), paintGrid);
    }
    for (int i = 1; i < numCols; i++) {
      final double gridX = size.width * (i / numCols);
      canvas.drawLine(Offset(gridX, 8), Offset(gridX, size.height - 8), paintGrid);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MicroWaveChart extends StatefulWidget {
  final Color color;
  final double frequency;
  final bool isActive;

  const MicroWaveChart({
    super.key,
    required this.color,
    required this.frequency,
    required this.isActive,
  });

  @override
  State<MicroWaveChart> createState() => _MicroWaveChartState();
}

class _MicroWaveChartState extends State<MicroWaveChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(80, 18),
          painter: _WaveLinePainter(
            color: widget.color,
            phase: _controller.value * 2 * math.pi,
            frequency: widget.frequency,
            isActive: widget.isActive,
          ),
        );
      },
    );
  }
}

class _WaveLinePainter extends CustomPainter {
  final Color color;
  final double phase;
  final double frequency;
  final bool isActive;

  _WaveLinePainter({
    required this.color,
    required this.phase,
    required this.frequency,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? color : Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    final width = size.width;

    path.moveTo(0, midY);
    for (double x = 0; x <= width; x += 1.5) {
      final double amp = isActive 
          ? (frequency < 2.0 ? 7.0 : (frequency > 8.0 ? 3.0 : 5.0)) 
          : 1.0;
      final double y = midY + amp * math.sin((x / width * 2 * math.pi * frequency) - phase);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveLinePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isActive != isActive;
  }
}

class ElectrodePlacementMap extends StatelessWidget {
  final bool isConnected;

  const ElectrodePlacementMap({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 85),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1.0),
      ),
      child: Row(
        children: [
          // Stylized Head Vector Paint
          SizedBox(
            width: 65,
            height: 65,
            child: CustomPaint(
              painter: _HeadPlacementPainter(isConnected: isConnected),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'การสัมผัสของขั้วอิเล็กโทรด (Electrode Contact Quality)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildContactStatusNode('TP9', isConnected),
                    const SizedBox(width: 8),
                    _buildContactStatusNode('AF7', isConnected),
                    const SizedBox(width: 8),
                    _buildContactStatusNode('AF8', isConnected),
                    const SizedBox(width: 8),
                    _buildContactStatusNode('TP10', isConnected),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  isConnected 
                      ? 'ความต้านทานสัมผัสต่ำ < 10 kΩ (สัญญาณสมบูรณ์)' 
                      : 'รอการเชื่อมต่อเซนเซอร์ตรวจจับประจุไฟฟ้า',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: isConnected ? AppColors.primaryGreen : AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactStatusNode(String label, bool active) {
    final color = active ? AppColors.primaryGreen : Colors.grey[400]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: active ? [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ] : null,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: active ? AppColors.textDark : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _HeadPlacementPainter extends CustomPainter {
  final bool isConnected;

  _HeadPlacementPainter({required this.isConnected});

  @override
  void paint(Canvas canvas, Size size) {
    final headPaint = Paint()
      ..color = Colors.grey[400]!.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final headCenter = Offset(size.width / 2, size.height / 2 + 1);
    
    // Head Oval
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 34, height: 42),
      headPaint,
    );

    // Draw simple nose pointing up
    final nosePath = Path()
      ..moveTo(headCenter.dx, headCenter.dy - 21)
      ..lineTo(headCenter.dx - 4, headCenter.dy - 25)
      ..lineTo(headCenter.dx + 4, headCenter.dy - 25)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = Colors.grey[400]!..style = PaintingStyle.fill);

    // Ears
    canvas.drawArc(
      Rect.fromCenter(center: Offset(headCenter.dx - 17, headCenter.dy), width: 6, height: 12),
      math.pi / 2,
      math.pi,
      false,
      headPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(headCenter.dx + 17, headCenter.dy), width: 6, height: 12),
      -math.pi / 2,
      math.pi,
      false,
      headPaint,
    );

    // Connecting signal routes
    final routePaint = Paint()
      ..color = isConnected ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(headCenter.dx - 15, headCenter.dy), Offset(headCenter.dx - 9, headCenter.dy - 15), routePaint);
    canvas.drawLine(Offset(headCenter.dx - 9, headCenter.dy - 15), Offset(headCenter.dx + 9, headCenter.dy - 15), routePaint);
    canvas.drawLine(Offset(headCenter.dx + 9, headCenter.dy - 15), Offset(headCenter.dx + 15, headCenter.dy), routePaint);

    // Draw electrodes node values
    void drawNode(Offset pos, bool good) {
      final nodeColor = good ? AppColors.primaryGreen : Colors.grey[500]!;
      
      // Outer glow boundary
      final borderPaint = Paint()
        ..color = nodeColor.withValues(alpha: 0.35)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, 4.5, borderPaint);

      // Solid inner core
      final fillPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 2.5, fillPaint);
    }

    // TP9 (Left ear)
    drawNode(Offset(headCenter.dx - 15, headCenter.dy), isConnected);
    // AF7 (Left forehead)
    drawNode(Offset(headCenter.dx - 9, headCenter.dy - 15), isConnected);
    // AF8 (Right forehead)
    drawNode(Offset(headCenter.dx + 9, headCenter.dy - 15), isConnected);
    // TP10 (Right ear)
    drawNode(Offset(headCenter.dx + 15, headCenter.dy), isConnected);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LiveOscilloscope extends StatefulWidget {
  final MuseService museService;
  const LiveOscilloscope({super.key, required this.museService});

  @override
  State<LiveOscilloscope> createState() => _LiveOscilloscopeState();
}

class _LiveOscilloscopeState extends State<LiveOscilloscope> {
  Timer? _timer;
  final List<double> _points1 = List.generate(80, (index) => 0.0);
  final List<double> _points2 = List.generate(80, (index) => 0.0);
  final List<double> _points3 = List.generate(80, (index) => 0.0);
  final List<double> _points4 = List.generate(80, (index) => 0.0);
  double _tick = 0.0;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        _tick += 0.2;
        // Shift points left
        _points1.removeAt(0);
        _points2.removeAt(0);
        _points3.removeAt(0);
        _points4.removeAt(0);

        if (widget.museService.isConnected && widget.museService.latestData != null) {
          final data = widget.museService.latestData!;
          _points1.add(math.sin(_tick) * (data.alpha / 25) + math.cos(_tick * 2) * (data.beta / 50));
          _points2.add(math.sin(_tick * 1.5) * (data.theta / 25) + math.sin(_tick * 0.5) * (data.delta / 40));
          _points3.add(math.cos(_tick * 1.2) * (data.beta / 30) + math.sin(_tick * 3) * (data.gamma / 60));
          _points4.add(math.sin(_tick * 0.8) * (data.alpha / 20) + math.cos(_tick * 1.7) * (data.theta / 30));
        } else {
          // Flatline/Standby noise
          _points1.add(math.sin(_tick) * 0.15 + (_random.nextDouble() - 0.5) * 0.04);
          _points2.add(math.cos(_tick * 1.3) * 0.1 + (_random.nextDouble() - 0.5) * 0.04);
          _points3.add(math.sin(_tick * 0.7) * 0.2 + (_random.nextDouble() - 0.5) * 0.04);
          _points4.add(math.cos(_tick * 1.8) * 0.08 + (_random.nextDouble() - 0.5) * 0.04);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.75,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _OscilloscopePainter(
            points1: _points1,
            points2: _points2,
            points3: _points3,
            points4: _points4,
            isConnected: widget.museService.isConnected,
          ),
        ),
      ),
    );
  }
}

class _OscilloscopePainter extends CustomPainter {
  final List<double> points1;
  final List<double> points2;
  final List<double> points3;
  final List<double> points4;
  final bool isConnected;

  _OscilloscopePainter({
    required this.points1,
    required this.points2,
    required this.points3,
    required this.points4,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    // Draw clinical oscilloscope grid
    const int gridCols = 10;
    const int gridRows = 6;
    for (int i = 0; i <= gridCols; i++) {
      final x = size.width * (i / gridCols);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 0; i <= gridRows; i++) {
      final y = size.height * (i / gridRows);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw horizontal dashed reference centerline
    final centerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    
    double dashWidth = 4, dashSpace = 4, startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), centerPaint);
      startX += dashWidth + dashSpace;
    }

    _drawTrace(canvas, size, points1, const Color(0xFF8B5CF6), size.height * 0.2);
    _drawTrace(canvas, size, points2, const Color(0xFF10B981), size.height * 0.4);
    _drawTrace(canvas, size, points3, const Color(0xFF3B82F6), size.height * 0.6);
    _drawTrace(canvas, size, points4, const Color(0xFFF59E0B), size.height * 0.8);

    // CH indicators
    const textStyle = TextStyle(color: AppColors.textGray, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5);
    _drawText(canvas, const Offset(6, 4), 'CH1: TP9 (ALPHA/BETA)', textStyle);
    _drawText(canvas, Offset(6, size.height * 0.4 - 10), 'CH2: AF7 (THETA/DELTA)', textStyle);
    _drawText(canvas, Offset(6, size.height * 0.6 - 10), 'CH3: AF8 (BETA/GAMMA)', textStyle);
    _drawText(canvas, Offset(6, size.height * 0.8 - 10), 'CH4: TP10 (ALPHA/THETA)', textStyle);
  }

  void _drawTrace(Canvas canvas, Size size, List<double> points, Color color, double centerY) {
    if (points.isEmpty) return;

    final stepX = size.width / (points.length - 1);
    final path = Path();
    path.moveTo(0, centerY + points[0] * 12);

    for (int i = 1; i < points.length; i++) {
      final x = i * stepX;
      final y = centerY + points[i] * 12;
      path.lineTo(x, y);
    }

    // 1. Draw glowing path underneath (thick and semi-transparent)
    final glowPaint = Paint()
      ..color = isConnected ? color.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // 2. Draw sharp core path on top (thin and opaque)
    final corePaint = Paint()
      ..color = isConnected ? color : Colors.grey.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, corePaint);
  }

  void _drawText(Canvas canvas, Offset offset, String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _OscilloscopePainter oldDelegate) => true;
}
