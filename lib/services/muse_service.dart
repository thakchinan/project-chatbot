import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'fft_calculator.dart';

class BrainwaveData {
  final double alpha;
  final double beta;
  final double theta;
  final double delta;
  final double gamma;
  final double attention;
  final double meditation;
  final DateTime timestamp;

  BrainwaveData({
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.delta,
    required this.gamma,
    this.attention = 0,
    this.meditation = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'alpha': alpha,
    'beta': beta,
    'theta': theta,
    'delta': delta,
    'gamma': gamma,
    'attention': attention,
    'meditation': meditation,
  };
}

class MuseService extends ChangeNotifier {
  static final MuseService _instance = MuseService._internal();
  factory MuseService() => _instance;
  MuseService._internal();

  BluetoothDevice? _connectedDevice;
  List<ScanResult> _scanResults = [];
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  final List<StreamSubscription> _dataSubscriptions = [];

  bool _isScanning = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _status = 'ไม่ได้เชื่อมต่อ';
  String? _deviceName;

  BrainwaveData? _latestData;
  final List<BrainwaveData> _dataHistory = [];

  final int _windowSize = 256;
  final List<double> _tp9Window = [];
  final List<double> _af7Window = [];
  final List<double> _af8Window = [];
  final List<double> _tp10Window = [];

  bool _isMuse2 = false;

  Timer? _simulationTimer;
  bool _isSimulating = false;
  bool _isDisposed = false;

  Timer? _fftDelayTimer;
  final int _fftDelayMs = 1000;
  final int _minBufferFill = 256;
  int _packetCount = 0;
  DateTime? _lastFFTTime;

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isSimulating => _isSimulating;
  String get status => _status;
  String? get deviceName => _deviceName;
  bool get isMuse2 => _isMuse2;

  String get detectedDeviceType => _isMuse2 ? 'Muse 2' : 'Muse S';
  BrainwaveData? get latestData => _latestData;
  List<BrainwaveData> get dataHistory => _dataHistory;
  List<ScanResult> get scanResults => _scanResults;

  int get bufferFillLevel => _tp9Window.length;
  int get minBufferRequired => _minBufferFill;
  int get packetCount => _packetCount;
  double get bufferProgress => _tp9Window.length / _minBufferFill;
  bool get isBuffering => _isConnected && _latestData == null && _packetCount > 0;
  bool get isWaitingForFFT => _tp9Window.length >= _minBufferFill && _latestData == null;

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<bool> isBluetoothAvailable() async {
    if (kIsWeb) return false;
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    if (kIsWeb) return;

    try {

    if (!await _checkPermissions()) {
      _status = 'ต้องการสิทธิ์ Bluetooth/Location';
      _safeNotify();
      return;
    }

      if (!await FlutterBluePlus.isSupported) return;

      if (Platform.isAndroid) {
         try { await FlutterBluePlus.turnOn(); } catch (e) {}
      }

      _isScanning = true;
      _scanResults = [];
  _status = 'กำลังค้นหาอุปกรณ์ Muse...';
  _safeNotify();

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results.where((r) {
          final name = r.device.platformName.toLowerCase();
          return name.contains('muse') || name.contains('headband');
        }).toList();

        if (_scanResults.isNotEmpty) {
          _status = 'พบอุปกรณ์ ${_scanResults.length} เครื่อง';
        }
        _safeNotify();
      });

      FlutterBluePlus.isScanning.where((val) => val == false).first.then((_) {
        _isScanning = false;
        if (_scanResults.isEmpty && !_isConnected) {
          _status = 'ไม่พบอุปกรณ์ - ลองใหม่';
        }
        _safeNotify();
      });

    } catch (e) {
      _isScanning = false;
      _status = 'Error: $e';
      _safeNotify();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _isScanning = false;
    _safeNotify();
  }

  Timer? _dataWatchdog;
  bool _dataReceivedRecently = false;
  List<BluetoothCharacteristic> _writableChars = [];
  BluetoothCharacteristic? _controlChar;

