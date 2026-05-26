import 'api_service.dart';
import 'supabase_service.dart';
import 'weekly_report_service.dart';

class ChatbotActionResult {
  final bool handled;
  final String response;
  final String? actionType;
  /// Name of the route/screen to navigate to after showing the response.
  /// e.g. 'eeg_session', 'mini_games', 'weekly_report', 'caretaker'
  final String? navigationTarget;

  const ChatbotActionResult({
    required this.handled,
    required this.response,
    this.actionType,
    this.navigationTarget,
  });

  static const none = ChatbotActionResult(handled: false, response: '');
}

class ChatbotActionService {
  static List<Map<String, dynamic>> getTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'create_schedule',
          'description': 'สร้างตารางเวลาหรือการตั้งเตือนสำหรับผู้ใช้',
          'parameters': {
            'type': 'object',
            'properties': {
              'time': {
                'type': 'string',
                'description': 'เวลาในรูปแบบ HH:MM (24 ชั่วโมง)',
              },
              'title': {
                'type': 'string',
                'description': 'ชื่อของการตั้งเตือน',
              },
            },
            'required': ['time', 'title'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'log_emotion',
          'description': 'บันทึกอารมณ์ความรู้สึกของผู้ใช้',
          'parameters': {
            'type': 'object',
            'properties': {
              'emotion': {
                'type': 'string',
                'description': 'ประเภทอารมณ์: stress, sad, anxious, happy, calm, neutral',
              },
              'intensity': {
                'type': 'integer',
                'description': 'ระดับความเข้มข้นของอารมณ์ (1 ถึง 10)',
              },
            },
            'required': ['emotion', 'intensity'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'request_help',
          'description': 'ขอความช่วยเหลือฉุกเฉินจากผู้ดูแล หรือเมื่อผู้ใช้รู้สึกท้อแท้ ต้องการกำลังใจ',
          'parameters': {
            'type': 'object',
            'properties': {
              'message': {
                'type': 'string',
                'description': 'ข้อความสรุปปัญหาของผู้ใช้',
              },
            },
            'required': ['message'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'navigate_to_screen',
          'description': 'นำทางผู้ใช้ไปยังหน้าจอต่างๆ ตามความต้องการ',
          'parameters': {
            'type': 'object',
            'properties': {
              'screen_name': {
                'type': 'string',
                'description': 'ชื่อหน้าจอ: eeg_session (วัดคลื่นสมอง), mini_games (เล่นเกม), weekly_report (รายงาน), caretaker (ผู้ดูแล)',
              },
            },
            'required': ['screen_name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'summarize_weekly_report',
          'description': 'สรุปรายงานสุขภาพรายสัปดาห์แบบย่อให้ผู้ใช้อ่าน',
          'parameters': {
            'type': 'object',
            'properties': {},
          },
        },
      }
    ];
  }

  static Future<ChatbotActionResult> executeToolCall({
    required int userId,
    required String functionName,
    required Map<String, dynamic> arguments,
    required String originalMessage,
  }) async {
    if (functionName == 'create_schedule') {
      final time = arguments['time'] ?? '20:00';
      final title = arguments['title'] ?? 'กิจกรรมจากแชทบอท';
      final result = await ApiService.addSchedule(
        userId: userId,
        title: title,
        description: 'สร้างจากคำสั่งแชท: $originalMessage',
        time: time,
        iconName: 'event',
        color: 'blue',
      );
      if (result['success'] == true) {
        return ChatbotActionResult(
          handled: true,
          actionType: 'create_schedule',
          response: 'ตั้งเตือน "$title" เวลา $time ให้แล้วครับ ระบบบันทึกลงตารางกิจกรรมเรียบร้อย',
        );
      }
      return ChatbotActionResult(
        handled: true,
        actionType: 'create_schedule',
        response: 'ผมเข้าใจว่าต้องการตั้งเตือน แต่ยังบันทึกไม่ได้: ${result['message'] ?? 'ไม่ทราบสาเหตุ'}',
      );
    }

    if (functionName == 'log_emotion') {
      final emotion = arguments['emotion'] ?? 'neutral';
      final intensity = arguments['intensity'] ?? 5;
      final result = await ApiService.saveEmotionLog(
        userId: userId,
        emotionType: emotion,
        triggerEvent: originalMessage,
        intensity: intensity,
      );
      if (result['success'] == true) {
        return ChatbotActionResult(
          handled: true,
          actionType: 'log_emotion',
          response: 'บันทึกอารมณ์ "$emotion" ระดับ $intensity ให้แล้วครับ เดี๋ยวระบบจะนำไปใช้ในรายงานรายสัปดาห์',
        );
      }
      return ChatbotActionResult(
        handled: true,
        actionType: 'log_emotion',
        response: 'ผมเข้าใจว่าต้องการบันทึกอารมณ์ แต่ยังบันทึกไม่ได้: ${result['message'] ?? 'ไม่ทราบสาเหตุ'}',
      );
    }

    if (functionName == 'request_help') {
      final msg = arguments['message'] ?? originalMessage;
      try {
        await SupabaseService.client.from('caregiver_alerts').insert({
          'user_id': userId,
          'level': 'high',
          'title': 'ผู้ใช้ขอความช่วยเหลือ',
          'message': 'ข้อความ: $msg',
          'source': 'chatbot',
        });

        await ApiService.sendFCMPushNotification(
          userId,
          '⚠️ แจ้งเตือนฉุกเฉิน!',
          'ผู้ใช้อาจต้องการความช่วยเหลือ: "$msg"'
        );
      } catch (_) {}
      return const ChatbotActionResult(
        handled: true,
        actionType: 'request_help',
        response: 'หากตอนนี้รู้สึกไม่ไหว หรือต้องการใครสักคนรับฟัง ลองโทรพูดคุยที่นี่ได้ตลอด 24 ชั่วโมงนะครับ:\n📞 สายด่วนสุขภาพจิต 1323\nคุณไม่ได้อยู่คนเดียวนะครับ ผมและอีกหลายคนห่วงใย พร้อมรับฟังเสมอ❤️',
      );
    }

    if (functionName == 'navigate_to_screen') {
      final screen = arguments['screen_name'] ?? '';
      String responseMsg = 'กำลังเปิดหน้าจอให้ครับ...';
      if (screen == 'eeg_session') responseMsg = 'เปิดหน้าวัดคลื่นสมองให้แล้วครับ กรุณาสวมอุปกรณ์ Muse แล้วกดเริ่มวัดได้เลย 🧠';
      if (screen == 'mini_games') responseMsg = 'เปิดเกมฝึกสมองให้แล้วครับ เลือกเกมที่ชอบแล้วเริ่มเล่นได้เลย! 🎮';
      if (screen == 'weekly_report') responseMsg = 'เปิดหน้ารายงานรายสัปดาห์ให้แล้วครับ 📊';
      if (screen == 'caretaker') responseMsg = 'เปิดหน้าจัดการผู้ดูแลให้แล้วครับ 📞';

      return ChatbotActionResult(
        handled: true,
        actionType: 'navigate_to_screen',
        response: responseMsg,
        navigationTarget: screen,
      );
    }

    if (functionName == 'summarize_weekly_report') {
      try {
        final report = await WeeklyReportService.generate(userId);
        final aiSummary = report['aiSummary']?.toString() ?? report['insight']?.toString() ?? '';
        final eeg = report['eeg'] as Map<String, dynamic>? ?? {};
        final stressIdx = ((eeg['stressIndex'] ?? 0) as num).toStringAsFixed(1);
        final label = eeg['label'] ?? 'ปกติ';
        return ChatbotActionResult(
          handled: true,
          actionType: 'inline_summary',
          response: '📊 สรุปสัปดาห์นี้:\n\n• Stress Index: $stressIdx\n• สถานะ: $label\n\n$aiSummary\n\nดูรายงานเต็มได้ที่หน้า AI Report ครับ',
          navigationTarget: 'weekly_report',
        );
      } catch (_) {
        return const ChatbotActionResult(
          handled: true,
          actionType: 'inline_summary',
          response: 'ยังไม่มีข้อมูลเพียงพอสำหรับสรุปสัปดาห์นี้ครับ ลองใช้งานต่ออีกสักวันแล้วถามใหม่นะครับ',
        );
      }
    }

    return ChatbotActionResult.none;
  }
}
