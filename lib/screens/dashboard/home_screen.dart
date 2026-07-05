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
import 'eeg_session_screen.dart'; // เพิ่มการนำเข้าหน้าเก็บบันทึกข้อมูลคลื่นสมอง
import 'eeg_assessment_report_screen.dart';
import 'eeg_report_history_screen.dart';
import 'settings_screen.dart';
import 'mini_games_screen.dart';
import '../../widgets/eeg_pipeline_visualizer.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final Function(int)? onTabSelected;

  const HomeScreen({super.key, required this.user, this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MuseService _museService = MuseService();
  static bool _isResearchWavesExpanded = true;
 
  // สถานะค่าบัฟเฟอร์สัญญาณของหน้าจอออสซิลโลสโคปแบบเรียลไทม์ (Real-time scrolling oscilloscope state)
  final Map<String, List<double>> _oscilloscopeBuffers = {
    'TP9': [],
    'AF7': [],
    'AF8': [],
    'TP10': [],
  };
  StreamSubscription? _rawEegSubscription;
  Timer? _simulationWaveTimer;

  void _updateOscilloscopeSubscription() {
    final bool shouldBeRunning = _museService.isConnected;
    
    if (shouldBeRunning) {
      if (_museService.isSimulating) {
        _rawEegSubscription?.cancel();
        _rawEegSubscription = null;
        if (_simulationWaveTimer == null || !_simulationWaveTimer!.isActive) {
          _startSimulationWaves();
        }
      } else {
        _simulationWaveTimer?.cancel();
        _simulationWaveTimer = null;
        if (_rawEegSubscription == null) {
          _startListeningToRawEeg();
        }
      }
    } else {
      _rawEegSubscription?.cancel();
      _rawEegSubscription = null;
      _simulationWaveTimer?.cancel();
      _simulationWaveTimer = null;
      _oscilloscopeBuffers.forEach((key, value) => value.clear());
    }
  }

  void _startListeningToRawEeg() {
    _rawEegSubscription?.cancel();
    _rawEegSubscription = _museService.rawEegStream.listen((channelData) {
      if (!mounted || !_museService.isConnected || _museService.isSimulating) return;
      setState(() {
        channelData.forEach((channel, samples) {
          _addOscilloscopeSample(channel, samples);
        });
      });
    });
  }

  void _startSimulationWaves() {
    _simulationWaveTimer?.cancel();
    double time = 0;
    final random = math.Random();
    _simulationWaveTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_museService.isConnected || !_museService.isSimulating) {
        timer.cancel();
        return;
      }
      time += 0.03;
      setState(() {
        final tp9Val = 15.0 * math.sin(2 * math.pi * 10 * time) + 4.0 * math.sin(2 * math.pi * 4 * time) + (random.nextDouble() - 0.5) * 6.0;
        final af7Val = 8.0 * math.sin(2 * math.pi * 20 * time) + 10.0 * math.sin(2 * math.pi * 8 * time) + (random.nextDouble() - 0.5) * 8.0;
        final af8Val = 7.0 * math.sin(2 * math.pi * 18 * time) + 9.0 * math.sin(2 * math.pi * 9 * time) + (random.nextDouble() - 0.5) * 7.5;
        final tp10Val = 10.0 * math.sin(2 * math.pi * 6 * time) + 15.0 * math.sin(2 * math.pi * 2 * time) + (random.nextDouble() - 0.5) * 5.0;

        _addSingleOscilloscopeSample('TP9', tp9Val);
        _addSingleOscilloscopeSample('AF7', af7Val);
        _addSingleOscilloscopeSample('AF8', af8Val);
        _addSingleOscilloscopeSample('TP10', tp10Val);
      });
    });
  }

  void _addOscilloscopeSample(String channel, List<double> samples) {
    final buffer = _oscilloscopeBuffers[channel];
    if (buffer != null) {
      buffer.addAll(samples);
      if (buffer.length > 500) {
        buffer.removeRange(0, buffer.length - 500);
      }
    }
  }

  void _addSingleOscilloscopeSample(String channel, double value) {
    final buffer = _oscilloscopeBuffers[channel];
    if (buffer != null) {
      buffer.add(value);
      if (buffer.length > 500) {
        buffer.removeAt(0);
      }
    }
  }

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

  // สถานะเครื่องนับเวลาถอยหลังการทดสอบ EEG (EEG Countdown Timer State)
  bool _isEegCountdownRunning = false;
  bool _isEegCountdownDone = false;
  int _eegCountdownSeconds = 90; // บันทึก 90 วินาที = อิง DEAP 60 วินาที + 30 วินาทีขอบเขตตัดสัญญาณรบกวน
  Timer? _eegCountdownTimer;
  Timer? _eegSampleTimer; // เครื่องเวลาสุ่มตัวอย่างความถี่เร็ว (Fast sampling timer 250ms)
  Map<String, dynamic>? _eegSummaryResult;
  
  // ชุดข้อมูลคลื่นสมอง EEG สะสมที่วัดได้ระหว่างการนับเวลาถอยหลัง
  final List<Map<String, double>> _eegSamples = [];


  @override
  void initState() {
    super.initState();

    // กำหนดค่าและเตรียมการเล่นวิดีโอตัวอย่างคลื่นสมองจากไฟล์ในเครื่อง (Initialize Video Player)
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
    _updateOscilloscopeSubscription();
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

    _rawEegSubscription?.cancel();
    _simulationWaveTimer?.cancel();

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

    // เครื่องจับเวลาสุ่มสัญญาณแบบเร็ว - ทำการสุ่มเก็บข้อมูลสัญญาณสมองทุกๆ 250 มิลลิวินาที (เก็บราวๆ 360 ชุดในเวลา 90 วินาที)
    _eegSampleTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) { timer.cancel(); return; }
      _collectEegSample();
    });

    // เครื่องเวลานับถอยหลังสำหรับ UI - อัปเดตแสดงผลบนหน้าจอทุกๆ 1 วินาที
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

    // ทำนายสภาวะทางอารมณ์/จิตใจภาพรวมโดยใช้โมเดล PyTorch Mobile บนข้อมูลค่าเฉลี่ย
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
    _updateOscilloscopeSubscription();
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
                                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
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
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            // ตัวเล่นวิดีโอ (Video Player) — แสดงผลเต็มพื้นที่ในกรอบ Stack
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

                            // กรอบมุมสไตล์ไฮเทค (High-Tech Cyber Corner Frame Paint)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CyberFramePainter(
                                  color: Colors.cyan.withValues(alpha: 0.6),
                                  isConnected: _museService.isConnected,
                                ),
                              ),
                            ),

                            // แถบเส้นเลเซอร์สแกนแบบล้ำสมัย (Pulse-scanning laser line overlay)
                            if (_isVideoLoaded && _isVideoPlaying)
                              const Positioned.fill(
                                child: SciFiScannerOverlay(
                                  color: Colors.cyan,
                                ),
                              ),

                            // แผ่นฟิล์มไล่ระดับเฉดสีเพื่อเพิ่มการอ่านค่า (Subtle gradient overlay at bottom and top for readability)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.5),
                                    ],
                                    stops: const [0.0, 0.2, 0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // หน้าจอ HUD มุมบนซ้าย: แสดงสถานะการบันทึกภาพพร้อมจุดสีแดงกะพริบ (HUD Overlay: Top-Left)
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
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // หน้าจอ HUD มุมบนขวา: แสดงข้อมูลรายละเอียดการเชื่อมต่อเครื่องส่ง (HUD Overlay: Top-Right)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
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

                            // หน้าจอ HUD มุมล่างซ้าย: แสดงสถานะช่องวัดสัญญาณสมองแบบสด (HUD Overlay: Bottom-Left)
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
                                      color: Colors.white.withValues(alpha: 0.5),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // หน้าจอ HUD มุมล่างขวา: แถบควบคุมวิดีโอแบบกระจกฝ้าลอยตัว (HUD Overlay: Bottom-Right)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ปุ่มกด เล่น / หยุดเล่นวิดีโอ (Play / Pause Button)
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
                                          color: Colors.white.withValues(alpha: 0.1),
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
                                    // ปุ่มเปิด / ปิดเสียงวิดีโอ (Mute Button)
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
                                          color: Colors.white.withValues(alpha: 0.1),
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
                                    // จุดไฟกระพริบแสดงสัญญาณสดแบบเรียลไทม์ (Live Indicator Dot)
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

                            // หน้าต่างซ้อนทับขณะกำลังโหลด (Loading overlay)
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
                                            color: Colors.white.withValues(alpha: 0.7),
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
                      'เมนูการประเมินและเก็บข้อมูลคลื่นสมอง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _buildFeaturedEegSessionCard(context),
                        const SizedBox(height: 12),
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
                        borderColor: (_museService.isConnected ? AppColors.primaryGreen : AppColors.primaryBlue).withValues(alpha: 0.2),
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
                                  color: (_museService.isConnected ? AppColors.primaryGreen : AppColors.primaryBlue).withValues(alpha: 0.1),
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
                                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                                : Colors.grey.withValues(alpha: 0.1),
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
                                color: AppColors.primaryBlue.withValues(alpha: 0.05),
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
                          
                          // ตารางข้อมูลโทรมาตรการเชื่อมต่อ (Connection Telemetry Grid - แสดงเมื่อเชื่อมต่อสำเร็จ)
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
                                      color: const Color(0xFF667eea).withValues(alpha: 0.1),
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
                                  borderColor: AppColors.warning.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'รอสัญญาณจริง... ตรวจสอบการสวมใส่หน้ากากวัดคลื่นสมองให้กระชับหน้าผาก',
                                        style: TextStyle(fontSize: 12, color: AppColors.textDark.withValues(alpha: 0.8)),
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
                                  borderColor: AppColors.primaryBlue.withValues(alpha: 0.25),
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
                        borderColor: AppColors.primaryBlue.withValues(alpha: 0.15),
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
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_museService.isConnected && _museService.latestData != null)
                                      ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
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
                            style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                          ),
                          const SizedBox(height: 18),
                          
                          // รูปแบบเลย์เอาต์ยืดหยุ่นรองรับการแสดงผลความแรงคลื่นสมอง 5 ย่านความถี่ (Wrap แทนที่จะใช้การเลื่อนแนวนอน)
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
                              final hasData = _museService.isConnected && _museService.latestData != null;
                              final rawVals = hasData
                                  ? [
                                      _museService.latestData!.delta,
                                      _museService.latestData!.theta,
                                      _museService.latestData!.alpha,
                                      _museService.latestData!.beta,
                                      _museService.latestData!.gamma,
                                    ]
                                  : [0.0, 0.0, 0.0, 0.0, 0.0];

                              // แปลงสัดส่วนเป็นเปอร์เซ็นต์ (Normalized percentages)
                              final double sumRaw = rawVals.reduce((a, b) => a + b);
                              final List<double> pctVals = sumRaw > 0
                                  ? rawVals.map((v) => (v / sumRaw) * 100.0).toList()
                                  : [0.0, 0.0, 0.0, 0.0, 0.0];

                              // ปรับแต่งโดยใช้วิธีเศษเหลือสูงสุด (Largest Remainder Method / Hamilton Method) เพื่อปรับจุดทศนิยมให้รวมกันได้ครบ 100% พอดี
                              final List<int> roundedVals = List.filled(5, 0);
                              if (sumRaw > 0) {
                                final List<int> floors = pctVals.map((v) => v.floor()).toList();
                                final int floorSum = floors.reduce((a, b) => a + b);
                                final int diff = 100 - floorSum;

                                // จัดเก็บค่าดัชนีและเศษที่เหลือหลังปัดเศษลง
                                final List<MapEntry<int, double>> remainders = List.generate(
                                  5,
                                  (i) => MapEntry(i, pctVals[i] - floors[i])
                                );

                                // เรียงลำดับจากค่าเศษเหลือมากไปหาน้อย
                                remainders.sort((a, b) => b.value.compareTo(a.value));

                                // กำหนดสัดส่วนพื้นฐาน (Floors)
                                for (int i = 0; i < 5; i++) {
                                  roundedVals[i] = floors[i];
                                }

                                // กระจายผลต่างเศษเหลือที่เหลืออยู่ให้แก่ย่านความถี่ที่มีเศษเหลือมากสุดตามลำดับ
                                for (int i = 0; i < diff; i++) {
                                  final idx = remainders[i].key;
                                  roundedVals[idx]++;
                                }
                              }

                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildCircularWaveIndicator(
                                    'Delta',
                                    hasData ? roundedVals[0].toDouble() : 0.0,
                                    const Color(0xFF8B5CF6),
                                    'หลับลึก',
                                    1.0,
                                    hasData,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Theta',
                                    hasData ? roundedVals[1].toDouble() : 0.0,
                                    const Color(0xFF10B981),
                                    'ผ่อนคลาย',
                                    2.5,
                                    hasData,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Alpha',
                                    hasData ? roundedVals[2].toDouble() : 0.0,
                                    const Color(0xFF3B82F6),
                                    'ตื่นตัว',
                                    5.0,
                                    hasData,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Beta',
                                    hasData ? roundedVals[3].toDouble() : 0.0,
                                    const Color(0xFFF59E0B),
                                    'คิดวิเคราะห์',
                                    9.0,
                                    hasData,
                                    width: cardWidth,
                                  ),
                                  _buildCircularWaveIndicator(
                                    'Gamma',
                                    hasData ? roundedVals[4].toDouble() : 0.0,
                                    const Color(0xFFEF4444),
                                    'สมาธิสูง',
                                    15.0,
                                    hasData,
                                    width: cardWidth,
                                  ),
                                ],
                              );
                            },
                          ),
                          if (_museService.isConnected) ...[
                            const SizedBox(height: 18),
                            _buildResearchWaveformCard(),
                            const SizedBox(height: 18),
                            EegPipelineVisualizer(
                              channels: _oscilloscopeBuffers,
                              hasData: _oscilloscopeBuffers.values.any((b) => b.isNotEmpty),
                            ),
                          ],
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
        color: isConnected ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isConnected ? Colors.green.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
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
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 0.5),
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
        borderColor: displayColor.withValues(alpha: isActive ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
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
                      backgroundColor: displayColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
              ),
              Text(
                '${value.round()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: displayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // กราฟเส้นคลื่นสมองเคลื่อนไหวแบบเรียลไทม์ (Dynamic animated microwave line chart)
          MicroWaveChart(
            color: displayColor,
            frequency: frequency,
            isActive: isActive,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
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
        borderColor: AppColors.primaryBlue.withValues(alpha: 0.15),
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
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
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
              // แผงควบคุมฝั่งซ้าย: ข้อมูลผลประเมินภาวะอารมณ์ PHQ-9 (Left Panel)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.15), width: 1),
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
              // แผงควบคุมฝั่งขวา: ข้อมูลผลประเมินคลื่นสมอง EEG (Right Panel)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1), width: 1),
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
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
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
                                  color: AppColors.error.withValues(alpha: 0.1),
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
        color: isPyTorch ? const Color(0xFF4F46E5).withValues(alpha: 0.04) : AppColors.primaryBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isPyTorch ? const Color(0xFF4F46E5) : AppColors.primaryBlue).withValues(alpha: 0.12),
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
                        color: Colors.black.withValues(alpha: 0.04),
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
        borderColor: const Color(0xFF667eea).withValues(alpha: 0.18),
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
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
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
              // เมนูสำหรับเลือกเปลี่ยนประเภทโมเดล AI ในการประมวลผล (Model Selection Menu)
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
        borderColor: const Color(0xFF1a237e).withValues(alpha: 0.18),
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
                  color: const Color(0xFF1a237e).withValues(alpha: 0.1),
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
                    color: Colors.green.withValues(alpha: 0.12),
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
            // วงล้อแสดงความคืบหน้าของเวลานับถอยหลังการทดสอบ (Timer circular progress or medical badge)
            Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1B2A4A),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1a237e).withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
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

  Widget _buildResearchWaveformCard() {
    // คำนวณค่าสถิติแบบเรียลไทม์สำหรับแต่ละช่องสัญญาณประสาท (คำนวณจากค่าดิบ Raw values)
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
        final std = math.sqrt(variance.abs());
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
    final String sourceLabel = _museService.isSimulating
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
                            _buildMetaChip('Source', sourceLabel),
                            const SizedBox(width: 12),
                            _buildMetaChip('Fs', '256 Hz'),
                            const SizedBox(width: 12),
                            _buildMetaChip('Ref', 'FPz (Forehead)'),
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
                            height: 180,
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
                            Container(width: 40, height: 2, color: Colors.black54),
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
                                      _HomeStatHeader('Ch'),
                                      _HomeStatHeader('Mean'),
                                      _HomeStatHeader('Std'),
                                      _HomeStatHeader('Min'),
                                      _HomeStatHeader('Max'),
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
                                        _HomeStatCell(s?['mean']),
                                        _HomeStatCell(s?['std']),
                                        _HomeStatCell(s?['min']),
                                        _HomeStatCell(s?['max']),
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

  Widget _buildMetaChip(String label, String value) {
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

  /// สร้างบัตรปุ่มกดสำหรับเปิดหน้าเก็บบันทึกข้อมูลอารมณ์คลื่นสมอง (EEG Session Screen)
  /// ออกแบบเป็นสไตล์พรีเมียม ไฮเทค ตามภาพดีไซน์ที่กำหนด มีลายเส้นตาราง Grid สีจางที่พื้นหลัง
  /// และมีปุ่มวงกลมสีขาวบรรจุลูกศรนำทางชี้ไปข้างหน้า
  Widget _buildFeaturedEegSessionCard(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          // นำทางผู้ใช้ไปยังหน้าจอการเก็บบันทึกข้อมูลคลื่นสมองและอารมณ์จริง EegSessionScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EegSessionScreen(
                user: widget.user,
                museService: _museService, // ส่งมอบ service สัญญาณบลูทูธของอุปกรณ์ Muse ไปร่วมใช้งาน
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          height: 125,
          decoration: AppTheme.glassDecoration(
            color: AppColors.primaryBlue,
            opacity: 0.15,
            borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              // ลายเส้นกริดตารางจำลองจอวิเคราะห์สัญญาณแบบจาง
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPatternPainter(color: AppColors.primaryBlue.withValues(alpha: 0.04)),
                ),
              ),
              // วงกลมประดับพื้นหลังด้านขวาบนเพื่อความสมมาตรทางดีไซน์
              Positioned(
                right: -15,
                top: -15,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // กล่องแสดงไอคอนสมองทรงพรีเมียมสีฟ้าอ่อนตัดน้ำเงินเข้ม
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: AppColors.primaryBlue, size: 28),
                    ),
                    const SizedBox(width: 16),
                    // ส่วนแสดงชื่อปุ่มและคำบรรยายวัตถุประสงค์การวัดผล
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                'บันทึกข้อมูลอารมณ์',
                                style: GoogleFonts.prompt(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // วงกลมจุดสีเขียวบ่งบอกสถานะการวัดแบบเรียลไทม์
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.neonGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'เชื่อมต่อเซนเซอร์ EEG เพื่อเริ่มทำการบันทึกและประเมินจิตวิทยาคลินิก',
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              color: AppColors.textGray,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ปุ่มวงกลมสีขาวบรรจุไอคอนหัวลูกศรชี้ไปขวาตามรูปต้นแบบดีไซน์
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// คลาสวาดตารางลายเส้นกริดพื้นหลังแบบจาง (Grid Background Painter)
/// เพื่อใช้ตกแต่งหน้าบัตร Eeg Session Card ให้ดูสวยงามพรีเมียม สไตล์เครื่องมือทางการแพทย์ระดับสูง
class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 15.0;
    // ลากเส้นตามแนวตั้ง
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // ลากเส้นตามแนวนอน
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} // สิ้นสุดคลาส _HomeScreenState

// ==========================================
// วิดเจ็ตอำนวยความสะดวกภายนอกและตัววาดรูปไดนามิก (Custom Helper Widgets & Dynamic Painters)
// ==========================================

class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseDot({required this.color, required this.size});

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

    // วาดสัญลักษณ์มุมกรอบ (Draw corner brackets)
    // บนซ้าย (Top-Left)
    canvas.drawPath(Path()..moveTo(bracketSize, 2)..lineTo(2, 2)..lineTo(2, bracketSize), paint);
    // บนขวา (Top-Right)
    canvas.drawPath(Path()..moveTo(size.width - bracketSize, 2)..lineTo(size.width - 2, 2)..lineTo(size.width - 2, bracketSize), paint);
    // ล่างซ้าย (Bottom-Left)
    canvas.drawPath(Path()..moveTo(bracketSize, size.height - 2)..lineTo(2, size.height - 2)..lineTo(2, size.height - bracketSize), paint);
    // ล่างขวา (Bottom-Right)
    canvas.drawPath(Path()..moveTo(size.width - bracketSize, size.height - 2)..lineTo(size.width - 2, size.height - 2)..lineTo(size.width - 2, size.height - bracketSize), paint);

    // เส้นโครงขอบด้านในจางๆ (Subtle inner boundary frame)
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), borderPaint);

    // เป้าเล็งวงกลมกึ่งกลางสไตล์กล้องสแกนคลินิก (Center Target Reticle)
    final center = Offset(size.width / 2, size.height / 2);
    final reticlePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 30, reticlePaint);
    canvas.drawCircle(center, 4, Paint()..color = color.withValues(alpha: 0.4)..style = PaintingStyle.fill);

    // วาดขีดไม้กางเขนเล็งเป้า (Draw reticle crosshair ticks)
    canvas.drawLine(Offset(center.dx - 45, center.dy), Offset(center.dx - 35, center.dy), reticlePaint);
    canvas.drawLine(Offset(center.dx + 35, center.dy), Offset(center.dx + 45, center.dy), reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy - 45), Offset(center.dx, center.dy - 35), reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy + 35), Offset(center.dx, center.dy + 45), reticlePaint);

    // ขีดสเกลด้านข้างสำหรับวัดระดับ (Side ticks - Rulers on left & right sides)
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

    // เส้นเลเซอร์เรืองแสงที่วิ่งสแกน (Glowing laser scan line)
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

    // ลำแสงเลเซอร์เรืองแสงฟุ้งที่ลากเป็นเงาตามหลังมา (Glowing laser trail trailing behind)
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
      ..color = isActive ? color : Colors.grey.withValues(alpha: 0.3)
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
          // ภาพวาดจำลองศีรษะคนเชิงเวกเตอร์ (Stylized Head Vector Paint)
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
    
    // วาดรูปวงรีศีรษะ (Head Oval)
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 34, height: 42),
      headPaint,
    );

    // วาดรูปจมูกอย่างง่ายชี้ขึ้นด้านบน (Draw simple nose pointing up)
    final nosePath = Path()
      ..moveTo(headCenter.dx, headCenter.dy - 21)
      ..lineTo(headCenter.dx - 4, headCenter.dy - 25)
      ..lineTo(headCenter.dx + 4, headCenter.dy - 25)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = Colors.grey[400]!..style = PaintingStyle.fill);

    // วาดใบหูซ้ายขวา (Ears)
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

    // วาดเส้นแนวเชื่อมต่อสัญญาณประสาท (Connecting signal routes)
    final routePaint = Paint()
      ..color = isConnected ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(headCenter.dx - 15, headCenter.dy), Offset(headCenter.dx - 9, headCenter.dy - 15), routePaint);
    canvas.drawLine(Offset(headCenter.dx - 9, headCenter.dy - 15), Offset(headCenter.dx + 9, headCenter.dy - 15), routePaint);
    canvas.drawLine(Offset(headCenter.dx + 9, headCenter.dy - 15), Offset(headCenter.dx + 15, headCenter.dy), routePaint);

    // วาดจุดอิเล็กโทรดบนศีรษะ (Draw electrodes node values)
    void drawNode(Offset pos, bool good) {
      final nodeColor = good ? AppColors.primaryGreen : Colors.grey[500]!;
      
      // เส้นวงกลมเรืองแสงวงนอก (Outer glow boundary)
      final borderPaint = Paint()
        ..color = nodeColor.withValues(alpha: 0.35)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, 4.5, borderPaint);

      // แกนวงกลมทึบด้านใน (Solid inner core)
      final fillPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 2.5, fillPaint);
    }

    // จุดรับสัญญาณตำแหน่ง TP9 (หูด้านซ้าย)
    drawNode(Offset(headCenter.dx - 15, headCenter.dy), isConnected);
    // จุดรับสัญญาณตำแหน่ง AF7 (หน้าผากด้านซ้าย)
    drawNode(Offset(headCenter.dx - 9, headCenter.dy - 15), isConnected);
    // จุดรับสัญญาณตำแหน่ง AF8 (หน้าผากด้านขวา)
    drawNode(Offset(headCenter.dx + 9, headCenter.dy - 15), isConnected);
    // จุดรับสัญญาณตำแหน่ง TP10 (หูด้านขวา)
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
        // เลื่อนจุดสัญญาณไปทางซ้ายเพื่อแสดงผลกราฟเลื่อน (Shift points left)
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
          // สัญญาณนิ่งหรือคลื่นสัญญาณรบกวนสแตนด์บาย (Flatline/Standby noise)
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

    // วาดตารางกริดออสซิลโลสโคปแบบคลินิก (Draw clinical oscilloscope grid)
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

    // วาดเส้นแกนนอนกึ่งกลางแนวอ้างอิงประ (Draw horizontal dashed reference centerline)
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

    // ป้ายกำกับระบุช่องสัญญาณประสาทแต่ละช่อง (CH indicators)
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