  Future<void> connectToDevice(BluetoothDevice device) async {
    await stopScan();

    try {
  _isConnecting = true;
  _status = 'เชื่อมต่อ ${device.platformName}...';
  _safeNotify();

      if (Platform.isAndroid) {
          try { await device.clearGattCache(); } catch (e) {}
      }

      await device.connect(timeout: const Duration(seconds: 20), autoConnect: false);

  _connectedDevice = device;
  _deviceName = device.platformName;

  _isMuse2 = device.platformName.toLowerCase().contains('muse-2') ||
             device.platformName.toLowerCase().contains('muse 2') ||
             device.platformName.toLowerCase() == 'muse2';
  debugPrint('🎧 Detected device type: ${_isMuse2 ? "Muse 2 (12-bit)" : "Muse S (14-bit)"}');
  _isConnected = true;
  _isConnecting = false;
  _status = 'เชื่อมต่อแล้ว (รอ Set up)...';
  _safeNotify();

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      await Future.delayed(const Duration(seconds: 1));
      await _setupMuseConnection();

    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _status = 'เชื่อมต่อล้มเหลว: $e';
      _safeNotify();
    }
  }

  Future<void> _setupMuseConnection() async {
    if (_connectedDevice == null) return;

    try {
  _status = 'Discovering Services...';
  _safeNotify();

      List<BluetoothService> services = await _connectedDevice!.discoverServices();

      try { if (Platform.isAndroid) await _connectedDevice!.requestMtu(512); } catch (e) {}

      List<BluetoothCharacteristic> eegChars = [];
      List<BluetoothCharacteristic> allNotifyChars = [];
      _writableChars = [];
      _controlChar = null;

      for (var service in services) {
        debugPrint('🔍 Service: ${service.uuid}');
        for (var c in service.characteristics) {
           final uuid = c.uuid.toString().toLowerCase();
           debugPrint('   📌 Char: $uuid | notify=${c.properties.notify} | write=${c.properties.write} | writeNoResp=${c.properties.writeWithoutResponse}');

           if (c.properties.notify) {
              allNotifyChars.add(c);

              if (uuid.contains('273e0003') || uuid.contains('273e0004') ||
                  uuid.contains('273e0005') || uuid.contains('273e0006')) {
                 eegChars.add(c);
              }
           }

           if (c.properties.write || c.properties.writeWithoutResponse) {
              _writableChars.add(c);
              if (uuid.contains('273e0001')) {
                _controlChar = c;
                debugPrint('   ✅ Found Muse Control Characteristic: $uuid');
              }
           }
        }
      }

      if (eegChars.isEmpty) {
         eegChars = allNotifyChars;
      }

    if (eegChars.isEmpty) {
      _status = 'Error: ไม่พบช่องสัญญาณ (Notify=0)';
      _safeNotify();

    } else {
      _status = 'Found ${eegChars.length} Channels. Subscribing...';
      _safeNotify();
    }

      int subs = 0;
      for (var c in eegChars) {
         try {
            await c.setNotifyValue(true);
            var sub = c.lastValueStream.listen((value) {
                _processEEGData(c.uuid.toString(), value);
            });
            _dataSubscriptions.add(sub);
            subs++;
            await Future.delayed(const Duration(milliseconds: 50));
         } catch (e) {}
      }

  _status = 'Ready (Subs:$subs). Sending Start...';
  _safeNotify();

      if (_controlChar != null) {
          debugPrint('🎯 Sending start commands to Control Char');
          await _sendStartCommands(_controlChar!);
      } else {
          debugPrint('⚠️ No control char found, trying all writable chars');
          for (var char in _writableChars) {
              await _sendStartCommands(char);
              await Future.delayed(const Duration(milliseconds: 50));
          }
      }

      _dataWatchdog?.cancel();
      _dataWatchdog = Timer.periodic(const Duration(seconds: 3), (t) {
          if (!_isConnected) { t.cancel(); return; }

          if (!_dataReceivedRecently) {
             _status = 'กำลังปลุก... (Wakeup ${t.tick})';
             _safeNotify();
             if (_controlChar != null) {
                _sendStartCommands(_controlChar!);
             } else {
                for (var char in _writableChars) {
                   _sendStartCommands(char);
                }
             }
          } else {
             _dataReceivedRecently = false;
          }
      });

    } catch (e) {
      _status = 'Setup Error: $e';
      _safeNotify();
    }
  }

