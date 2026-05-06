import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../emotion_detection/emotion_detection.dart';
import 'history_screen.dart';
import 'test_screen.dart';
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
  EmotionResult? _currentEmotion;
  bool _isDetectingEmotion = false;
  Timer? _emotionDetectionTimer;
  bool _isLoading = false;

  Map<String, dynamic>? _latestTestResult;
  Map<String, dynamic>? _latestBrainwave;
  bool _healthLoaded = false;

  StreamSubscription? _testResultSub;
  StreamSubscription? _brainwaveSub;

  @override
  void initState() {
    super.initState();
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

      final result = await _emotionService.detectFromEEG(eegData);

      if (mounted) {
        setState(() {
          _currentEmotion = result;
        });

        if (result.confidence >= EmotionConstants.confidenceThreshold) {
          ApiService.saveEmotionLog(
            userId: widget.user.id,
            emotionType: result.emotionType,
            triggerEvent: 'eeg_brainwave',
            intensity: (result.confidence * 10).round(),
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

    _testResultSub?.cancel();
    _brainwaveSub?.cancel();

    _museService.removeListener(_onMuseDataUpdate);
    _museService.stopSimulation();
    super.dispose();
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
              ],

              _buildHealthSummaryCard(),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      icon: Icons.history_rounded,
                      label: 'ประวัติ',
                      gradient: const [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(user: widget.user)));
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildQuickAction(
                      context,
                      icon: Icons.quiz_rounded,
                      label: 'แบบทดสอบ',
                      gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TestScreen(user: widget.user)),
                        ).then((_) {
                          _reloadHealthData();
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
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

  Widget _buildEmotionDetectionCard() {
    final emotion = _currentEmotion;
    final emotionType = emotion != null ? EmotionType.fromString(emotion.emotionType) : null;

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

          if (emotion != null && emotionType != null) ...[

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emotionType.label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: emotion.confidence.clamp(0.0, 1.0),
                                minHeight: 8,
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
                          const SizedBox(width: 8),
                          Text(
                            '${(emotion.confidence * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
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

            if (emotion.allScores.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ..._buildEmotionScoreBars(emotion.allScores),
            ],
          ] else ...[

            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('กำลังวิเคราะห์อารมณ์...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(
                      'เชื่อมต่อ Muse S แล้ว — รอข้อมูล EEG',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
}