// ── Home Screen Stat table helper widgets ──
class _HomeStatHeader extends StatelessWidget {
  final String text;
  const _HomeStatHeader(this.text);
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

class _HomeStatCell extends StatelessWidget {
  final double? value;
  const _HomeStatCell(this.value);
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
// ตัววาดกราฟคลื่นสมอง EEG เกรดงานวิจัยที่มีตารางกริด สเกลวัด และสีแยกแยะสำหรับแต่ละช่องสัญญาณประสาท
// ออกแบบขึ้นให้สอดคล้องตามเกณฑ์มาตรฐานสากล (clinical/research EEG viewer conventions)
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

    // ฟังก์ชันย่อยสำหรับวาดเส้นฐานแนวนอนแบบประ (Dashed baseline helper)
    void drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final totalLength = math.sqrt(dx * dx + dy * dy);
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

      // วาดพื้นหลังสลับสีเพื่อแยกบรรทัดแต่ละแชลแนล (Alternating background)
      if (i % 2 == 1) {
        canvas.drawRect(
          Rect.fromLTWH(0, yOffset, size.width, channelHeight),
          Paint()..color = const Color(0xFFF7F7FA),
        );
      }

      // เส้นกริดแนวนอนย่อย 3 เส้นต่อแชลแนล (Grid lines - 3 minor lines per channel)
      for (int g = 1; g <= 3; g++) {
        final gy = yOffset + channelHeight * g / 4;
        canvas.drawLine(
          Offset(labelWidth, gy),
          Offset(size.width - rightPadding, gy),
          gridPaint,
        );
      }

