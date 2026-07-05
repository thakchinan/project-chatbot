import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// STTService จัดการการแปลงสัญญาณเสียงพูดเป็นตัวอักษรภาษาไทย (Speech-to-Text) โดยใช้บริการ OpenAI Whisper API
/// ทำหน้าที่บันทึกไฟล์เสียงคลื่นความถี่ 16kHz โมโนผ่านไมโครโฟนโทรศัพท์ 
/// และส่งข้อมูลเสียงแบบ Multipart Request ไปแปลงผลที่เซิร์ฟเวอร์แบบเรียลไทม์
class STTService {
  // Singleton instance เพื่อให้ใช้ตัวควบคุมการบันทึกเสียงเดียวกันทั่วทั้งแอปพลิเคชัน
  static final STTService _instance = STTService._internal();
  factory STTService() => _instance;
  STTService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedText = '';

  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _whisperUrl =
      'https://api.openai.com/v1/audio/transcriptions';

  String? _currentRecordingPath;

  // ฟังก์ชัน Callback สำหรับการส่งคืนผลลัพธ์เสียงที่แปลงแล้ว และดักจับความเคลื่อนไหว/ข้อผิดพลาด
  Function(String)? onResult;
  Function(String)? onPartialResult;
  Function()? onListeningStarted;
  Function()? onListeningStopped;
  Function(String)? onError;

  bool get isListening => _isListening;

  bool get isAvailable => _isInitialized;

  String get lastRecognizedText => _lastRecognizedText;

  /// ตรวจสอบสิทธิ์การเข้าถึงไมโครโฟนและเปิดใช้งานไมโครโฟนเบื้องต้น
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {

      final hasPermission = await _recorder.hasPermission();
      debugPrint('🎤 Whisper STT: hasPermission = $hasPermission');

      if (!hasPermission) {
        debugPrint('🎤 Whisper STT: ไม่มีสิทธิ์ไมโครโฟน');
        onError?.call('กรุณาอนุญาตการใช้ไมโครโฟน');
        return false;
      }

      _isInitialized = true;
      debugPrint('🎤 Whisper STT: Initialized ✅');
      return true;
    } catch (e) {
      debugPrint('🎤 Whisper STT Init Error: $e');
      onError?.call('ไม่สามารถเปิดไมโครโฟนได้: $e');
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) {
        onError?.call('ไม่สามารถเปิดไมโครโฟนได้');
        return;
      }
    }

    if (_isListening) {

      await stopListening();
      return;
    }

    try {

      _isListening = true;
      _lastRecognizedText = '';
      onListeningStarted?.call();
      onPartialResult?.call('กำลังฟัง... พูดแล้วกดไมค์อีกทีเพื่อหยุด 🎤');

      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/stt_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: _currentRecordingPath!,
      );

      debugPrint('🎤 Whisper STT: Start recording → $_currentRecordingPath');
    } catch (e) {
      debugPrint('🎤 Whisper STT: Start error: $e');
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('ไม่สามารถเริ่มบันทึกเสียงได้: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      final path = await _recorder.stop();
      _isListening = false;
      debugPrint('🎤 Whisper STT: Stopped recording → $path');

      if (path != null && path.isNotEmpty) {

        onPartialResult?.call('กำลังแปลงเสียง...');

        final text = await _transcribeWithWhisper(path);

        if (text != null && text.isNotEmpty) {
          _lastRecognizedText = text;
          debugPrint('🎤 Whisper STT: Result → $text');
          onResult?.call(text);
        } else {
          debugPrint('🎤 Whisper STT: No text recognized');
          onPartialResult?.call('');
        }

        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('🎤 Whisper STT: Stop error: $e');
      _isListening = false;
      onError?.call('เกิดข้อผิดพลาดในการแปลงเสียง');
    } finally {
      onListeningStopped?.call();
    }
  }

  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _recorder.stop();
    } catch (_) {}

    _isListening = false;
    _lastRecognizedText = '';

    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    onListeningStopped?.call();
  }

  Future<String?> _transcribeWithWhisper(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('🎤 Whisper: File not found: $filePath');
        return null;
      }

      final fileSize = await file.length();
      debugPrint('🎤 Whisper: Sending file ($fileSize bytes)');

      if (fileSize < 1000) {
        debugPrint('🎤 Whisper: File too small, likely no audio');
        return null;
      }

      final request = http.MultipartRequest('POST', Uri.parse(_whisperUrl));
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'th';
      request.fields['response_format'] = 'json';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody);
        final text = json['text'] as String?;
        debugPrint('🎤 Whisper: Success → "$text"');
        return text?.trim();
      } else {
        debugPrint('🎤 Whisper: Error ${response.statusCode}: $responseBody');
        onError?.call('ไม่สามารถแปลงเสียงได้ ลองใหม่อีกครั้ง');
        return null;
      }
    } catch (e) {
      debugPrint('🎤 Whisper: Exception: $e');
      onError?.call('เกิดข้อผิดพลาดในการเชื่อมต่อ');
      return null;
    }
  }

  void setLocale(String localeId) {

    debugPrint('🎤 Whisper STT: setLocale → $localeId (auto-detected)');
  }

  void dispose() {
    cancelListening();
    try {
      // ดักจับข้อผิดพลาดแบบอะซิงโครนัสเพื่อป้องกันแอปแครช (โดยเฉพาะบน macOS/iOS Sandbox)
      _recorder.dispose().catchError((e) {
        debugPrint('⚠️ Recorder dispose error: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Recorder dispose sync error: $e');
    }
    onResult = null;
    onPartialResult = null;
    onListeningStarted = null;
    onListeningStopped = null;
    onError = null;
  }
}
