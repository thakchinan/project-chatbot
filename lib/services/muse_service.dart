// บริการนำเข้าและส่งออกไฟล์เชื่อมต่ออุปกรณ์ Muse S แบบมีเงื่อนไข (Conditional Export)
// เพื่อให้แอปพลิเคชันสามารถรองรับทั้งบนอุปกรณ์เคลื่อนที่ (Android/iOS via _io) และเว็บบราวเซอร์ (via _web)
export 'muse_service_io.dart' if (dart.library.html) 'muse_service_web.dart';
export 'muse_types.dart';

