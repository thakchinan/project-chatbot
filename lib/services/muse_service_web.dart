import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'muse_types.dart';

/// Web build: BLE unavailable; simulation mode provides demo EEG data.
class MuseService extends ChangeNotifier {
  static final MuseService _instance = MuseService._internal();
  factory MuseService() => _instance;
  MuseService._internal();

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

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isSimulating => _isSimulating;
  String get status => _status;
  String? get deviceName => _deviceName;
  bool get isMuse2 => false;

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
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final r = Random();
      _latestData = BrainwaveData(
        alpha: r.nextDouble() * 100,
        beta: r.nextDouble() * 100,
        theta: 20 + r.nextDouble() * 30,
        delta: 10 + r.nextDouble() * 20,
        gamma: 5 + r.nextDouble() * 15,
        attention: r.nextDouble() * 100,
        meditation: r.nextDouble() * 100,
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
    _simulationTimer?.cancel();
    super.dispose();
  }
}