  Future<void> _sendStartCommands(BluetoothCharacteristic c) async {
     // 1. Halt — หยุด streaming เก่า
     await _writeRaw(c, [0x02, 0x68, 0x0a]);
     await Future.delayed(const Duration(milliseconds: 100));

     // 2. Request device info
     await _writeRaw(c, [0x02, 0x76, 0x0a]);
     await Future.delayed(const Duration(milliseconds: 100));

     // 3. Set Preset 21 (EEG data) — ต้องมี length prefix!
     await _writeRaw(c, [0x04, 0x70, 0x32, 0x31, 0x0a]);
     await Future.delayed(const Duration(milliseconds: 100));

     // 4. Start streaming
     await _writeRaw(c, [0x02, 0x73, 0x0a]);
     await Future.delayed(const Duration(milliseconds: 100));

     // 5. Resume (ถ้าถูก pause)
     await _writeRaw(c, [0x02, 0x64, 0x0a]);

     debugPrint('📤 Start commands sent to ${c.uuid}');
  }

  Future<void> _writeRaw(BluetoothCharacteristic c, List<int> cmd) async {
    try {
      await c.write(cmd, withoutResponse: true);
    } catch (e) {
      debugPrint('❌ BLE Write Error (${c.uuid}): $e | cmd=$cmd');
    }
  }

  void _processEEGData(String uuid, List<int> rawData) {
     if (rawData.isEmpty) return;
     _dataReceivedRecently = true;
     _packetCount++;
     _status = 'รับข้อมูล... (${rawData.length} bytes, packet #$_packetCount)';

     try {
       List<double> samples = _parseMuseEEGPacket(rawData);
       String lowerUuid = uuid.toLowerCase();

       if (lowerUuid.contains('273e0003')) {
         _addToWindow(_tp9Window, samples);
       } else if (lowerUuid.contains('273e0004')) {
         _addToWindow(_af7Window, samples);
       } else if (lowerUuid.contains('273e0005')) {
         _addToWindow(_af8Window, samples);
       } else if (lowerUuid.contains('273e0006')) {
         _addToWindow(_tp10Window, samples);
       }

       _scheduleFFT();

     } catch (e) {}
  }

  void _scheduleFFT() {
    if (_tp9Window.length < _minBufferFill) {
      _status = 'สะสมข้อมูล... (${_tp9Window.length}/$_minBufferFill samples)';
      _safeNotify();
      return;
    }

    // ครั้งแรก: คำนวณทันที ไม่ต้องรอ
    if (_lastFFTTime == null) {
      debugPrint('⚡ First FFT — computing immediately!');
      _calculateFFT();
      _lastFFTTime = DateTime.now();
      return;
    }

    // ครั้งถัดไป: Throttle — คำนวณได้สูงสุดทุก 1 วินาที
    final elapsed = DateTime.now().difference(_lastFFTTime!).inMilliseconds;
    if (elapsed >= _fftDelayMs) {
      _calculateFFT();
      _lastFFTTime = DateTime.now();
      debugPrint('🔄 FFT updated | Buffer: TP9=${_tp9Window.length}, AF7=${_af7Window.length}, AF8=${_af8Window.length}, TP10=${_tp10Window.length}');
    }
  }

  void _addToWindow(List<double> window, List<double> newSamples) {
    window.addAll(newSamples);
    if (window.length > _windowSize) window.removeRange(0, window.length - _windowSize);
  }

  List<double> _parseMuseEEGPacket(List<int> rawData) {
    List<double> samples = [];

    if (_isMuse2 && rawData.length >= 20) {
      // Muse 2 (12-bit Encoding): ข้อมูลเริ่มที่ Byte 2, ใช้ 3 Byte ต่อ 2 Samples
      for (int i = 2; i < rawData.length - 2; i += 3) {
        int b1 = rawData[i];
        int b2 = rawData[i+1];
        int b3 = rawData[i+2];

        int s1 = (b1 << 4) | (b2 >> 4);
        int s2 = ((b2 & 0x0F) << 8) | b3;

        samples.add((s1 / 4095.0) * 1682.0);
        samples.add((s2 / 4095.0) * 1682.0);
      }
    } else {
      // รุ่นเก่า หรือการเข้ารหัสแบบ 16-bit
      final double maxRawValue = 65535.0;
      if (rawData.length >= 6) {
        for (int i = 2; i < rawData.length - 1; i += 2) {
           int s = (rawData[i] << 8) | rawData[i+1];
           samples.add( (s / maxRawValue) * 1682.0 );
        }
      }
    }
    return samples;
  }

