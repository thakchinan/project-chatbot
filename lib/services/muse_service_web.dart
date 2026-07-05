import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'muse_types.dart';

/// Web build ของ MuseService: เนื่องจากระบบตรวจจับ Bluetooth BLE ไม่เปิดใช้งานในสถาปัตยกรรมเว็บเบราว์เซอร์
/// จึงทดแทนด้วยโหมดจำลอง (Simulation Mode) เพื่อป้อนข้อมูลคลื่นสมองสำหรับการทดสอบแอปพลิเคชันบนเว็บ
class MuseService extends ChangeNotifier {
  static final MuseService _instance = MuseService._internal();
  factory MuseService() => _instance;
  MuseService._internal();

  // กำหนดสถานะและคุณสมบัติเช่นเดียวกับเวอร์ชันของ Native (iOS/Android) เพื่อความเข้ากันได้
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _status = 'ไม่ได้เชื่อมต่อ (เว็บ)';
  String? _deviceName;

  BrainwaveData? _latestData;
  final List<BrainwaveData> _dataHistory = [];

  Timer? _simulationTimer;
  bool _isSimulating = false;
  bool _isDisposed = false;

  // ตัวกระจายข้อมูลคลื่นสมองแบบ Raw Data ปลอมสำหรับการแกว่งของกราฟบนเว็บ
  final StreamController<Map<String, List<double>>> _rawEegController = StreamController<Map<String, List<double>>>.broadcast();

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isSimulating => _isSimulating;
  String get status => _status;
  String? get deviceName => _deviceName;
  bool get isMuse2 => false;

  // ช่องสัญญาณข้อมูลคลื่นสมองสำหรับการแสดงผลของกราฟ
  Stream<Map<String, List<double>>> get rawEegStream => _rawEegController.stream;

  String get detectedDeviceType => 'Simulation';
  BrainwaveData? get latestData => _latestData;
  List<BrainwaveData> get dataHistory => _dataHistory;
  List<MuseScanResult> get scanResults => const [];

  int get bufferFillLevel => 0;
  int get minBufferRequired => 512;
  int get packetCount => 0;
  double get bufferProgress => 0;
  double get actualHz => 0;
  int get droppedPackets => 0;
  bool get isBuffering => false;
  bool get isWaitingForFFT => false;

  double _notchFrequency = 50.0;
  double get notchFrequency => _notchFrequency;
  set notchFrequency(double val) {
    if (val == 50.0 || val == 60.0) {
      _notchFrequency = val;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<bool> isBluetoothAvailable() async => false;

  Future<void> startScan() async {
    _isScanning = true;
    _status = 'Bluetooth ไม่รองรับบนเว็บ';
    _safeNotify();
    await Future.delayed(const Duration(milliseconds: 300));
    _isScanning = false;
    _safeNotify();
  }

  Future<void> stopScan() async {
    _isScanning = false;
    _status = 'หยุดค้นหาแล้ว';
    _safeNotify();
  }

  Future<void> connectToDevice(MuseBleDevice device) async {
    _isConnecting = true;
    _status = 'เชื่อมต่อไม่ได้บนเว็บ';
    _safeNotify();
    await Future.delayed(const Duration(milliseconds: 200));
    _isConnecting = false;
    _safeNotify();
  }

  Future<void> disconnect() async {
    stopSimulation();
    _isConnected = false;
    _deviceName = null;
    _status = 'ไม่ได้เชื่อมต่อ';
    _safeNotify();
  }

  void startSimulation() {
    if (_isSimulating) return;
    _isSimulating = true;
    _isConnected = true;
    _deviceName = 'Web Simulation';
    _status = 'Simulation Mode (Web)';
    _safeNotify();

    double alphaVal = 30.0;
    double betaVal = 25.0;
    double thetaVal = 20.0;
    double deltaVal = 18.0;
    double gammaVal = 7.0;
    final r = Random();

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // Random walk with small steps for realistic fluctuations
      alphaVal = (alphaVal + (r.nextDouble() - 0.5) * 5.0).clamp(10.0, 50.0);
      betaVal = (betaVal + (r.nextDouble() - 0.5) * 4.0).clamp(10.0, 45.0);
      thetaVal = (thetaVal + (r.nextDouble() - 0.5) * 3.0).clamp(5.0, 35.0);
      deltaVal = (deltaVal + (r.nextDouble() - 0.5) * 3.0).clamp(5.0, 30.0);
      gammaVal = (gammaVal + (r.nextDouble() - 0.5) * 2.0).clamp(2.0, 20.0);

      // Normalize so they sum up to exactly 100%
      final double total = alphaVal + betaVal + thetaVal + deltaVal + gammaVal;
      final double normAlpha = (alphaVal / total) * 100;
      final double normBeta = (betaVal / total) * 100;
      final double normTheta = (thetaVal / total) * 100;
      final double normDelta = (deltaVal / total) * 100;
      final double normGamma = (gammaVal / total) * 100;

      // Simulate Attention & Meditation based on ratios
      double attentionRatio = normBeta / (normTheta + normAlpha + 0.001);
      double attention = (attentionRatio * 40 + 30 + (r.nextDouble() - 0.5) * 10).clamp(0.0, 100.0);

      double meditationRatio = normAlpha / (normBeta + normGamma + 0.001);
      double meditation = (meditationRatio * 40 + 35 + (r.nextDouble() - 0.5) * 10).clamp(0.0, 100.0);

      _latestData = BrainwaveData(
        alpha: normAlpha,
        beta: normBeta,
        theta: normTheta,
        delta: normDelta,
        gamma: normGamma,
        attention: attention,
        meditation: meditation,
      );
      _dataHistory.add(_latestData!);
      if (_dataHistory.length > 200) _dataHistory.removeAt(0);
      _safeNotify();
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _isSimulating = false;
    if (_deviceName == null) _isConnected = false;
    _status = _isConnected ? 'Simulation Mode (Web)' : 'ไม่ได้เชื่อมต่อ';
    _safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _rawEegController.close();
    _simulationTimer?.cancel();
    super.dispose();
  }
}
