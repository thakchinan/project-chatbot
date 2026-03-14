/// Emotion Detection Module
/// 
/// โมดูลสำหรับตรวจจับอารมณ์จากข้อมูลต่างๆ เช่น EEG, ใบหน้า, เสียง
/// 
/// การใช้งาน:
/// ```dart
/// import 'package:brain_wave_flutter/emotion_detection/emotion_detection.dart';
/// ```

// Models
export 'models/emotion_result.dart';
export 'models/emotion_type.dart';

// Services
export 'services/emotion_detection_service.dart';
export 'services/emotion_analyzer.dart';

// Widgets
export 'widgets/emotion_display_widget.dart';
export 'widgets/emotion_chart_widget.dart';

// Utils
export 'utils/emotion_constants.dart';