  void _calculateFFT() {

     Map<String, double> getPower(List<double> buf) {
        if (buf.isEmpty) return {};
        List<double> p = List.from(buf);
        if (p.length < _windowSize) p.addAll(List.filled(_windowSize - p.length, 0.0));
        try {
           var mags = FFTCalculator.computeMagnitudes(p);
           return FFTCalculator.calculateBandPowers(mags, 256);
        } catch (e) { return {}; }
     }

     var p1 = getPower(_tp9Window);
     var p2 = getPower(_af7Window);
     var p3 = getPower(_af8Window);
     var p4 = getPower(_tp10Window);

     double totalAlpha = 0, totalBeta = 0, totalTheta = 0, totalDelta = 0, totalGamma = 0;
     int validChannels = 0;

     void addPower(Map<String, double> p) {
       if (p.isNotEmpty) {
         totalAlpha += (p['alpha'] ?? 0);
         totalBeta += (p['beta'] ?? 0);
         totalTheta += (p['theta'] ?? 0);
         totalDelta += (p['delta'] ?? 0);
         totalGamma += (p['gamma'] ?? 0);
         validChannels++;
       }
     }

     addPower(p1);
     addPower(p2);
     addPower(p3);
     addPower(p4);

     if (validChannels == 0) return;

     double sum = totalAlpha + totalBeta + totalTheta + totalDelta + totalGamma;
     if (sum == 0) sum = 1;

     _latestData = BrainwaveData(
        alpha: (totalAlpha/sum)*100,
        beta: (totalBeta/sum)*100,
        theta: (totalTheta/sum)*100,
        delta: (totalDelta/sum)*100,
        gamma: (totalGamma/sum)*100,
        attention: 50,
        meditation: 50
     );

     _dataHistory.add(_latestData!);
     if (_dataHistory.length > 100) _dataHistory.removeAt(0);
     
     // แสดงค่าออก Console เพื่อให้ดูได้สะดวกขึ้น
     debugPrint('Brainwaves -> Alpha: ${_latestData!.alpha.toStringAsFixed(2)}%, Beta: ${_latestData!.beta.toStringAsFixed(2)}%, Theta: ${_latestData!.theta.toStringAsFixed(2)}%');
     
    _safeNotify();
  }

  Future<void> disconnect() async {
    _fftDelayTimer?.cancel();
    _dataWatchdog?.cancel();
    _scanSubscription?.cancel();
    stopSimulation();
    try { await _connectedDevice?.disconnect(); } catch (e) {}
    _isConnected = false;
    _connectedDevice = null;
    _packetCount = 0;
    _lastFFTTime = null;
    _status = 'ไม่ได้เชื่อมต่อ';
    _safeNotify();
  }

  void startSimulation() {
     if(_isSimulating) return;
     _isSimulating = true;
     _isConnected = true;
     _status = 'Simulation Mode';
     _safeNotify();
     _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
         _latestData = BrainwaveData(alpha: Random().nextDouble()*100, beta: Random().nextDouble()*100, theta: 20, delta: 10, gamma: 5);
         _safeNotify();
     });
  }

  void stopSimulation() {
     _simulationTimer?.cancel();
     _isSimulating = false;
     if(_deviceName == null) _isConnected = false;
     _safeNotify();
  }

  @override
  void dispose() {

    _isDisposed = true;

    _fftDelayTimer?.cancel();
    _dataWatchdog?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    for (var s in _dataSubscriptions) {
      try { s.cancel(); } catch (e) {}
    }
    _dataSubscriptions.clear();
    _simulationTimer?.cancel();
    try { _connectedDevice?.disconnect(); } catch (e) {}
    super.dispose();
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.bluetoothScan.request().isGranted &&
          await Permission.bluetoothConnect.request().isGranted &&
          await Permission.location.request().isGranted) {
            return true;
      }
      return false;
    }
    return true;
  }
}
