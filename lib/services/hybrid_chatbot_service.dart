import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'chatbot_action_service.dart';

class HybridChatbotService {
  // === API Keys ===
  static String get _openAIApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get _anthropicApiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  // === Models ===
  static const String _gpt4oModel = 'gpt-4o'; // For Vision Tasks
  static const String _claudeSonnetModel = 'claude-3-5-sonnet-20241022'; // For Core Brain Engine (Clinical)
  static const String _claudeHaikuModel = 'claude-3-5-haiku-20241022'; // For Volume & Speed (General Chat)

  // === API Endpoints ===
  static const String _openAIBaseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _anthropicBaseUrl = 'https://api.anthropic.com/v1/messages';

  static const String _systemPrompt = '''
คุณคือ "สมาร์ทเบรน AI" ผู้เชี่ยวชาญด้านคลื่นสมองและสุขภาพจิต ทำหน้าที่:

1. **ความรู้เฉพาะทาง:**
   - คลื่นสมอง 5 ประเภท: Delta, Theta, Alpha, Beta, Gamma
   - ความสัมพันธ์ระหว่างคลื่นสมองกับสุขภาพจิต
   - วิธีเพิ่มคลื่น Alpha/Theta ด้วยการทำสมาธิ

2. **บทบาท:**
   - ให้คำแนะนำเรื่องสุขภาพจิต ความเครียด การนอนหลับ
   - อธิบายข้อมูลคลื่นสมองให้เข้าใจง่าย
   - แนะนำกิจกรรมลดความเครียด

3. **รูปแบบการตอบ:**
   - ใช้ภาษาไทยที่เป็นกันเอง
   - ห้ามใช้ emoji ทุกชนิด
   - ห้ามใช้อักษรพิเศษเช่น ** ## * - หรือ markdown formatting ใดๆ ทั้งสิ้น
   - ตอบเป็นข้อความธรรมดาอ่านง่าย
   - ตอบกระชับ ไม่เกิน 3-4 ประโยค
''';

  /// Clinical keywords used to trigger the Core Brain Engine (Claude Sonnet)
  static const List<String> _clinicalKeywords = [
    'วิเคราะห์', 'คลื่นสมอง', 'eeg', 'mri', 'ปวดหัว', 'เครียด', 
    'ซึมเศร้า', 'วินิจฉัย', 'ผลแล็บ', 'อาการ', 'สมอง', 'อัลฟ่า', 'เบต้า'
  ];

  /// Core entry point for sending a message using the Hybrid Router
  static Future<Map<String, dynamic>> sendMessage({
    required int userId,
    required String message,
    List<Map<String, dynamic>>? chatHistory,
    String? base64Image,
    Map<String, double>? brainwaveData,
  }) async {
    
    // 1. Router Logic: Determine the target model
    String targetModel = _determineModel(
      message: message, 
      base64Image: base64Image, 
      brainwaveData: brainwaveData
    );

    debugPrint('🚀 Hybrid Router selected model: $targetModel');

    // Prepare context if brainwave data is provided
    String finalMessage = message;
    if (brainwaveData != null) {
      finalMessage = _buildBrainwaveContext(message, brainwaveData);
    }

    // 2. Dispatch to the appropriate API provider
    if (targetModel == _gpt4oModel) {
      return _callOpenAI(
        userId: userId,
        model: targetModel,
        message: finalMessage,
        chatHistory: chatHistory,
        base64Image: base64Image,
      );
    } else {
      return _callAnthropic(
        userId: userId,
        model: targetModel,
        message: finalMessage,
        chatHistory: chatHistory,
      );
    }
  }

  /// Determines which model to use based on the input
  static String _determineModel({
    required String message,
    String? base64Image,
    Map<String, double>? brainwaveData,
  }) {
    // 1. Vision Tasks -> GPT-4o
    if (base64Image != null && base64Image.isNotEmpty) {
      return _gpt4oModel;
    }

    // 2. Core Brain Engine Tasks -> Claude 3.5 Sonnet
    if (brainwaveData != null) {
      return _claudeSonnetModel;
    }
    
    final lowercaseMessage = message.toLowerCase();
    for (final keyword in _clinicalKeywords) {
      if (lowercaseMessage.contains(keyword)) {
        return _claudeSonnetModel;
      }
    }

    // 3. Volume & Speed Tasks -> Claude 3.5 Haiku
    return _claudeHaikuModel;
  }

  static String _buildBrainwaveContext(String message, Map<String, double> data) {
    return '''
=== ข้อมูลคลื่นสมองปัจจุบัน ===
🧠 Alpha: ${data['alpha']?.toStringAsFixed(1) ?? 'N/A'}%
🧠 Beta: ${data['beta']?.toStringAsFixed(1) ?? 'N/A'}%
🧠 Theta: ${data['theta']?.toStringAsFixed(1) ?? 'N/A'}%
🧠 Delta: ${data['delta']?.toStringAsFixed(1) ?? 'N/A'}%
🧠 Gamma: ${data['gamma']?.toStringAsFixed(1) ?? 'N/A'}%
📊 Attention Score: ${data['attention']?.toStringAsFixed(1) ?? 'N/A'}
📊 Meditation Score: ${data['meditation']?.toStringAsFixed(1) ?? 'N/A'}
=== จบข้อมูลคลื่นสมอง ===

คำถามผู้ใช้: $message
กรุณาให้คำแนะนำโดยอ้างอิงจากข้อมูลคลื่นสมองข้างต้น''';
  }

