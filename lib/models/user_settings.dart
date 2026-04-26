
class UserSettings {
  final int? id;
  final int userId;
  final String notificationPrefer;
  final String sensitivityLevel;
  final String stressThreshold;
  final int criticalFFT;
  final String brainMode;
  final String language;
  final bool darkMode;
  final int fontSize;
  final bool dailyReminder;
  final bool weeklyReport;
  final bool stressAlert;
  final String? reminderTime;
  final DateTime? updatedAt;

  UserSettings({
    this.id,
    required this.userId,
    this.notificationPrefer = 'all',
    this.sensitivityLevel = 'medium',
    this.stressThreshold = 'moderate',
    this.criticalFFT = 0,
    this.brainMode = 'normal',
    this.language = 'th',
    this.darkMode = false,
    this.fontSize = 16,
    this.dailyReminder = true,
    this.weeklyReport = true,
    this.stressAlert = true,
    this.reminderTime,
    this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'],
      userId: json['user_id'],
      notificationPrefer: json['notification_prefer'] ?? 'all',
      sensitivityLevel: json['sensitivity_level'] ?? 'medium',
      stressThreshold: json['stress_threshold'] ?? 'moderate',
      criticalFFT: json['critical_fft'] ?? 0,
      brainMode: json['brain_mode'] ?? 'normal',
      language: json['language'] ?? 'th',
      darkMode: json['dark_mode'] ?? false,
      fontSize: json['font_size'] ?? 16,
      dailyReminder: json['daily_reminder'] ?? true,
      weeklyReport: json['weekly_report'] ?? true,
      stressAlert: json['stress_alert'] ?? true,
      reminderTime: json['reminder_time'],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'notification_prefer': notificationPrefer,
      'sensitivity_level': sensitivityLevel,
      'stress_threshold': stressThreshold,
      'critical_fft': criticalFFT,
      'brain_mode': brainMode,
      'language': language,
      'dark_mode': darkMode,
      'font_size': fontSize,
      'daily_reminder': dailyReminder,
      'weekly_report': weeklyReport,
      'stress_alert': stressAlert,
      if (reminderTime != null) 'reminder_time': reminderTime,
    };
  }

  UserSettings toggleDarkMode() {
    return UserSettings(
      id: id,
      userId: userId,
      notificationPrefer: notificationPrefer,
      sensitivityLevel: sensitivityLevel,
      stressThreshold: stressThreshold,
      criticalFFT: criticalFFT,
      brainMode: brainMode,
      language: language,
      darkMode: !darkMode,
      fontSize: fontSize,
      dailyReminder: dailyReminder,
      weeklyReport: weeklyReport,
      stressAlert: stressAlert,
      reminderTime: reminderTime,
      updatedAt: updatedAt,
    );
  }

  UserSettings updateNotificationConfig({
    bool? dailyReminder,
    bool? weeklyReport,
    bool? stressAlert,
    String? notificationPrefer,
  }) {
    return UserSettings(
      id: id,
      userId: userId,
      notificationPrefer: notificationPrefer ?? this.notificationPrefer,
      sensitivityLevel: sensitivityLevel,
      stressThreshold: stressThreshold,
      criticalFFT: criticalFFT,
      brainMode: brainMode,
      language: language,
      darkMode: darkMode,
      fontSize: fontSize,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      weeklyReport: weeklyReport ?? this.weeklyReport,
      stressAlert: stressAlert ?? this.stressAlert,
      reminderTime: reminderTime,
      updatedAt: updatedAt,
    );
  }
}
