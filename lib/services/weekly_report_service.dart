import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'chatgpt_service.dart';
import 'supabase_service.dart';

class WeeklyReportService {
  static Future<Map<String, dynamic>> generate(int userId) async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final brainwaveResult = await ApiService.getBrainwaveData(userId);
    final testResult = await ApiService.getTestResults(userId);
    final emotionResult = await ApiService.getEmotionLogs(userId, limit: 80);
    final activityResult = await ApiService.getActivities(userId);
    final chatResult = await ApiService.getChatHistory(userId);

    final brainwaves = _filterSince(
      brainwaveResult['success'] == true ? brainwaveResult['data'] : null,
      since,
      ['recorded_at', 'created_at'],
    );
    final tests = _filterSince(
      testResult['success'] == true ? testResult['results'] : null,
      since,
      ['test_date', 'created_at'],
    );
    final emotions = _filterSince(
      emotionResult['success'] == true ? emotionResult['emotion_logs'] : null,
      since,
      ['created_at'],
    );
    final activities = _filterSince(
      activityResult['success'] == true ? activityResult['activities'] : null,
      since,
      ['completed_at', 'created_at'],
    );
    final chats = _filterSince(
      chatResult['success'] == true ? chatResult['messages'] : null,
      since,
      ['sent_at', 'created_at'],
    );

    final eeg = _summarizeBrainwaves(brainwaves);
    final mood = _summarizeEmotions(emotions, chats);
    final stress = _summarizeStress(tests);
    final activity = _summarizeActivities(activities);
    final alerts = _buildAlerts(eeg, mood, stress);
    final insight = _buildInsight(eeg, mood, stress, activity, alerts);
    final dailyTrend = _buildDailyTrend(brainwaves);
    final emotionDistribution = _buildEmotionDistribution(emotions);
    final comparison = await _buildComparison(userId, eeg, activity);
    final aiSummary = await _generateAiSummary(
      eeg: eeg,
      mood: mood,
      stress: stress,
      activity: activity,
      alerts: alerts,
      fallback: insight,
    );

