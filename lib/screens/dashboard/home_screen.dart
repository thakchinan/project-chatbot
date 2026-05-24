import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/eeg_assessment_service.dart';
import '../../emotion_detection/emotion_detection.dart';
import 'eeg_assessment_report_screen.dart';
import 'eeg_report_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MuseService _museService = MuseService();
  final EmotionDetectionService _emotionService = EmotionDetectionService();
  late final WebViewController _webViewController;
  late final WebViewController _popupWebViewController;
  bool _is3DModelLoaded = false;
  EmotionResult? _pytorchEmotion;
  EmotionResult? _tfliteEmotion;
  bool _isDetectingEmotion = false;
  Timer? _emotionDetectionTimer;
  bool _isLoading = false;

  Map<String, dynamic>? _latestTestResult;
  Map<String, dynamic>? _latestBrainwave;
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

    // JavaScript to hide Spline watermark and set dark bg
    const splineJS = '''
      (function() {
        document.body.style.backgroundColor = '#0F1629';
        function hideWatermark() {
          var els = document.querySelectorAll('a[href*="spline"], div[class*="watermark"], div[class*="logo"]');
          els.forEach(function(el) { el.style.display = 'none'; });
          var allDivs = document.querySelectorAll('div');
          allDivs.forEach(function(d) {
            if (d.textContent && d.textContent.includes('Built with Spline')) {
              d.style.display = 'none';
            }
          });
        }
        hideWatermark();
        setInterval(hideWatermark, 1000);
      })();
    ''';

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      _webViewController.setBackgroundColor(const Color(0xFF0F1629));
    }
    _webViewController
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          _webViewController.runJavaScript(splineJS);
          if (mounted) setState(() => _is3DModelLoaded = true);
        },
      ))
      ..loadRequest(Uri.parse('https://my.spline.design/untitled-HfIixx8UIc1mREO9Ims7nA0X/'));

    _popupWebViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      _popupWebViewController.setBackgroundColor(const Color(0xFF0F1629));
    }
    _popupWebViewController
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          _popupWebViewController.runJavaScript(splineJS);
        },
      ))
      ..loadRequest(Uri.parse('https://my.spline.design/untitled-HfIixx8UIc1mREO9Ims7nA0X/'));

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
        .from('brainwave_data')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _healthLoaded = true;
        if (data.isNotEmpty) {
          _latestBrainwave = data.first;
          print('🔴 [Realtime] brainwave_data updated: $_latestBrainwave');
        }
      });
    }, onError: (e) {
      print('❌ [Realtime] brainwave_data error: $e');
      _loadBrainwaveFallback();
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

  Future<void> _loadBrainwaveFallback() async {
    try {
      final result = await ApiService.getBrainwaveData(widget.user.id);
      if (!mounted) return;
      setState(() {
        if (result['success'] == true &&
            result['data'] != null &&
            (result['data'] as List).isNotEmpty) {
          _latestBrainwave = (result['data'] as List).first;
        }
      });
    } catch (_) {}
  }

  Future<void> _reloadHealthData() async {
    try {
      final testResult = await ApiService.getTestResults(widget.user.id);
      final brainResult = await ApiService.getBrainwaveData(widget.user.id);

      if (!mounted) return;
      setState(() {
        if (testResult['success'] == true &&
            testResult['results'] != null &&
            (testResult['results'] as List).isNotEmpty) {
          _latestTestResult = (testResult['results'] as List).first;
          print('🔄 [Reload] test_results: $_latestTestResult');
        }
        if (brainResult['success'] == true &&
            brainResult['data'] != null &&
            (brainResult['data'] as List).isNotEmpty) {
          _latestBrainwave = (brainResult['data'] as List).first;
          print('🔄 [Reload] brainwave_data: $_latestBrainwave');
        }
      });
    } catch (e) {
      print('❌ [Reload] error: $e');
    }
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
          _pytorchEmotion = results['pytorch'];
          _tfliteEmotion = results['tflite'];
        });

        final mainResult = results['pytorch'];
        if (mainResult != null && mainResult.confidence >= EmotionConstants.confidenceThreshold) {
          ApiService.saveEmotionLog(
            userId: widget.user.id,
            emotionType: mainResult.emotionType,
            triggerEvent: 'eeg_brainwave',
            intensity: (mainResult.confidence * 10).round(),
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
      final pytorchResult = results['pytorch'];
      if (pytorchResult != null) {
        summary['predictedMentalState'] = pytorchResult.emotionType;
        summary['predictedMentalStateLabel'] = EmotionType.fromString(pytorchResult.emotionType).label;
        summary['predictedMentalStateConfidence'] = pytorchResult.confidence;
      }
    } catch (e) {
      debugPrint('❌ Failed to run session mental state prediction: $e');
    }

    setState(() {
      _isEegCountdownRunning = false;
      _isEegCountdownDone = true;
      _eegSummaryResult = summary;
    });

    if (_museService.latestData != null) {
      await ApiService.saveMuseBrainwave(
        userId: widget.user.id,
        alphaWave: summary['avgAlpha'] as double,
        betaWave: summary['avgBeta'] as double,
        thetaWave: summary['avgTheta'] as double,
        deltaWave: summary['avgDelta'] as double,
        gammaWave: summary['avgGamma'] as double,
        attentionScore: summary['avgAttention'] as double,
        meditationScore: summary['avgMeditation'] as double,
        deviceName: _museService.deviceName ?? 'Muse',
        sessionPhase: 'qeeg_90s',
      );
    }

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

  Future<void> _saveBrainwaveData() async {
    if (_museService.latestData == null) return;

    final data = _museService.latestData!;
    final result = await ApiService.saveMuseBrainwave(
      userId: widget.user.id,
      alphaWave: data.alpha,
      betaWave: data.beta,
      thetaWave: data.theta,
      deltaWave: data.delta,
      gammaWave: data.gamma,
      attentionScore: data.attention,
      meditationScore: data.meditation,
      deviceName: _museService.deviceName ?? 'Muse S',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true ? 'บันทึกข้อมูลสำเร็จ' : 'ไม่สามารถบันทึกได้'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _reset3DModel({bool popupOnly = false}) {
    const splineUrl = 'https://my.spline.design/untitled-HfIixx8UIc1mREO9Ims7nA0X/';
    if (popupOnly) {
      _popupWebViewController.loadRequest(Uri.parse(splineUrl));
    } else {
      _webViewController.loadRequest(Uri.parse(splineUrl));
    }
  }

  void _show3DModelPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close 3D Model',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 32,
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F1629), Color(0xFF1A1F3D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF4A7FC1).withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A7FC1).withOpacity(0.25),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // 3D Model WebView (uses separate controller)
                    Positioned.fill(
                      child: WebViewWidget(
                        controller: _popupWebViewController,
                        gestureRecognizers: {
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                      ),
                    ),

                    // Top gradient overlay for header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F1629).withOpacity(0.95),
                                const Color(0xFF0F1629).withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Header with title and close button
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 16,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A7FC1), Color(0xFF6BA3E8)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Muse EEG Headband',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Interactive 3D Model',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _reset3DModel(popupOnly: true),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: Icon(Icons.replay_rounded, color: Colors.white.withOpacity(0.7), size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.15)),
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 90,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0F1629).withOpacity(0.0),
                                const Color(0xFF0F1629).withOpacity(0.95),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom hint
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 16, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(width: 8),
                              Text(
                                'ลากเพื่อหมุน • บีบเพื่อซูม',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A7FC1), Color(0xFF6BA3E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A7FC1).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A7FC1),
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
                          Text(
                            'สวัสดี!',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                          ),
                          Text(
                            widget.user.fullName ?? widget.user.username,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // 3D Model Embedded View — Premium Dark Card
              GestureDetector(
                onDoubleTap: _show3DModelPopup,
                child: Container(
                  width: double.infinity,
                  height: 380,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1629), Color(0xFF1A1F3D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF4A7FC1).withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A7FC1).withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // WebView with 3D model
                        Positioned.fill(
                          child: WebViewWidget(
                            controller: _webViewController,
                            gestureRecognizers: {
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                          ),
                        ),

                        // Loading overlay
                        if (!_is3DModelLoaded)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF0F1629),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: const Color(0xFF4A7FC1).withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'กำลังโหลด 3D Model...',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Top label badge
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6BA3E8),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6BA3E8).withOpacity(0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '3D Model',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Top-right action buttons (reset + expand)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Reset button
                              GestureDetector(
                                onTap: () => _reset3DModel(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Icon(
                                    Icons.replay_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Expand button
                              GestureDetector(
                                onTap: _show3DModelPopup,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Icon(
                                    Icons.fullscreen_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom gradient overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 80,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0F1629).withOpacity(0.0),
                                    const Color(0xFF0F1629).withOpacity(0.9),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Bottom info row
                        Positioned(
                          bottom: 14,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              // Touch hint
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, size: 14, color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'หมุนหรือซูมเพื่อดู',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Muse label
                              Text(
                                'Muse Headband',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
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
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _museService.isConnected
                        ? [const Color(0xFF11998e), const Color(0xFF38ef7d)]
                        : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (_museService.isConnected ? const Color(0xFF11998e) : const Color(0xFF667eea)).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [

                    Positioned(
                      top: -15,
                      right: -15,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _museService.isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Muse EEG Headband',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _museService.status,
                                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                                  ),
                                ],
                              ),
                            ),
                            if (_museService.isConnected)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (_museService.deviceName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.devices_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(width: 4),
                              Text('${_museService.deviceName}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading || _museService.isConnecting
                                    ? null
                                    : (_museService.isConnected ? _disconnectMuse : _scanAndConnect),
                                icon: _isLoading || _museService.isConnecting
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Icon(
                                        _museService.isConnected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_searching_rounded,
                                        size: 18,
                                        color: _museService.isConnected ? Colors.white : const Color(0xFF667eea),
                                      ),
                                label: Text(
                                  _museService.isConnecting
                                      ? 'กำลังเชื่อมต่อ...'
                                      : (_museService.isConnected ? 'ยกเลิกเชื่อมต่อ' : 'เชื่อมต่อ Muse'),
                                  style: TextStyle(
                                    color: _museService.isConnected ? Colors.white : const Color(0xFF667eea),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _museService.isConnected ? Colors.white.withOpacity(0.2) : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            if (_museService.isConnected && _museService.latestData != null) ...[
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _saveBrainwaveData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: const Text('💾 บันทึก', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE8F0FE)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3)),
                    ],
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'รอสัญญาณจากอุปกรณ์... ตรวจสอบว่าสวม Muse แนบหน้าผากแล้ว',
                                  style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.science_rounded, color: Color(0xFF667eea), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _museService.isWaitingForFFT
                                      ? 'Buffer เต็มแล้ว กำลัง FFT แปลงสัญญาณเป็นคลื่นความถี่...'
                                      : 'ต้องสะสม 256 samples เพื่อให้ FFT วิเคราะห์คลื่นสมองได้แม่นยำ',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF5A67D8)),
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

              if (_museService.isConnected && _museService.latestData != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text('คลื่นสมอง (EEG)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                          const Spacer(),
                          if (_museService.isSimulating)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                              child: const Text('จำลอง', style: TextStyle(fontSize: 10, color: Colors.orange)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildWaveRow('Delta (0.5-4 Hz)', _museService.latestData!.delta, Colors.purple, 'การนอนหลับลึก'),
                      _buildWaveRow('Theta (4-8 Hz)', _museService.latestData!.theta, Colors.green, 'ผ่อนคลาย/สมาธิ'),
                      _buildWaveRow('Alpha (8-12 Hz)', _museService.latestData!.alpha, Colors.blue, 'ตื่นตัว ผ่อนคลาย'),
                      _buildWaveRow('Beta (12-30 Hz)', _museService.latestData!.beta, Colors.orange, 'คิดวิเคราะห์'),
                      _buildWaveRow('Gamma (30+ Hz)', _museService.latestData!.gamma, Colors.red, 'สมาธิสูง'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
    );
  }

  Widget _buildWaveRow(String name, double value, Color color, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(name, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value / 100,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${value.round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.right),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 120),
            child: Text(desc, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text('$value%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStressDisplay(String? stressLevel, int? score) {
    switch (stressLevel) {
      case 'normal':
        return {'label': 'ปกติ', 'emoji': '😊', 'color': const Color(0xFF4CAF50)};
      case 'mild':
        return {'label': 'ซึมเศร้าเล็กน้อย', 'emoji': '😐', 'color': const Color(0xFFFFC107)};
      case 'moderate':
        return {'label': 'ซึมเศร้าปานกลาง', 'emoji': '😟', 'color': const Color(0xFFFF9800)};
      case 'high':
        return {'label': 'ค่อนข้างรุนแรง', 'emoji': '😰', 'color': const Color(0xFFFF5722)};
      case 'severe':
        return {'label': 'รุนแรง', 'emoji': '🆘', 'color': const Color(0xFFF44336)};
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

    final alpha = (_latestBrainwave?['alpha_wave'] as num?)?.toDouble();
    final beta = (_latestBrainwave?['beta_wave'] as num?)?.toDouble();
    final attention = (_latestBrainwave?['attention_score'] as num?)?.toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.08), statusColor.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text('สรุปสุขภาพสมอง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
              const Spacer(),
              if (!_healthLoaded)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),

          if (_latestTestResult != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display['label'],
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: statusColor),
                      ),
                      Text(
                        'PHQ-9: ${stressScore ?? depressionScore ?? '-'}/27 คะแนน',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_latestTestResult?['test_date'] != null)
              Text(
                'ทดสอบล่าสุด: ${_formatDate(_latestTestResult!['test_date'])}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ] else ...[
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ยังไม่ได้ทดสอบ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('ทำแบบทดสอบ PHQ-9 เพื่อประเมินผล', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ],

        ],
      ),
    );
  }

  Widget _buildResponsive(Widget Function(bool narrow) builder) {
    return LayoutBuilder(builder: (_, c) => builder(c.maxWidth < 560));
  }

  Widget _buildModelPredictionSubcard({
    required String title,
    required EmotionResult? emotion,
    required bool isPyTorch,
  }) {
    final emotionType = emotion != null ? EmotionType.fromString(emotion.emotionType) : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPyTorch ? const Color(0xFF4F46E5) : const Color(0xFF0F1B4C),
            ),
          ),
          const SizedBox(height: 8),
          if (emotion != null && emotionType != null) ...[
            Row(
              children: [
                Text(
                  emotionType.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emotionType.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: emotion.confidence.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  emotion.confidence >= 0.7
                                      ? Colors.green
                                      : emotion.confidence >= 0.4
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(emotion.confidence * 100).toStringAsFixed(0)}%',
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
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'รอข้อมูล EEG...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.08),
            const Color(0xFF764ba2).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_emotions, color: Color(0xFF667eea), size: 20),
              const SizedBox(width: 8),
              const Text(
                'การตรวจจับอารมณ์ (AI)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF667eea)),
              ),
              const Spacer(),
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
          const SizedBox(height: 16),
          _buildResponsive((narrow) => narrow
              ? Column(
                  children: [
                    _buildModelPredictionSubcard(
                      title: 'โมเดล PyTorch (หลัก)',
                      emotion: _pytorchEmotion,
                      isPyTorch: true,
                    ),
                    const SizedBox(height: 12),
                    _buildModelPredictionSubcard(
                      title: 'โมเดล TFLite (สำรอง)',
                      emotion: _tfliteEmotion,
                      isPyTorch: false,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildModelPredictionSubcard(
                        title: 'โมเดล PyTorch (หลัก)',
                        emotion: _pytorchEmotion,
                        isPyTorch: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModelPredictionSubcard(
                        title: 'โมเดล TFLite (สำรอง)',
                        emotion: _tfliteEmotion,
                        isPyTorch: false,
                      ),
                    ),
                  ],
                )),
        ],
      ),
    );
  }

  List<Widget> _buildEmotionScoreBars(Map<String, double> scores) {
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.take(5).toList();

    return top.map((entry) {
      final etype = EmotionType.fromString(entry.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 65,
              child: Text(etype.label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: entry.value.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getEmotionBarColor(entry.value),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 35,
              child: Text(
                '${(entry.value * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getEmotionBarColor(double value) {
    if (value >= 0.7) return const Color(0xFF667eea);
    if (value >= 0.4) return const Color(0xFFa8b4f0);
    return Colors.blueGrey[300]!;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatCard({required IconData icon, required String label, required Color iconColor, String? value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700]), overflow: TextOverflow.ellipsis),
                  if (value != null)
                    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: iconColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, List<Color> gradient = const [Color(0xFF4A7FC1), Color(0xFF6BA3E8)]}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // === EEG Countdown Card ===
  Widget _buildEegCountdownCard() {
    final minutes = _eegCountdownSeconds ~/ 60;
    final seconds = _eegCountdownSeconds % 60;
    final progress = 1.0 - (_eegCountdownSeconds / 120.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isEegCountdownRunning
              ? [const Color(0xFF1a237e).withOpacity(0.1), const Color(0xFF0d47a1).withOpacity(0.05)]
              : [const Color(0xFF0d47a1).withOpacity(0.08), const Color(0xFF1565c0).withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isEegCountdownRunning
              ? const Color(0xFF1a237e).withOpacity(0.3)
              : const Color(0xFF0d47a1).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: Color(0xFF1a237e), size: 22),
              const SizedBox(width: 8),
              const Text(
                'ทดสอบคลื่นสมอง EEG (1.5 นาที)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1a237e)),
              ),
              const Spacer(),
              if (_isEegCountdownRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('กำลังบันทึก', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'บันทึกคลื่นสมองเพื่อวิเคราะห์ภาวะซึมเศร้า (qEEG)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          if (_isEegCountdownRunning) ...[
            // Timer display
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF1a237e), Color(0xFF0d47a1)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF1a237e).withOpacity(0.3), blurRadius: 20, spreadRadius: 3)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '$minutes:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFF1a237e).withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1a237e)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_eegSamples.length} samples', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1a237e))),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _stopEegCountdown,
                icon: const Icon(Icons.stop_rounded, color: Colors.red, size: 18),
                label: const Text('หยุดทดสอบ', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startEegCountdown,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                label: const Text('เริ่มทดสอบคลื่นสมอง', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a237e),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openEegReportHistory,
                icon: const Icon(Icons.history_rounded, color: Color(0xFF1a237e), size: 20),
                label: const Text(
                  'ดูประวัติใบสรุป qEEG',
                  style: TextStyle(color: Color(0xFF1a237e), fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1a237e)),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openLatestReport,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: riskColor.withValues(alpha: 0.4)),
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
                      'ใบสรุปประเมินภาวะซึมเศร้า (qEEG)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      s['riskLevel'] as String? ?? '',
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.w600),
                    ),
                    Text(
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
}

