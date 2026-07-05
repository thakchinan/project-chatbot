import 'package:flutter/foundation.dart';

/// Web build ของ STTService: เนื่องจากข้อจำกัดด้านการจัดการสิทธิ์ไมโครโฟนและการบันทึกไฟล์เสียง m4a ในเว็บบราวเซอร์ 
/// ระบบจึงปิดใช้งานฟังก์ชันไมโครโฟนสำหรับการพูด โดยแนะนำให้พิมพ์คำค้นหาทางข้อความแทนในกรณีที่เปิดบนเบราว์เซอร์
class STTService {
  static final STTService _instance = STTService._internal();
  factory STTService() => _instance;
  STTService._internal();

  bool _isListening = false;
  final String _lastRecognizedText = '';

  Function(String)? onResult;
  Function(String)? onPartialResult;
  Function()? onListeningStarted;
  Function()? onListeningStopped;
  Function(String)? onError;

  bool get isListening => _isListening;
  bool get isAvailable => false;
  String get lastRecognizedText => _lastRecognizedText;

  Future<bool> init() async {
    debugPrint('🎤 STT: not available on web');
    onError?.call('การพูดด้วยไมค์ยังไม่รองรับบนเว็บ กรุณาพิมพ์ข้อความ');
    return false;
  }

  Future<void> startListening() async {
    onError?.call('การพูดด้วยไมค์ยังไม่รองรับบนเว็บ กรุณาพิมพ์ข้อความ');
  }

  Future<void> stopListening() async {
    _isListening = false;
    onListeningStopped?.call();
  }

  Future<void> cancelListening() async {
    _isListening = false;
    onListeningStopped?.call();
  }

  void setLocale(String localeId) {}

  void dispose() {
    onResult = null;
    onPartialResult = null;
    onListeningStarted = null;
    onListeningStopped = null;
    onError = null;
  }
}
