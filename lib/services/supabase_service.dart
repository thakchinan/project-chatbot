import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static const String supabaseUrl = 'https://ifsvthnxydchqnigvmuw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlmc3Z0aG54eWRjaHFuaWd2bXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkwNjQ2NDIsImV4cCI6MjA4NDY0MDY0Mn0.HWVTbQ7SwY93EZqdKCljnPCT8rCliJAMMxI1QC5JsR0';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase client not initialized. Call SupabaseService.initialize() first.');
    }
    return _client!;
  }

  static bool get isInitialized => _client != null;

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {

      final response = await client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        return {'success': false, 'message': 'ไม่พบชื่อผู้ใช้'};
      }

      if (response['password'] != password) {
        return {'success': false, 'message': 'รหัสผ่านไม่ถูกต้อง'};
      }

      return {
        'success': true,
        'message': 'เข้าสู่ระบบสำเร็จ',
        'user': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? fullName,
    String? phone,
    String? email,
    String? birthDate,
  }) async {
    try {

      final existing = await client
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'ชื่อผู้ใช้นี้ถูกใช้แล้ว'};
      }

      final response = await client
          .from('users')
          .insert({
            'username': username,
            'password': password,
            'full_name': fullName,
            'phone': phone,
            'email': email,
            'birth_date': birthDate,
          })
          .select()
          .single();

      await client
          .from('user_settings')
          .insert({
            'user_id': response['id'],
          });

      return {
        'success': true,
        'message': 'สมัครสมาชิกสำเร็จ',
        'user': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return {
        'success': true,
        'profile': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดโปรไฟล์ได้'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? fullName,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? birthDate,
    String? avatarUrl,
    String? role,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (phone != null) updateData['phone'] = phone;
      if (email != null) updateData['email'] = email;
      if (birthDate != null) updateData['birth_date'] = birthDate;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (role != null) updateData['role'] = role;

      await client
          .from('users')
          .update(updateData)
          .eq('id', userId);

      return {'success': true, 'message': 'อัปเดตโปรไฟล์สำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปเดตโปรไฟล์ได้'};
    }
  }

  static Future<Map<String, dynamic>> uploadAvatar({
    required int userId,
    required File imageFile,
  }) async {
    try {

      final fileExt = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'user_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'profiles/$fileName';

      const mimeTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
      };
      final contentType = mimeTypes[fileExt] ?? 'image/jpeg';

      final fileBytes = await imageFile.readAsBytes();

      await client.storage.from('avatars').uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      final publicUrl = client.storage.from('avatars').getPublicUrl(filePath);

      await client
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      debugPrint('Avatar uploaded successfully: $publicUrl');

      return {
        'success': true,
        'message': 'อัปโหลดรูปโปรไฟล์สำเร็จ',
        'avatar_url': publicUrl,
      };
    } catch (e) {
      debugPrint('Upload avatar error: $e');
      return {'success': false, 'message': 'ไม่สามารถอัปโหลดรูปได้: $e'};
    }
  }

  static Future<void> deleteOldAvatar(String? oldAvatarUrl) async {
    if (oldAvatarUrl == null || oldAvatarUrl.isEmpty) return;
    try {

      final uri = Uri.parse(oldAvatarUrl);
      final pathSegments = uri.pathSegments;

      final avatarIdx = pathSegments.indexOf('avatars');
      if (avatarIdx >= 0 && avatarIdx < pathSegments.length - 1) {
        final storagePath = pathSegments.sublist(avatarIdx + 1).join('/');
        await client.storage.from('avatars').remove([storagePath]);
        debugPrint('Deleted old avatar: $storagePath');
      }
    } catch (e) {
      debugPrint('Delete old avatar error: $e');
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required int userId,
    String? currentPassword,
    required String newPassword,
  }) async {
    try {

      if (currentPassword != null) {
        final user = await client
            .from('users')
            .select('password')
            .eq('id', userId)
            .single();

        if (user['password'] != currentPassword) {
          return {'success': false, 'message': 'รหัสผ่านปัจจุบันไม่ถูกต้อง'};
        }
      }

      await client
          .from('users')
          .update({'password': newPassword})
          .eq('id', userId);

      return {'success': true, 'message': 'เปลี่ยนรหัสผ่านสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเปลี่ยนรหัสผ่านได้'};
    }
  }

  static Future<Map<String, dynamic>> saveTestResult({
    required int userId,
    required int stressScore,
    required int depressionScore,
    required String stressLevel,
  }) async {
    try {
      final response = await client
          .from('test_results')
          .insert({
            'user_id': userId,
            'stress_score': stressScore,
            'depression_score': depressionScore,
            'stress_level': stressLevel,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'บันทึกผลทดสอบสำเร็จ',
        'id': response['id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถบันทึกผลทดสอบได้'};
    }
  }

  static Future<Map<String, dynamic>> getTestResults(int userId) async {
    try {
      final response = await client
          .from('test_results')
          .select()
          .eq('user_id', userId)
          .order('test_date', ascending: false);

      return {
        'success': true,
        'results': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดผลทดสอบได้'};
    }
  }

  static Future<Map<String, dynamic>> saveBrainwaveData({
    required int userId,
    required double alphaWave,
    required double betaWave,
    required double thetaWave,
    required double deltaWave,
    double gammaWave = 0,
    double attentionScore = 0,
    double meditationScore = 0,
    String deviceName = 'Muse S',
  }) async {
    try {
      final response = await client
          .from('brainwave_data')
          .insert({
            'user_id': userId,
            'alpha_wave': alphaWave,
            'beta_wave': betaWave,
            'theta_wave': thetaWave,
            'delta_wave': deltaWave,
            'gamma_wave': gammaWave,
            'attention_score': attentionScore,
            'meditation_score': meditationScore,
            'device_name': deviceName,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'บันทึกข้อมูลคลื่นสมองสำเร็จ',
        'id': response['id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถบันทึกข้อมูลคลื่นสมองได้'};
    }
  }

  static Future<Map<String, dynamic>> getBrainwaveData(int userId) async {
    try {
      final response = await client
          .from('brainwave_data')
          .select()
          .eq('user_id', userId)
          .order('recorded_at', ascending: false);

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดข้อมูลคลื่นสมองได้'};
    }
  }

  static Future<Map<String, dynamic>> saveActivity({
    required int userId,
    required String activityType,
    required String activityName,
    required int score,
    required int durationMinutes,
  }) async {
    try {
      final response = await client
          .from('activities')
          .insert({
            'user_id': userId,
            'activity_type': activityType,
            'activity_name': activityName,
            'score': score,
            'duration_minutes': durationMinutes,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'บันทึกกิจกรรมสำเร็จ',
        'id': response['id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถบันทึกกิจกรรมได้'};
    }
  }

  static Future<Map<String, dynamic>> getActivities(int userId) async {
    try {
      final response = await client
          .from('activities')
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false);

      return {
        'success': true,
        'activities': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดกิจกรรมได้'};
    }
  }

  static Future<Map<String, dynamic>> getSchedules(int userId) async {
    try {
      final response = await client
          .from('schedules')
          .select()
          .eq('user_id', userId)
          .order('time', ascending: true);

      return {
        'success': true,
        'schedules': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดตารางเวลาได้'};
    }
  }

  static Future<Map<String, dynamic>> addSchedule({
    required int userId,
    required String title,
    required String description,
    required String time,
    String iconName = 'event',
    String color = 'purple',
  }) async {
    try {
      final response = await client
          .from('schedules')
          .insert({
            'user_id': userId,
            'title': title,
            'description': description,
            'time': time,
            'icon_name': iconName,
            'color': color,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'เพิ่มตารางเวลาสำเร็จ',
        'id': response['id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเพิ่มตารางเวลาได้'};
    }
  }

  static Future<Map<String, dynamic>> updateScheduleCompletion({
    required int scheduleId,
    required bool isCompleted,
  }) async {
    try {
      await client
          .from('schedules')
          .update({'is_completed': isCompleted})
          .eq('id', scheduleId);

      return {'success': true, 'message': 'อัปเดตสถานะสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปเดตสถานะได้'};
    }
  }

  static Future<Map<String, dynamic>> deleteSchedule({
    required int scheduleId,
    required int userId,
  }) async {
    try {
      await client
          .from('schedules')
          .delete()
          .eq('id', scheduleId)
          .eq('user_id', userId);

      return {'success': true, 'message': 'ลบตารางเวลาสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถลบตารางเวลาได้'};
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required int userId,
    required String message,
    bool isBot = false,
  }) async {
    try {
      final response = await client
          .from('chat_messages')
          .insert({
            'user_id': userId,
            'message': message,
            'is_bot': isBot,
          })
          .select()
          .single();

      return {
        'success': true,
        'message_id': response['id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถส่งข้อความได้'};
    }
  }

  static Future<Map<String, dynamic>> getChatHistory(int userId) async {
    try {
      final response = await client
          .from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: true);

      return {
        'success': true,
        'messages': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดประวัติแชทได้'};
    }
  }

  static Future<Map<String, dynamic>> getSettings(int userId) async {
    try {
      final response = await client
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {

        final newSettings = await client
            .from('user_settings')
            .insert({'user_id': userId})
            .select()
            .single();

        return {'success': true, 'settings': newSettings};
      }

      return {'success': true, 'settings': response};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดการตั้งค่าได้'};
    }
  }

  static Future<Map<String, dynamic>> updateSettings({
    required int userId,
    bool? dailyReminder,
    bool? weeklyReport,
    bool? stressAlert,
    String? reminderTime,
    bool? darkMode,
    String? language,
    String? notificationPrefer,
    String? sensitivityLevel,
    String? stressThreshold,
    int? criticalFFT,
    String? brainMode,
    int? fontSize,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (dailyReminder != null) updateData['daily_reminder'] = dailyReminder;
      if (weeklyReport != null) updateData['weekly_report'] = weeklyReport;
      if (stressAlert != null) updateData['stress_alert'] = stressAlert;
      if (reminderTime != null) updateData['reminder_time'] = reminderTime;
      if (darkMode != null) updateData['dark_mode'] = darkMode;
      if (language != null) updateData['language'] = language;
      if (notificationPrefer != null) updateData['notification_prefer'] = notificationPrefer;
      if (sensitivityLevel != null) updateData['sensitivity_level'] = sensitivityLevel;
      if (stressThreshold != null) updateData['stress_threshold'] = stressThreshold;
      if (criticalFFT != null) updateData['critical_fft'] = criticalFFT;
      if (brainMode != null) updateData['brain_mode'] = brainMode;
      if (fontSize != null) updateData['font_size'] = fontSize;

      await client
          .from('user_settings')
          .update(updateData)
          .eq('user_id', userId);

      return {'success': true, 'message': 'อัปเดตการตั้งค่าสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปเดตการตั้งค่าได้'};
    }
  }

  static Future<Map<String, dynamic>> getEmergencyContacts(int userId) async {
    try {
      final response = await client
          .from('emergency_contacts')
          .select()
          .eq('user_id', userId)
          .order('is_primary', ascending: false);

      return {
        'success': true,
        'contacts': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดผู้ติดต่อฉุกเฉินได้'};
    }
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
    try {

      if (isPrimary) {
        await client
            .from('emergency_contacts')
            .update({'is_primary': false})
            .eq('user_id', userId);
      }

      final response = await client
          .from('emergency_contacts')
          .insert({
            'user_id': userId,
            'contact_name': contactName,
            'phone_number': phoneNumber,
            'relationship': relationship,
            'email': email,
            'is_primary': isPrimary,
            'notify_on_emergency': notifyOnEmergency,
            'notify_on_high_stress': notifyOnHighStress,
            'notes': notes,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'เพิ่มผู้ติดต่อฉุกเฉินสำเร็จ',
        'contact_id': response['contact_id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเพิ่มผู้ติดต่อฉุกเฉินได้: $e'};
    }
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
    try {
      final updateData = <String, dynamic>{};
      if (contactName != null) updateData['contact_name'] = contactName;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (relationship != null) updateData['relationship'] = relationship;
      if (email != null) updateData['email'] = email;
      if (isPrimary != null) updateData['is_primary'] = isPrimary;
      if (notifyOnEmergency != null) updateData['notify_on_emergency'] = notifyOnEmergency;
      if (notifyOnHighStress != null) updateData['notify_on_high_stress'] = notifyOnHighStress;
      if (notes != null) updateData['notes'] = notes;

      await client
          .from('emergency_contacts')
          .update(updateData)
          .eq('contact_id', contactId);

      return {'success': true, 'message': 'อัปเดตผู้ติดต่อฉุกเฉินสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปเดตผู้ติดต่อฉุกเฉินได้'};
    }
  }

  static Future<Map<String, dynamic>> deleteEmergencyContact(int contactId) async {
    try {
      await client
          .from('emergency_contacts')
          .delete()
          .eq('contact_id', contactId);

      return {'success': true, 'message': 'ลบผู้ติดต่อฉุกเฉินสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถลบผู้ติดต่อฉุกเฉินได้'};
    }
  }

  static Future<Map<String, dynamic>> getElderlyProfile(int userId) async {
    try {
      final response = await client
          .from('elderly_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return {
        'success': true,
        'profile': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดข้อมูลสุขภาพได้'};
    }
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
    try {
      final data = <String, dynamic>{
        'user_id': userId,
      };

      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (dateOfBirth != null) data['date_of_birth'] = dateOfBirth;
      if (gender != null) data['gender'] = gender;
      if (bloodType != null) data['blood_type'] = bloodType;
      if (heightCm != null) data['height_cm'] = heightCm;
      if (weightKg != null) data['weight_kg'] = weightKg;
      if (medicalConditions != null) data['medical_conditions'] = medicalConditions;
      if (allergies != null) data['allergies'] = allergies;
      if (currentMedications != null) data['current_medications'] = currentMedications;
      if (mobilityStatus != null) data['mobility_status'] = mobilityStatus;
      if (cognitiveStatus != null) data['cognitive_status'] = cognitiveStatus;
      if (doctorName != null) data['doctor_name'] = doctorName;
      if (doctorPhone != null) data['doctor_phone'] = doctorPhone;
      if (hospitalName != null) data['hospital_name'] = hospitalName;
      if (insuranceInfo != null) data['insurance_info'] = insuranceInfo;
      if (specialNeeds != null) data['special_needs'] = specialNeeds;

      await client
          .from('elderly_profiles')
          .upsert(data, onConflict: 'user_id');

      return {'success': true, 'message': 'บันทึกข้อมูลสุขภาพสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถบันทึกข้อมูลสุขภาพได้: $e'};
    }
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
    try {
      final response = await client
          .from('voice_metadata')
          .insert({
            'message_id': messageId,
            'detected_language': detectedLanguage ?? 'th',
            'duration_seconds': durationSeconds ?? 0,
            'audio_file_url': audioFileUrl,
            'content_text': contentText,
            'sender_type': senderType,
            'sentiment_score': sentimentScore ?? 0,
            'stress_index': stressIndex ?? 0,
            'pitch_avg': pitchAvg,
            'volume_avg': volumeAvg,
            'speech_rate': speechRate,
          })
          .select()
          .single();

      return {
        'success': true,
        'voice_id': response['voice_id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถบันทึกข้อมูลเสียงได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> getVoiceMetadata(int messageId) async {
    try {
      final response = await client
          .from('voice_metadata')
          .select()
          .eq('message_id', messageId)
          .maybeSingle();

      return {
        'success': true,
        'metadata': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดข้อมูลเสียงได้'};
    }
  }

  static Future<Map<String, dynamic>> registerEEGDevice({
    required int userId,
    required String deviceName,
    String? modelName,
    String? serialNumber,
    String? macAddress,
    String? firmwareVersion,
  }) async {
    try {
      final response = await client
          .from('eeg_devices')
          .insert({
            'user_id': userId,
            'device_name': deviceName,
            'model_name': modelName,
            'serial_number': serialNumber,
            'mac_address': macAddress,
            'firmware_version': firmwareVersion,
            'status': 'active',
          })
          .select()
          .single();

      return {
        'success': true,
        'device_id': response['device_id'],
        'message': 'ลงทะเบียนอุปกรณ์สำเร็จ',
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถลงทะเบียนอุปกรณ์ได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> getEEGDevices(int userId) async {
    try {
      final response = await client
          .from('eeg_devices')
          .select()
          .eq('user_id', userId)
          .order('last_connected_at', ascending: false);

      return {
        'success': true,
        'devices': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดรายการอุปกรณ์ได้'};
    }
  }

  static Future<Map<String, dynamic>> updateDeviceStatus({
    required int deviceId,
    String? status,
    int? batteryLevel,
    bool updateLastConnected = false,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (status != null) updateData['status'] = status;
      if (batteryLevel != null) updateData['battery_level'] = batteryLevel;
      if (updateLastConnected) updateData['last_connected_at'] = DateTime.now().toIso8601String();

      await client
          .from('eeg_devices')
          .update(updateData)
          .eq('device_id', deviceId);

      return {'success': true, 'message': 'อัปเดตสถานะอุปกรณ์สำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปเดตสถานะอุปกรณ์ได้'};
    }
  }

  static Future<Map<String, dynamic>> startEEGSession({
    required int userId,
    int? deviceId,
    String sessionType = 'general',
    String? notes,
  }) async {
    try {
      final response = await client
          .from('eeg_sessions')
          .insert({
            'user_id': userId,
            'device_id': deviceId,
            'session_type': sessionType,
            'notes': notes,
          })
          .select()
          .single();

      return {
        'success': true,
        'session_id': response['session_id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเริ่ม session ได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> endEEGSession({
    required int sessionId,
    double? avgAttentionScore,
    double? avgRelaxationScore,
    double? avgStressScore,
    String? dataQualityGrade,
  }) async {
    try {
      final startedSession = await client
          .from('eeg_sessions')
          .select('started_at')
          .eq('session_id', sessionId)
          .single();

      final startedAt = DateTime.parse(startedSession['started_at']);
      final endedAt = DateTime.now();
      final durationSeconds = endedAt.difference(startedAt).inSeconds;

      await client
          .from('eeg_sessions')
          .update({
            'ended_at': endedAt.toIso8601String(),
            'duration_seconds': durationSeconds,
            'avg_attention_score': avgAttentionScore,
            'avg_relaxation_score': avgRelaxationScore,
            'avg_stress_score': avgStressScore,
            'data_quality_grade': dataQualityGrade,
          })
          .eq('session_id', sessionId);

      return {
        'success': true,
        'duration_seconds': durationSeconds,
        'message': 'จบ session สำเร็จ',
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถจบ session ได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> getEEGSessions(int userId, {int limit = 20}) async {
    try {
      final response = await client
          .from('eeg_sessions')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(limit);

      return {
        'success': true,
        'sessions': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลด sessions ได้'};
    }
  }

  static Future<Map<String, dynamic>> startConversation(int userId) async {
    try {
      final response = await client
          .from('conversations')
          .insert({
            'user_id': userId,
            'is_active': true,
          })
          .select()
          .single();

      return {
        'success': true,
        'conversation_id': response['conversation_id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถเริ่มการสนทนาได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> endConversation({
    required int conversationId,
    String? topicSummary,
    double? sentimentAvg,
  }) async {
    try {
      await client
          .from('conversations')
          .update({
            'ended_at': DateTime.now().toIso8601String(),
            'is_active': false,
            'topic_summary': topicSummary,
            'sentiment_avg': sentimentAvg,
          })
          .eq('conversation_id', conversationId);

      return {'success': true, 'message': 'จบการสนทนาสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถจบการสนทนาได้'};
    }
  }

  static Future<Map<String, dynamic>> getActiveConversation(int userId) async {
    try {
      final response = await client
          .from('conversations')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return {
        'success': true,
        'conversation': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดการสนทนาได้'};
    }
  }

  static Future<Map<String, dynamic>> saveEmotionLog({
    required int userId,
    required String emotionType,
    String? triggerEvent,
    int intensity = 5,
  }) async {
    try {
      final response = await client
          .from('emotion_logs')
          .insert({
            'user_id': userId,
            'emotion_type': emotionType,
            'trigger_event': triggerEvent,
            'intensity': intensity,
          })
          .select()
          .single();

      return {
        'success': true,
        'log_id': response['log_id'],
        'message': 'บันทึกอารมณ์สำเร็จ',
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถบันทึกอารมณ์ได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> getEmotionLogs(int userId, {int limit = 50}) async {
    try {
      final response = await client
          .from('emotion_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return {
        'success': true,
        'emotion_logs': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดบันทึกอารมณ์ได้'};
    }
  }

  static Future<Map<String, dynamic>> getEmotionLogsByType(int userId, String emotionType) async {
    try {
      final response = await client
          .from('emotion_logs')
          .select()
          .eq('user_id', userId)
          .eq('emotion_type', emotionType)
          .order('created_at', ascending: false);

      return {
        'success': true,
        'emotion_logs': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดบันทึกอารมณ์ได้'};
    }
  }

  static Future<Map<String, dynamic>> deleteEmotionLog(int logId) async {
    try {
      await client
          .from('emotion_logs')
          .delete()
          .eq('log_id', logId);

      return {'success': true, 'message': 'ลบบันทึกอารมณ์สำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถลบบันทึกอารมณ์ได้'};
    }
  }

  static Future<Map<String, dynamic>> getEmotionSummary(int userId) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

      final response = await client
          .from('emotion_logs')
          .select()
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: false);

      final Map<String, int> emotionCounts = {};
      double totalIntensity = 0;

      for (final log in response) {
        final type = log['emotion_type'] as String;
        emotionCounts[type] = (emotionCounts[type] ?? 0) + 1;
        totalIntensity += (log['intensity'] ?? 5);
      }

      return {
        'success': true,
        'total_logs': response.length,
        'emotion_counts': emotionCounts,
        'avg_intensity': response.isNotEmpty ? totalIntensity / response.length : 0,
        'logs': response,
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถโหลดสรุปอารมณ์ได้'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount(int userId) async {
    try {

      await client.from('user_settings').delete().eq('user_id', userId);

      await client.from('emergency_contacts').delete().eq('user_id', userId);

      await client.from('activities').delete().eq('user_id', userId);

      await client.from('schedules').delete().eq('user_id', userId);

      final chatMessages = await client
          .from('chat_messages')
          .select('id')
          .eq('user_id', userId);
      for (final msg in chatMessages) {
        await client.from('voice_metadata').delete().eq('message_id', msg['id']);
      }

      await client.from('chat_messages').delete().eq('user_id', userId);

      await client.from('brainwave_data').delete().eq('user_id', userId);

      await client.from('test_results').delete().eq('user_id', userId);

      try {
        await client.from('eeg_sessions').delete().eq('user_id', userId);
      } catch (_) {}

      try {
        await client.from('eeg_devices').delete().eq('user_id', userId);
      } catch (_) {}

      try {
        await client.from('emotion_logs').delete().eq('user_id', userId);
      } catch (_) {}

      try {
        await client.from('conversations').delete().eq('user_id', userId);
      } catch (_) {}

      try {
        await client.from('elderly_profiles').delete().eq('user_id', userId);
      } catch (_) {}

      await client.from('users').delete().eq('id', userId);

      return {'success': true, 'message': 'ลบบัญชีสำเร็จ'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถลบบัญชีได้: $e'};
    }
  }
}
