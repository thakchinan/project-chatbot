import 'dart:io';
import 'supabase_service.dart';
import 'chatgpt_service.dart';
import 'auth_service.dart';

/// ApiService เป็น Facade Class สำหรับรวบรวมฟังก์ชันการเรียกใช้งาน API ทั้งหมดในจุดเดียว
/// ทำหน้าที่เป็นทางผ่านเชื่อมโยงไปยัง SupabaseService, ChatGPTService, และ AuthService
/// ช่วยให้ส่วนควบคุมการทำงานด้าน UI เรียกใช้การจัดการข้อมูลหลังบ้านและโมเดลปัญญาประดิษฐ์ได้สะดวกยิ่งขึ้น
class ApiService {

  // ═══════════════════════════════════════════
  //  Authentication — ระบบยืนยันตัวตน
  // ═══════════════════════════════════════════

  /// สมัครสมาชิกด้วย email + password (ผ่าน Supabase Auth)
  static Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    String? birthDate,
  }) async {
    return AuthService.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      birthDate: birthDate,
    );
  }

  /// เข้าสู่ระบบด้วย email + password
  static Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AuthService.signInWithEmail(email: email, password: password);
  }

  /// เข้าสู่ระบบด้วย Google Sign-In
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    return AuthService.signInWithGoogle();
  }

  /// ส่งอีเมลรีเซ็ตรหัสผ่าน (ลืมรหัสผ่าน)
  static Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    return AuthService.sendPasswordResetEmail(email);
  }

  /// ออกจากระบบ
  static Future<void> signOut() async {
    return AuthService.signOut();
  }

  /// ตรวจสอบว่าผู้ใช้ล็อกอินอยู่หรือไม่
  static bool get isLoggedIn => AuthService.isLoggedIn;

  /// กู้คืน session เมื่อเปิดแอปซ้ำ (Auto-login)
  static Future<Map<String, dynamic>> restoreSession() async {
    return AuthService.restoreSession();
  }

  // ═══════════════════════════════════════════
  //  Legacy Login — ล็อกอินแบบเดิม (username/password)
  // ═══════════════════════════════════════════

  /// เข้าสู่ระบบด้วยชื่อผู้ใช้งานและรหัสผ่าน
  static Future<Map<String, dynamic>> login(String username, String password) async {
    return SupabaseService.login(username, password);
  }

  /// ลงทะเบียนผู้ใช้งานใหม่พร้อมรายละเอียดข้อมูลส่วนตัว
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? fullName,
    String? phone,
    String? email,
    String? birthDate,
  }) async {
    return SupabaseService.register(
      username: username,
      password: password,
      fullName: fullName,
      phone: phone,
      email: email,
      birthDate: birthDate,
    );
  }

  /// ดึงข้อมูลโปรไฟล์ของผู้ใช้งานด้วยรหัสไอดีผู้ใช้
  static Future<Map<String, dynamic>> getProfile(int userId) async {
    return SupabaseService.getProfile(userId);
  }

  /// อัปเดตข้อมูลรายละเอียดโปรไฟล์ของผู้ใช้
  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? fullName,
    String? phone,
    String? email,
    String? birthDate,
  }) async {
    return SupabaseService.updateProfile(
      userId: userId,
      fullName: fullName,
      phone: phone,
      email: email,
      birthDate: birthDate,
    );
  }

  /// อัปโหลดรูปภาพโปรไฟล์ (Avatar) ไปยัง Supabase Storage
  static Future<Map<String, dynamic>> uploadAvatar({
    required int userId,
    required File imageFile,
  }) async {
    return SupabaseService.uploadAvatar(
      userId: userId,
      imageFile: imageFile,
    );
  }

  /// เปลี่ยนรหัสผ่านของผู้ใช้งาน
  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    String? currentPassword,
    required String newPassword,
  }) async {
    return SupabaseService.changePassword(
      userId: userId,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// บันทึกผลลัพธ์การทำแบบทดสอบคัดกรองสุขภาพจิต (PHQ-9)
  static Future<Map<String, dynamic>> saveTestResult({
    required int userId,
    required int stressScore,
    required int depressionScore,
    required String stressLevel,
  }) async {
    return SupabaseService.saveTestResult(
      userId: userId,
      stressScore: stressScore,
      depressionScore: depressionScore,
      stressLevel: stressLevel,
    );
  }

  /// ดึงข้อมูลประวัติการทำแบบทดสอบทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getTestResults(int userId) async {
    return SupabaseService.getTestResults(userId);
  }

  /// บันทึกข้อมูลวิเคราะห์คลื่นสมองลงฐานข้อมูล
  static Future<Map<String, dynamic>> saveBrainwaveData({
    required int userId,
    required double alphaWave,
    required double betaWave,
    required double thetaWave,
    required double deltaWave,
  }) async {
    return SupabaseService.saveBrainwaveData(
      userId: userId,
      alphaWave: alphaWave,
      betaWave: betaWave,
      thetaWave: thetaWave,
      deltaWave: deltaWave,
    );
  }

  /// ดึงข้อมูลประวัติคลื่นสมองทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getBrainwaveData(int userId) async {
    return SupabaseService.getBrainwaveData(userId);
  }

  /// บันทึกประวัติการทำกิจกรรมหรือเล่นเกม
  static Future<Map<String, dynamic>> saveActivity({
    required int userId,
    required String activityType,
    required String activityName,
    required int score,
    required int durationMinutes,
  }) async {
    return SupabaseService.saveActivity(
      userId: userId,
      activityType: activityType,
      activityName: activityName,
      score: score,
      durationMinutes: durationMinutes,
    );
  }

  /// ดึงข้อมูลประวัติกิจกรรมทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getActivities(int userId) async {
    return SupabaseService.getActivities(userId);
  }

  /// ส่งข้อความแชทและจัดเก็บลงในฐานข้อมูล
  static Future<Map<String, dynamic>> sendChatMessage({
    required int userId,
    required String message,
    bool isBot = false,
  }) async {
    return SupabaseService.sendChatMessage(
      userId: userId,
      message: message,
      isBot: isBot,
    );
  }

  /// ดึงข้อมูลประวัติการสนทนาทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getChatHistory(int userId) async {
    return SupabaseService.getChatHistory(userId);
  }

  /// ส่งข้อความหาบอทปัญญาประดิษฐ์ (ChatGPT) พร้อมดึง RAG Context และบันทึกคำตอบอัตโนมัติ
  static Future<Map<String, dynamic>> sendChatGPTMessage({
    required int userId,
    required String message,
    List<Map<String, dynamic>>? chatHistory,
  }) async {

    final userMessageResult = await SupabaseService.sendChatMessage(
      userId: userId,
      message: message,
      isBot: false,
    );

    final int? userMessageId = userMessageResult['success'] == true
        ? userMessageResult['message_id'] as int?
        : null;

    ChatGPTService.setUserId(userId);

    final result = await ChatGPTService.sendMessageWithRAG(
      message: message,
      chatHistory: chatHistory,
      userId: userId,
      userMessageId: userMessageId,
    );

    if (result['success'] == true && result['bot_response'] != null) {

      await SupabaseService.sendChatMessage(
        userId: userId,
        message: result['bot_response'],
        isBot: true,
      );
    }

    return result;
  }

  /// ดึงการตั้งค่าแอปพลิเคชันของผู้ใช้
  static Future<Map<String, dynamic>> getSettings(int userId) async {
    return SupabaseService.getSettings(userId);
  }

  /// ปรับปรุงบันทึกการตั้งค่าภายในแอป
  static Future<Map<String, dynamic>> updateSettings({
    required int userId,
    required bool pushNotifications,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    return SupabaseService.updateSettings(
      userId: userId,
      dailyReminder: pushNotifications,
      stressAlert: vibrationEnabled,
    );
  }

  /// ดึงรายการกำหนดการแจ้งเตือนทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getSchedules(int userId) async {
    return SupabaseService.getSchedules(userId);
  }

  /// เพิ่มกำหนดการแจ้งเตือนใหม่ในปฏิทิน
  static Future<Map<String, dynamic>> addSchedule({
    required int userId,
    required String title,
    required String description,
    required String time,
    String iconName = 'event',
    String color = 'purple',
  }) async {
    return SupabaseService.addSchedule(
      userId: userId,
      title: title,
      description: description,
      time: time,
      iconName: iconName,
      color: color,
    );
  }

  /// ลบกำหนดการแจ้งเตือน
  static Future<Map<String, dynamic>> deleteSchedule({
    required int scheduleId,
    required int userId,
  }) async {
    return SupabaseService.deleteSchedule(
      scheduleId: scheduleId,
      userId: userId,
    );
  }



  /// บันทึกเซสชันอารมณ์และคลื่นสมองเฉลี่ยที่รวบรวมได้
  static Future<Map<String, dynamic>> saveEmotionSession({
    required int userId,
    required String targetEmotion,
    required String activityType,
    String? sessionName,
    int durationSeconds = 0,
    int samplesCollected = 0,
    double avgAlpha = 0,
    double avgBeta = 0,
    double avgTheta = 0,
    double avgDelta = 0,
    double avgGamma = 0,
    int? selfReportValence,
    int? selfReportArousal,
    String? notes,
    bool isCompleted = false,
  }) async {
    return SupabaseService.saveEmotionSession(
      userId: userId,
      targetEmotion: targetEmotion,
      activityType: activityType,
      sessionName: sessionName,
      durationSeconds: durationSeconds,
      samplesCollected: samplesCollected,
      avgAlpha: avgAlpha,
      avgBeta: avgBeta,
      avgTheta: avgTheta,
      avgDelta: avgDelta,
      avgGamma: avgGamma,
      selfReportValence: selfReportValence,
      selfReportArousal: selfReportArousal,
      notes: notes,
      isCompleted: isCompleted,
    );
  }

  /// ดึงข้อมูลเซสชันอารมณ์และคลื่นสมองทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getEmotionSessions(int userId, {int limit = 20}) async {
    return SupabaseService.getEmotionSessions(userId, limit: limit);
  }


  /// ดึงข้อมูลรายชื่อผู้ติดต่อฉุกเฉินทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getEmergencyContacts(int userId) async {
    return SupabaseService.getEmergencyContacts(userId);
  }

  /// เพิ่มผู้ติดต่อฉุกเฉินใหม่
  static Future<Map<String, dynamic>> addEmergencyContact({
    required int userId,
    required String contactName,
    required String phoneNumber,
    String? relationship,
    String? email,
    bool isPrimary = false,
    bool notifyOnEmergency = true,
    bool notifyOnHighStress = false,
    String? notes,
  }) async {
    return SupabaseService.addEmergencyContact(
      userId: userId,
      contactName: contactName,
      phoneNumber: phoneNumber,
      relationship: relationship,
      email: email,
      isPrimary: isPrimary,
      notifyOnEmergency: notifyOnEmergency,
      notifyOnHighStress: notifyOnHighStress,
      notes: notes,
    );
  }

  /// อัปเดตข้อมูลผู้ติดต่อฉุกเฉินเดิม
  static Future<Map<String, dynamic>> updateEmergencyContact({
    required int contactId,
    String? contactName,
    String? phoneNumber,
    String? relationship,
    String? email,
    bool? isPrimary,
    bool? notifyOnEmergency,
    bool? notifyOnHighStress,
    String? notes,
  }) async {
    return SupabaseService.updateEmergencyContact(
      contactId: contactId,
      contactName: contactName,
      phoneNumber: phoneNumber,
      relationship: relationship,
      email: email,
      isPrimary: isPrimary,
      notifyOnEmergency: notifyOnEmergency,
      notifyOnHighStress: notifyOnHighStress,
      notes: notes,
    );
  }

  /// ลบผู้ติดต่อฉุกเฉิน
  static Future<Map<String, dynamic>> deleteEmergencyContact(int contactId) async {
    return SupabaseService.deleteEmergencyContact(contactId);
  }

  /// ดึงข้อมูลระเบียนคนไข้/ประวัติผู้สูงอายุ
  static Future<Map<String, dynamic>> getElderlyProfile(int userId) async {
    return SupabaseService.getElderlyProfile(userId);
  }

  /// บันทึกหรือสร้างระเบียนประวัติผู้สูงอายุ/คนไข้ใหม่
  static Future<Map<String, dynamic>> saveElderlyProfile({
    required int userId,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
    double? heightCm,
    double? weightKg,
    List<String>? medicalConditions,
    List<String>? allergies,
    List<String>? currentMedications,
    String? mobilityStatus,
    String? cognitiveStatus,
    String? doctorName,
    String? doctorPhone,
    String? hospitalName,
    String? insuranceInfo,
    String? specialNeeds,
  }) async {
    return SupabaseService.saveElderlyProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodType: bloodType,
      heightCm: heightCm,
      weightKg: weightKg,
      medicalConditions: medicalConditions,
      allergies: allergies,
      currentMedications: currentMedications,
      mobilityStatus: mobilityStatus,
      cognitiveStatus: cognitiveStatus,
      doctorName: doctorName,
      doctorPhone: doctorPhone,
      hospitalName: hospitalName,
      insuranceInfo: insuranceInfo,
      specialNeeds: specialNeeds,
    );
  }

  /// บันทึกข้อมูลและเมทาดาต้าของไฟล์เสียงพูด
  static Future<Map<String, dynamic>> saveVoiceMetadata({
    int? messageId,
    String? detectedLanguage,
    double? durationSeconds,
    String? audioFileUrl,
    String? contentText,
    String senderType = 'user',
    double? sentimentScore,
    double? stressIndex,
    double? pitchAvg,
    double? volumeAvg,
    double? speechRate,
  }) async {
    return SupabaseService.saveVoiceMetadata(
      messageId: messageId,
      detectedLanguage: detectedLanguage,
      durationSeconds: durationSeconds,
      audioFileUrl: audioFileUrl,
      contentText: contentText,
      senderType: senderType,
      sentimentScore: sentimentScore,
      stressIndex: stressIndex,
      pitchAvg: pitchAvg,
      volumeAvg: volumeAvg,
      speechRate: speechRate,
    );
  }

  /// ดึงข้อมูลเมทาดาต้าเสียงตามรหัสข้อความ
  static Future<Map<String, dynamic>> getVoiceMetadata(int messageId) async {
    return SupabaseService.getVoiceMetadata(messageId);
  }

  /// ลงทะเบียนและเชื่อมโยงอุปกรณ์ EEG แถบคาดศีรษะเครื่องใหม่กับผู้ใช้
  static Future<Map<String, dynamic>> registerEEGDevice({
    required int userId,
    required String deviceName,
    String? modelName,
    String? serialNumber,
    String? macAddress,
    String? firmwareVersion,
  }) async {
    return SupabaseService.registerEEGDevice(
      userId: userId,
      deviceName: deviceName,
      modelName: modelName,
      serialNumber: serialNumber,
      macAddress: macAddress,
      firmwareVersion: firmwareVersion,
    );
  }

  /// ดึงข้อมูลแถบตรวจคลื่นสมองทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getEEGDevices(int userId) async {
    return SupabaseService.getEEGDevices(userId);
  }

  /// อัปเดตสถานะและระดับแบตเตอรี่ของฮาร์ดแวร์แถบวัดคลื่นสมอง
  static Future<Map<String, dynamic>> updateDeviceStatus({
    required int deviceId,
    String? status,
    int? batteryLevel,
    bool updateLastConnected = false,
  }) async {
    return SupabaseService.updateDeviceStatus(
      deviceId: deviceId,
      status: status,
      batteryLevel: batteryLevel,
      updateLastConnected: updateLastConnected,
    );
  }

  /// เริ่มต้นเซสชันบันทึกข้อมูลคลื่นสมอง EEG ตัวใหม่
  static Future<Map<String, dynamic>> startEEGSession({
    required int userId,
    int? deviceId,
    String sessionType = 'general',
    String? notes,
  }) async {
    return SupabaseService.startEEGSession(
      userId: userId,
      deviceId: deviceId,
      sessionType: sessionType,
      notes: notes,
    );
  }

  /// สิ้นสุดเซสชันการบันทึกคลื่นสมองพร้อมคำนวณสรุปผลและระดับความเสถียรของสัญญาณ
  static Future<Map<String, dynamic>> endEEGSession({
    required int sessionId,
    double? avgAttentionScore,
    double? avgRelaxationScore,
    double? avgStressScore,
    String? dataQualityGrade,
  }) async {
    return SupabaseService.endEEGSession(
      sessionId: sessionId,
      avgAttentionScore: avgAttentionScore,
      avgRelaxationScore: avgRelaxationScore,
      avgStressScore: avgStressScore,
      dataQualityGrade: dataQualityGrade,
    );
  }

  /// ดึงประวัติรายงานคลื่นสมองทั้งหมดของผู้ใช้
  static Future<Map<String, dynamic>> getEEGSessions(int userId, {int limit = 20}) async {
    return SupabaseService.getEEGSessions(userId, limit: limit);
  }

  /// เริ่มต้นเซสชันเปิดสนทนาแชทใหม่
  static Future<Map<String, dynamic>> startConversation(int userId) async {
    return SupabaseService.startConversation(userId);
  }

  /// สิ้นสุดเซสชันแชทและเขียนบันทึกสรุปประเด็น (Topic Summary)
  static Future<Map<String, dynamic>> endConversation({
    required int conversationId,
    String? topicSummary,
    double? sentimentAvg,
  }) async {
    return SupabaseService.endConversation(
      conversationId: conversationId,
      topicSummary: topicSummary,
      sentimentAvg: sentimentAvg,
    );
  }

  /// ดึงเซสชันสนทนาแชทที่ยังเปิดทำงานอยู่ในปัจจุบัน
  static Future<Map<String, dynamic>> getActiveConversation(int userId) async {
    return SupabaseService.getActiveConversation(userId);
  }

  /// บันทึกอารมณ์รายวันพร้อมเหตุการณ์กระตุ้น
  static Future<Map<String, dynamic>> saveEmotionLog({
    required int userId,
    required String emotionType,
    String? triggerEvent,
    int intensity = 5,
  }) async {
    return SupabaseService.saveEmotionLog(
      userId: userId,
      emotionType: emotionType,
      triggerEvent: triggerEvent,
      intensity: intensity,
    );
  }

  /// ดึงข้อมูลบันทึกประวัติอารมณ์ทั้งหมด
  static Future<Map<String, dynamic>> getEmotionLogs(int userId, {int limit = 50}) async {
    return SupabaseService.getEmotionLogs(userId, limit: limit);
  }

  /// ดึงบันทึกประวัติอารมณ์แยกตามประเภทของอารมณ์
  static Future<Map<String, dynamic>> getEmotionLogsByType(int userId, String emotionType) async {
    return SupabaseService.getEmotionLogsByType(userId, emotionType);
  }

  /// ลบประวัติบันทึกอารมณ์
  static Future<Map<String, dynamic>> deleteEmotionLog(int logId) async {
    return SupabaseService.deleteEmotionLog(logId);
  }

  /// ดึงภาพรวมสถิติอารมณ์เฉลี่ยของผู้ใช้
  static Future<Map<String, dynamic>> getEmotionSummary(int userId) async {
    return SupabaseService.getEmotionSummary(userId);
  }

  /// บันทึกสรุปรายงานผลวิเคราะห์ qEEG
  static Future<Map<String, dynamic>> saveEegAssessmentReport({
    required int userId,
    required Map<String, dynamic> reportData,
  }) async {
    return SupabaseService.saveEegAssessmentReport(
      userId: userId,
      reportData: reportData,
    );
  }

  /// ดึงรายการประวัติรายงานสรุป qEEG ทั้งหมด
  static Future<Map<String, dynamic>> getEegAssessmentReports(
    int userId, {
    int limit = 50,
  }) async {
    return SupabaseService.getEegAssessmentReports(userId, limit: limit);
  }

  /// ดึงรายละเอียดรายงานสรุป qEEG เฉพาะชิ้นตามรหัสรายงาน
  static Future<Map<String, dynamic>> getEegAssessmentReport(int reportId) async {
    return SupabaseService.getEegAssessmentReport(reportId);
  }
}