      // เส้นกริดแนวตั้งแบ่งสเกลเวลาออกเป็น 8 ส่วน (Vertical grid lines - 8 segments)
      for (int v = 1; v < 8; v++) {
        final vx = labelWidth + plotWidth * v / 8;
        canvas.drawLine(
          Offset(vx, yOffset),
          Offset(vx, yOffset + channelHeight),
          v == 4 ? gridPaintMajor : gridPaint,
        );
      }

      // เส้นอ้างอิงตรงกลางสมดุลศูนย์ประ (Zero baseline - dashed)
      drawDashedLine(
        canvas,
        Offset(labelWidth, yCenter),
        Offset(size.width - rightPadding, yCenter),
        baselinePaint,
      );

      // เส้นขอบใต้แชลแนลช่องสัญญาณ (Channel border)
      canvas.drawLine(
        Offset(0, yOffset + channelHeight),
        Offset(size.width, yOffset + channelHeight),
        Paint()
          ..color = const Color(0xFFCCCCCC)
          ..strokeWidth = 0.8,
      );

      // เส้นคั่นแนวตั้งระหว่างชื่อแชลแนลและพื้นที่สัญญาณ (Vertical divider)
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
      canvas.rotate(-math.pi / 2);
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

      // การขจัดแนวโน้มเส้นกราฟเอียง (Detrend: ลบค่าเฉลี่ยออก)
      double sum = 0;
      for (final val in data) {
        sum += val;
      }
      final mean = sum / data.length;

      // ปรับขนาดความกว้างสเกลอัตโนมัติ (Auto-scale: หาค่าเบี่ยงเบนสัมบูรณ์สูงสุด)
      double maxDev = 5.0;
      for (final val in data) {
        final dev = (val - mean).abs();
        if (dev > maxDev) maxDev = dev;
      }
      maxDev *= 1.15;

      // วาดรูปเส้นคลื่นคลื่นสมอง (Draw waveform)
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

      // ── แถบสเกลบอกแรงดันไฟฟ้าในหน่วยไมโครโวลต์ด้านขวา (µV scale indicator) ──
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

    // วาดเส้นขอบด้านบนสุด (Top border)
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

