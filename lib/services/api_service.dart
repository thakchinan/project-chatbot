import 'dart:io';
import 'supabase_service.dart';
import 'chatgpt_service.dart';

class ApiService {

  static Future<Map<String, dynamic>> login(String username, String password) async {
    return SupabaseService.login(username, password);
  }

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

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    return SupabaseService.getProfile(userId);
  }

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

  static Future<Map<String, dynamic>> uploadAvatar({
    required int userId,
    required File imageFile,
  }) async {
    return SupabaseService.uploadAvatar(
      userId: userId,
      imageFile: imageFile,
    );
  }

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

  static Future<Map<String, dynamic>> getTestResults(int userId) async {
    return SupabaseService.getTestResults(userId);
  }

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

  static Future<Map<String, dynamic>> getBrainwaveData(int userId) async {
    return SupabaseService.getBrainwaveData(userId);
  }

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

  static Future<Map<String, dynamic>> getActivities(int userId) async {
    return SupabaseService.getActivities(userId);
  }

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

  static Future<Map<String, dynamic>> getChatHistory(int userId) async {
    return SupabaseService.getChatHistory(userId);
  }

  static Future<Map<String, dynamic>> sendChatGPTMessage({
    required int userId,
    required String message,
    List<Map<String, dynamic>>? chatHistory,
  }) async {

    await SupabaseService.sendChatMessage(
      userId: userId,
      message: message,
      isBot: false,
    );

    ChatGPTService.setUserId(userId);

    final result = await ChatGPTService.sendMessageWithRAG(
      message: message,
      chatHistory: chatHistory,
      userId: userId,
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

  static Future<Map<String, dynamic>> getSettings(int userId) async {
    return SupabaseService.getSettings(userId);
  }

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

  static Future<Map<String, dynamic>> getSchedules(int userId) async {
    return SupabaseService.getSchedules(userId);
  }

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

  static Future<Map<String, dynamic>> deleteSchedule({
    required int scheduleId,
    required int userId,
  }) async {
    return SupabaseService.deleteSchedule(
      scheduleId: scheduleId,
      userId: userId,
    );
  }

  static Future<Map<String, dynamic>> saveMuseBrainwave({
    required int userId,
    required double alphaWave,
    required double betaWave,
    required double thetaWave,
    required double deltaWave,
    required double gammaWave,
    double attentionScore = 0,
    double meditationScore = 0,
    String deviceName = 'Muse 2',
    String? emotionLabel,
    String? activityType,
    String? sessionPhase,
  }) async {
    return SupabaseService.saveBrainwaveData(
      userId: userId,
      alphaWave: alphaWave,
      betaWave: betaWave,
      thetaWave: thetaWave,
      deltaWave: deltaWave,
      gammaWave: gammaWave,
      attentionScore: attentionScore,
      meditationScore: meditationScore,
      deviceName: deviceName,
      emotionLabel: emotionLabel,
      activityType: activityType,
      sessionPhase: sessionPhase,
    );
  }

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

  static Future<Map<String, dynamic>> getEmotionSessions(int userId, {int limit = 20}) async {
    return SupabaseService.getEmotionSessions(userId, limit: limit);
  }


  static Future<Map<String, dynamic>> getEmergencyContacts(int userId) async {
    return SupabaseService.getEmergencyContacts(userId);
  }

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

  static Future<Map<String, dynamic>> deleteEmergencyContact(int contactId) async {
    return SupabaseService.deleteEmergencyContact(contactId);
  }

  static Future<Map<String, dynamic>> getElderlyProfile(int userId) async {
    return SupabaseService.getElderlyProfile(userId);
  }

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

  static Future<Map<String, dynamic>> getVoiceMetadata(int messageId) async {
    return SupabaseService.getVoiceMetadata(messageId);
  }

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

  static Future<Map<String, dynamic>> getEEGDevices(int userId) async {
    return SupabaseService.getEEGDevices(userId);
  }

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

  static Future<Map<String, dynamic>> getEEGSessions(int userId, {int limit = 20}) async {
    return SupabaseService.getEEGSessions(userId, limit: limit);
  }

  static Future<Map<String, dynamic>> startConversation(int userId) async {
    return SupabaseService.startConversation(userId);
  }

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

  static Future<Map<String, dynamic>> getActiveConversation(int userId) async {
    return SupabaseService.getActiveConversation(userId);
  }

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

  static Future<Map<String, dynamic>> getEmotionLogs(int userId, {int limit = 50}) async {
    return SupabaseService.getEmotionLogs(userId, limit: limit);
  }

  static Future<Map<String, dynamic>> getEmotionLogsByType(int userId, String emotionType) async {
    return SupabaseService.getEmotionLogsByType(userId, emotionType);
  }

  static Future<Map<String, dynamic>> deleteEmotionLog(int logId) async {
    return SupabaseService.deleteEmotionLog(logId);
  }

  static Future<Map<String, dynamic>> getEmotionSummary(int userId) async {
    return SupabaseService.getEmotionSummary(userId);
  }
}