    final report = {
      'periodStart': since,
      'periodEnd': DateTime.now(),
      'brainwaveCount': brainwaves.length,
      'emotionCount': emotions.length,
      'activityCount': activities.length,
      'chatCount': chats.length,
      'eeg': eeg,
      'mood': mood,
      'stress': stress,
      'activity': activity,
      'alerts': alerts,
      'insight': insight,
      'aiSummary': aiSummary,
      'carePlan': _buildCarePlan(eeg, mood, stress),
      'dailyTrend': dailyTrend,
      'emotionDistribution': emotionDistribution,
      'comparison': comparison,
    };
    await _persistReport(userId, report);
    await _persistAlerts(userId, alerts);
    return report;
  }

  static List<Map<String, dynamic>> _filterSince(
    dynamic rows,
    DateTime since,
    List<String> dateKeys,
  ) {
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((row) {
          for (final key in dateKeys) {
            final raw = row[key]?.toString();
            if (raw == null || raw.isEmpty) continue;
            final dt = DateTime.tryParse(raw);
            if (dt != null) return dt.isAfter(since);
          }
          return false;
        })
        .toList();
  }

  static Map<String, dynamic> _summarizeBrainwaves(List<Map<String, dynamic>> rows) {
    double avg(String key) {
      final values = rows
          .map((r) => (r[key] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      if (values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final alpha = avg('alpha_wave');
    final beta = avg('beta_wave');
    final theta = avg('theta_wave');
    final delta = avg('delta_wave');
    final attention = avg('attention_score');
    final meditation = avg('meditation_score');
    final stressIndex = ((beta + delta) - (alpha + meditation / 2)).clamp(0, 100);
    final dayStress = <String, List<double>>{};
    final nightDelta = <double>[];

    for (final row in rows) {
      final recordedAt = DateTime.tryParse(
        (row['recorded_at'] ?? row['created_at'] ?? '').toString(),
      );
      final rowBeta = (row['beta_wave'] as num?)?.toDouble() ?? 0;
      final rowDelta = (row['delta_wave'] as num?)?.toDouble() ?? 0;
      final rowAlpha = (row['alpha_wave'] as num?)?.toDouble() ?? 0;
      final rowMeditation = (row['meditation_score'] as num?)?.toDouble() ?? 0;
      final rowStress = ((rowBeta + rowDelta) - (rowAlpha + rowMeditation / 2)).clamp(0, 100).toDouble();

      if (recordedAt != null) {
        final key = _weekdayLabel(recordedAt.weekday);
        dayStress.putIfAbsent(key, () => []).add(rowStress);
        if (recordedAt.hour >= 21 || recordedAt.hour <= 6) {
          nightDelta.add(rowDelta);
        }
      }
    }

    final dailyRisk = dayStress.entries
        .map((entry) {
          final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
          return {'day': entry.key, 'stressIndex': avg};
        })
        .toList()
      ..sort((a, b) => (b['stressIndex'] as double).compareTo(a['stressIndex'] as double));

    final sleepScore = nightDelta.isEmpty
        ? 0.0
        : (nightDelta.reduce((a, b) => a + b) / nightDelta.length).clamp(0, 100).toDouble();

    return {
      'alpha': alpha,
      'beta': beta,
      'theta': theta,
      'delta': delta,
      'attention': attention,
      'meditation': meditation,
      'stressIndex': stressIndex,
      'highStressDays': dailyRisk.take(3).toList(),
      'sleepScore': sleepScore,
      'sleepTrend': sleepScore == 0
          ? 'ไม่มีข้อมูลช่วงกลางคืน'
          : sleepScore >= 45
              ? 'มีสัญญาณการพักผ่อน/หลับลึกค่อนข้างดี'
              : 'ควรติดตามคุณภาพการนอนเพิ่มเติม',
      'label': stressIndex >= 55
          ? 'ต้องเฝ้าระวัง'
          : stressIndex >= 35
              ? 'ปานกลาง'
              : 'ค่อนข้างสมดุล',
    };
  }

  static Map<String, dynamic> _summarizeEmotions(
    List<Map<String, dynamic>> emotions,
    List<Map<String, dynamic>> chats,
  ) {
    final counts = <String, int>{};
    var totalIntensity = 0.0;
    for (final row in emotions) {
      final type = (row['emotion_type'] ?? 'unknown').toString();
      counts[type] = (counts[type] ?? 0) + 1;
      totalIntensity += (row['intensity'] as num?)?.toDouble() ?? 5;
    }

    final riskWords = ['เครียด', 'ไม่ไหว', 'กลัว', 'เศร้า', 'เหงา', 'เจ็บ', 'ตาย', 'ทำร้าย'];
    final riskChatCount = chats.where((row) {
      if (row['is_bot'] == true || row['is_bot'] == 1) return false;
      final text = (row['message'] ?? '').toString().toLowerCase();
      return riskWords.any(text.contains);
    }).length;

    final topEmotion = counts.entries.isEmpty
        ? 'ไม่มีข้อมูล'
        : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return {
      'topEmotion': topEmotion,
      'avgIntensity': emotions.isEmpty ? 0 : totalIntensity / emotions.length,
      'riskChatCount': riskChatCount,
      'counts': counts,
    };
  }

  static Map<String, dynamic> _summarizeStress(List<Map<String, dynamic>> rows) {
    final levels = rows.map((r) => (r['stress_level'] ?? '').toString()).toList();
    final latest = levels.isEmpty ? 'ไม่มีข้อมูล' : levels.first;
    final highCount = levels.where((l) {
      final lower = l.toLowerCase();
      return lower.contains('severe') || lower.contains('high') || l.contains('สูง');
    }).length;
    final scores = rows
        .map((r) => (r['stress_score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    return {
      'latestLevel': latest,
      'highCount': highCount,
      'avgScore': scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length,
    };
  }

  static Map<String, dynamic> _summarizeActivities(List<Map<String, dynamic>> rows) {
    final minutes = rows.fold<int>(
      0,
      (sum, row) => sum + ((row['duration_minutes'] as num?)?.toInt() ?? 0),
    );
    final names = rows
        .map((r) => (r['activity_name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .take(4)
        .toList();
    return {
      'sessions': rows.length,
      'minutes': minutes,
      'recentNames': names,
    };
  }

  static List<Map<String, dynamic>> _buildAlerts(
    Map<String, dynamic> eeg,
    Map<String, dynamic> mood,
    Map<String, dynamic> stress,
  ) {
    final alerts = <Map<String, dynamic>>[];
    if ((eeg['stressIndex'] as num) >= 55) {
      alerts.add({
        'level': 'high',
        'title': 'สัญญาณ EEG เสี่ยงเครียดสูง',
        'message': 'ค่า beta/delta สูงกว่าฝั่งผ่อนคลาย ควรติดตามใกล้ชิด',
      });
    }
    if ((mood['riskChatCount'] as int) > 0) {
      alerts.add({
        'level': 'high',
        'title': 'พบข้อความที่ควรเฝ้าระวัง',
        'message': 'มีข้อความผู้ใช้ที่สะท้อนความเครียดหรือขอความช่วยเหลือ',
      });
    }
    if ((stress['highCount'] as int) > 0) {
      alerts.add({
        'level': 'medium',
        'title': 'แบบประเมินความเครียดสูง',
        'message': 'มีผลทดสอบในสัปดาห์นี้ที่อยู่ระดับสูง',
      });
    }
    if (alerts.isEmpty) {
      alerts.add({
        'level': 'low',
        'title': 'ไม่พบสัญญาณวิกฤตชัดเจน',
        'message': 'ยังควรติดตามต่อเนื่องและทำกิจกรรมผ่อนคลายสม่ำเสมอ',
      });
    }
    return alerts;
  }

  static String _buildInsight(
    Map<String, dynamic> eeg,
    Map<String, dynamic> mood,
    Map<String, dynamic> stress,
    Map<String, dynamic> activity,
    List<Map<String, dynamic>> alerts,
  ) {
    final alertText = alerts.where((a) => a['level'] != 'low').length;
    return 'สัปดาห์นี้ภาพรวมอยู่ในระดับ ${eeg['label']} '
        'อารมณ์ที่พบบ่อยคือ ${mood['topEmotion']} '
        'มีกิจกรรมดูแลสุขภาพ ${activity['sessions']} ครั้ง รวม ${activity['minutes']} นาที '
        'และมีสัญญาณที่ควรติดตาม $alertText รายการ';
  }

  static Future<String> _generateAiSummary({
    required Map<String, dynamic> eeg,
    required Map<String, dynamic> mood,
    required Map<String, dynamic> stress,
    required Map<String, dynamic> activity,
    required List<Map<String, dynamic>> alerts,
    required String fallback,
  }) async {
    if (!ChatGPTService.isConfigured) {
      return fallback;
    }

    final prompt = '''
สรุปรายงานสุขภาพสมองและอารมณ์รายสัปดาห์เป็นภาษาไทย 4-5 ประโยค
ใช้ภาษาที่แพทย์และบุตรหลานอ่านเข้าใจง่าย
ห้ามวินิจฉัยโรค ให้ระบุว่าเป็นข้อมูลประกอบการติดตามเท่านั้น

ข้อมูล:
- EEG status: ${eeg['label']}
- Stress index: ${eeg['stressIndex']}
- Sleep trend: ${eeg['sleepTrend']}
- High stress days: ${eeg['highStressDays']}
- Top mood: ${mood['topEmotion']}
- Risk chat count: ${mood['riskChatCount']}
- Latest stress test: ${stress['latestLevel']}
- Activities: ${activity['sessions']} sessions, ${activity['minutes']} minutes
- Alerts: ${alerts.map((a) => a['title']).join(', ')}
''';

    try {
      final result = await ChatGPTService.sendMessage(message: prompt)
          .timeout(const Duration(seconds: 14));
      if (result['success'] == true && result['bot_response'] != null) {
        return result['bot_response'].toString();
      } else {
        debugPrint('AI Summary Error: ${result['error']}');
      }
    } catch (e) {
      debugPrint('AI Summary Exception: $e');
    }
    return '(วิเคราะห์เบื้องต้น) $fallback';
  }

  static String _weekdayLabel(int weekday) {
    const labels = {
      DateTime.monday: 'จันทร์',
      DateTime.tuesday: 'อังคาร',
      DateTime.wednesday: 'พุธ',
      DateTime.thursday: 'พฤหัส',
      DateTime.friday: 'ศุกร์',
      DateTime.saturday: 'เสาร์',
      DateTime.sunday: 'อาทิตย์',
    };
    return labels[weekday] ?? '-';
  }

  static List<String> _buildCarePlan(
    Map<String, dynamic> eeg,
    Map<String, dynamic> mood,
    Map<String, dynamic> stress,
  ) {
    final plan = <String>[];
    if ((eeg['stressIndex'] as num) >= 55 || (stress['highCount'] as int) > 0) {
      plan.add('จัดช่วงหายใจช้า 5 นาที วันละ 2 รอบ และติดตาม EEG ซ้ำหลังทำกิจกรรม');
      plan.add('ให้ผู้ดูแลโทรสอบถามสั้น ๆ ในวันที่มีคะแนนเครียดสูง');
    } else {
      plan.add('รักษากิจวัตรเดิม และเพิ่มกิจกรรมผ่อนคลายอย่างน้อย 3 วันต่อสัปดาห์');
    }
    if ((mood['riskChatCount'] as int) > 0) {
      plan.add('ตรวจสอบบทสนทนาที่มีคำเสี่ยง และเตรียมช่องทางติดต่อผู้ดูแลหรือสายด่วน');
    }
    plan.add('นำรายงานนี้ให้แพทย์หรือบุตรหลานดูประกอบการติดตาม ไม่ใช้แทนการวินิจฉัย');
    return plan;
  }

  static Future<void> _persistReport(
    int userId,
    Map<String, dynamic> report,
  ) async {
    try {
      final periodStart = report['periodStart'] as DateTime;
      final periodEnd = report['periodEnd'] as DateTime;
      await SupabaseService.client.from('weekly_reports').upsert(
        {
          'user_id': userId,
          'period_start': _dateOnly(periodStart),
          'period_end': _dateOnly(periodEnd),
          'summary': report['aiSummary'] ?? report['insight'],
          'report_data': _jsonSafe(report),
        },
        onConflict: 'user_id,period_start',
      );
    } catch (_) {
      // The feature still works without the optional persistence migration.
    }
  }

  static Future<void> _persistAlerts(
    int userId,
    List<Map<String, dynamic>> alerts,
  ) async {
    try {
      final rows = alerts
          .where((alert) => alert['level'] != 'low')
          .map((alert) => {
                'user_id': userId,
                'level': alert['level'],
                'title': alert['title'],
                'message': alert['message'],
                'source': 'weekly_report',
              })
          .toList();
      if (rows.isNotEmpty) {
        await SupabaseService.client.from('caregiver_alerts').insert(rows);
      }
    } catch (_) {
      // Alert cards are still generated in-app if the table has not been added.
    }
  }

  static Map<String, dynamic> _jsonSafe(Map<String, dynamic> value) {
    return value.map((key, item) {
      if (item is DateTime) return MapEntry(key, item.toIso8601String());
      if (item is Map<String, dynamic>) return MapEntry(key, _jsonSafe(item));
      if (item is List) {
        return MapEntry(
          key,
          item.map((e) => e is Map<String, dynamic> ? _jsonSafe(e) : e).toList(),
        );
      }
      return MapEntry(key, item);
    });
  }

  static String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // Daily Trend — per-day data for LineChart
  // =====================================================
  static List<Map<String, dynamic>> _buildDailyTrend(List<Map<String, dynamic>> rows) {
    final dayData = <int, List<Map<String, double>>>{};
    for (final row in rows) {
      final recordedAt = DateTime.tryParse(
        (row['recorded_at'] ?? row['created_at'] ?? '').toString(),
      );
      if (recordedAt == null) continue;
      final dayKey = recordedAt.weekday;
      final alpha = (row['alpha_wave'] as num?)?.toDouble() ?? 0;
      final beta = (row['beta_wave'] as num?)?.toDouble() ?? 0;
      final meditation = (row['meditation_score'] as num?)?.toDouble() ?? 0;
      final delta = (row['delta_wave'] as num?)?.toDouble() ?? 0;
      final stress = ((beta + delta) - (alpha + meditation / 2)).clamp(0, 100).toDouble();
      dayData.putIfAbsent(dayKey, () => []).add({
        'alpha': alpha,
        'beta': beta,
        'stress': stress,
      });
    }

    final trend = <Map<String, dynamic>>[];
    for (int wd = DateTime.monday; wd <= DateTime.sunday; wd++) {
      final samples = dayData[wd];
      if (samples == null || samples.isEmpty) {
        trend.add({'day': _weekdayLabel(wd), 'weekday': wd, 'alpha': 0.0, 'beta': 0.0, 'stress': 0.0, 'count': 0});
      } else {
        final avgAlpha = samples.map((s) => s['alpha']!).reduce((a, b) => a + b) / samples.length;
        final avgBeta = samples.map((s) => s['beta']!).reduce((a, b) => a + b) / samples.length;
        final avgStress = samples.map((s) => s['stress']!).reduce((a, b) => a + b) / samples.length;
        trend.add({'day': _weekdayLabel(wd), 'weekday': wd, 'alpha': avgAlpha, 'beta': avgBeta, 'stress': avgStress, 'count': samples.length});
      }
    }
    return trend;
  }

  // =====================================================
  // Emotion Distribution — for PieChart
  // =====================================================
  static Map<String, int> _buildEmotionDistribution(List<Map<String, dynamic>> emotions) {
    final counts = <String, int>{};
    for (final row in emotions) {
      final type = (row['emotion_type'] ?? 'unknown').toString();
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  // =====================================================
  // Week-over-Week Comparison
  // =====================================================
  static Future<Map<String, dynamic>> _buildComparison(
    int userId,
    Map<String, dynamic> currentEeg,
    Map<String, dynamic> currentActivity,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('weekly_reports')
          .select('report_data')
          .eq('user_id', userId)
          .order('period_start', ascending: false)
          .limit(2);

      if (response is List && response.length >= 2) {
        final prevData = response[1]['report_data'] as Map<String, dynamic>?;
        if (prevData != null) {
          final prevEeg = prevData['eeg'] as Map<String, dynamic>?;
          final prevActivity = prevData['activity'] as Map<String, dynamic>?;
          final prevStress = (prevEeg?['stressIndex'] as num?)?.toDouble() ?? 0;
          final prevSleep = (prevEeg?['sleepScore'] as num?)?.toDouble() ?? 0;
          final prevSessions = (prevActivity?['sessions'] as num?)?.toInt() ?? 0;
          final curStress = (currentEeg['stressIndex'] as num).toDouble();
          final curSleep = (currentEeg['sleepScore'] as num).toDouble();
          final curSessions = (currentActivity['sessions'] as num).toInt();

          return {
            'hasData': true,
            'stressDelta': curStress - prevStress,
            'sleepDelta': curSleep - prevSleep,
            'activityDelta': curSessions - prevSessions,
            'prevStress': prevStress,
            'prevSleep': prevSleep,
            'prevSessions': prevSessions,
          };
        }
      }
    } catch (e) {
      debugPrint('Comparison fetch failed: $e');
    }
    return {'hasData': false};
  }

  // =====================================================
  // Get Stored Reports for history browsing
  // =====================================================
  static Future<List<Map<String, dynamic>>> getStoredReports(int userId, {int limit = 12}) async {
    try {
      final response = await SupabaseService.client
          .from('weekly_reports')
          .select()
          .eq('user_id', userId)
          .order('period_start', ascending: false)
          .limit(limit);

      if (response is List) {
        return response.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
    } catch (e) {
      debugPrint('getStoredReports failed: $e');
    }
    return [];
  }
}
