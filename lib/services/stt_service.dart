// บริการนำเข้าและส่งออกโมดูลจำเสียงพูด Speech-to-Text แบบมีเงื่อนไข (Conditional Export)
// แยกการประมวลผลคำพูดระหว่างอุปกรณ์เคลื่อนที่ (Android/iOS via _io) และเว็บบราวเซอร์ (via _web)
export 'stt_service_io.dart' if (dart.library.html) 'stt_service_web.dart';