  // ==========================================
  // OpenAI Integration (GPT-4o)
  // ==========================================
  static Future<Map<String, dynamic>> _callOpenAI({
    required int userId,
    required String model,
    required String message,
    List<Map<String, dynamic>>? chatHistory,
    String? base64Image,
  }) async {
    if (_openAIApiKey.isEmpty || _openAIApiKey == 'YOUR_OPENAI_API_KEY') {
      return {'success': false, 'message': 'Missing OpenAI API Key'};
    }

    try {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': _systemPrompt},
      ];

      if (chatHistory != null) {
        final recentHistory = chatHistory.length > 10 ? chatHistory.sublist(chatHistory.length - 10) : chatHistory;
        for (final msg in recentHistory) {
          messages.add({
            'role': msg['is_bot'] == true ? 'assistant' : 'user',
            'content': msg['message'] ?? '',
          });
        }
      }

      dynamic content = message;
      if (base64Image != null && base64Image.isNotEmpty) {
        content = [
          {"type": "text", "text": message},
          {
            "type": "image_url",
            "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
          }
        ];
      }

      messages.add({'role': 'user', 'content': content});

      final response = await http.post(
        Uri.parse(_openAIBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAIApiKey',
        },
        body: json.encode({
          'model': model,
          'messages': messages,
          'tools': ChatbotActionService.getTools(),
          'max_tokens': 800,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseMessage = data['choices'][0]['message'];
        
        // Handle Tool Calls
        if (responseMessage['tool_calls'] != null && (responseMessage['tool_calls'] as List).isNotEmpty) {
          try {
            final toolCall = responseMessage['tool_calls'][0];
            final functionName = toolCall['function']['name'];
            final arguments = json.decode(toolCall['function']['arguments']);

            final actionResult = await ChatbotActionService.executeToolCall(
              userId: userId,
              functionName: functionName,
              arguments: arguments,
              originalMessage: message,
            );

            return {
              'success': true,
              'bot_response': actionResult.response,
              'model_used': model,
              'navigation_target': actionResult.navigationTarget,
              'action_type': actionResult.actionType,
            };
          } catch (e) {
            debugPrint('Error executing tool call: $e');
          }
        }

        return {
          'success': true,
          'bot_response': responseMessage['content'],
          'model_used': model,
        };
      } else {
        return {'success': false, 'message': 'OpenAI API Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error: $e'};
    }
  }

  // ==========================================
  // Anthropic Integration (Claude 3.5 Family)
  // ==========================================
  static Future<Map<String, dynamic>> _callAnthropic({
    required int userId,
    required String model,
    required String message,
    List<Map<String, dynamic>>? chatHistory,
  }) async {
    if (_anthropicApiKey.isEmpty || _anthropicApiKey == 'YOUR_ANTHROPIC_API_KEY') {
      return {'success': false, 'message': 'Missing Anthropic API Key'};
    }

    try {
      final messages = <Map<String, dynamic>>[];

      if (chatHistory != null) {
        final recentHistory = chatHistory.length > 10 ? chatHistory.sublist(chatHistory.length - 10) : chatHistory;
        for (final msg in recentHistory) {
          messages.add({
            'role': msg['is_bot'] == true ? 'assistant' : 'user',
            'content': msg['message'] ?? '',
          });
        }
      }

      messages.add({'role': 'user', 'content': message});

      // Map OpenAI tools to Anthropic tool schema
      final anthropicTools = ChatbotActionService.getTools().map((t) {
        final func = t['function'];
        return {
          'name': func['name'],
          'description': func['description'],
          'input_schema': func['parameters'],
        };
      }).toList();

      final response = await http.post(
        Uri.parse(_anthropicBaseUrl),
        headers: {
          'x-api-key': _anthropicApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: json.encode({
          'model': model,
          'system': _systemPrompt,
          'messages': messages,
          'tools': anthropicTools,
          'max_tokens': 800,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle Tool Calls
        if (data['stop_reason'] == 'tool_use') {
          try {
            final toolUse = (data['content'] as List).firstWhere((c) => c['type'] == 'tool_use');
            final functionName = toolUse['name'];
            final arguments = toolUse['input'] as Map<String, dynamic>;

            final actionResult = await ChatbotActionService.executeToolCall(
              userId: userId,
              functionName: functionName,
              arguments: arguments,
              originalMessage: message,
            );

            return {
              'success': true,
              'bot_response': actionResult.response,
              'model_used': model,
              'navigation_target': actionResult.navigationTarget,
              'action_type': actionResult.actionType,
            };
          } catch (e) {
            debugPrint('Error executing tool call: $e');
          }
        }

        final textContent = (data['content'] as List).firstWhere((c) => c['type'] == 'text', orElse: () => {'text': ''});
        return {
          'success': true,
          'bot_response': textContent['text'],
          'model_used': model,
        };
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': 'Anthropic API Error: ${errorData['error']?['message'] ?? response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error: $e'};
    }
  }
}
