import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import 'settings_screen.dart';
import 'mini_games_screen.dart';
import 'test_screen.dart';
import 'nutrition_screen.dart';
import 'caretaker_screen.dart';
import 'weekly_report_screen.dart';
import 'caregiver_dashboard_screen.dart';

class RecommendationScreen extends StatefulWidget {
  final User? user;

  const RecommendationScreen({super.key, this.user});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final TTSService _ttsService = TTSService();
  final STTService _sttService = STTService();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _autoSpeak = true;
  int? _speakingMessageIndex;

  bool _isVoiceMode = false;
  List<String> _suggestedQuestions = [
    'ขอวิธีจัดการความเครียดสะสม',
    'ขอแนะนำอาหารบำรุงสุขภาพจิต',
    'ตรวจคลื่นสมองมีขั้นตอนอย่างไร?',
    'วิเคราะห์แนวโน้มสุขภาพจิตสัปดาห์นี้'
  ];
  String _partialText = '';

  late AnimationController _micPulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadChatHistory();

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _initServices() async {
    await _ttsService.init();
    await _sttService.init();

    _sttService.onResult = _onSpeechResult;
    _sttService.onPartialResult = _onPartialResult;
    _sttService.onListeningStarted = _onListeningStarted;
    _sttService.onListeningStopped = _onListeningStopped;
    _sttService.onError = _onSpeechError;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    _sttService.dispose();
    _micPulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _onSpeechResult(String text) {
    if (text.isNotEmpty && mounted) {
      setState(() {
        _partialText = '';
        _isVoiceMode = false;
      });

      _messageController.text = text;
      _sendMessage();
    }
  }

  void _onPartialResult(String text) {
    if (mounted) {
      setState(() => _partialText = text);
    }
  }

  void _onListeningStarted() {
    if (mounted) {
      setState(() => _isVoiceMode = true);
      _micPulseController.repeat(reverse: true);
      _waveController.repeat(reverse: true);
    }
  }

  void _onListeningStopped() {
    if (mounted) {
      setState(() => _isVoiceMode = false);
      _micPulseController.stop();
      _waveController.stop();
      _micPulseController.reset();
      _waveController.reset();
    }
  }

  void _onSpeechError(String error) {
    if (mounted) {
      setState(() {
        _isVoiceMode = false;
        _partialText = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red[400],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_sttService.isListening) {

      await _sttService.stopListening();
    } else {

      if (!_sttService.isAvailable) {
        final success = await _sttService.init();
        if (!success) return;

        _sttService.onResult = _onSpeechResult;
        _sttService.onPartialResult = _onPartialResult;
        _sttService.onListeningStarted = _onListeningStarted;
        _sttService.onListeningStopped = _onListeningStopped;
        _sttService.onError = _onSpeechError;
      }

      if (_ttsService.isSpeaking) {
        await _ttsService.stop();
        setState(() => _speakingMessageIndex = null);
      }
      await _sttService.startListening();
    }
  }

  Future<void> _loadChatHistory() async {
    if (widget.user == null) {
      setState(() {
        _isLoading = false;
        _messages = [
          ChatMessage(
            text: 'สวัสดีครับ! ผมสมาร์ทเบรน AI ผู้เชี่ยวชาญด้านคลื่นสมองและสุขภาพจิต พร้อมให้คำแนะนำครับ 🧠\n\nคุณสามารถพิมพ์หรือ กดปุ่มไมค์เพื่อพูดกับผมได้เลยครับ 🎤',
            isBot: true,
            time: '09:00',
          ),
        ];
      });
      return;
    }

    final result = await ApiService.getChatHistory(widget.user!.id);

    if (result['success'] == true && result['messages'] != null) {
      setState(() {
        _messages = (result['messages'] as List).map((m) {
          return ChatMessage(
            text: m['message'],
            isBot: m['is_bot'] == true || m['is_bot'] == 1,
            time: m['sent_at']?.toString().substring(11, 16) ?? '',
          );
        }).toList();

        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            text: 'สวัสดีครับ! ผมสมาร์ทเบรน AI ผู้เชี่ยวชาญด้านคลื่นสมองและสุขภาพจิต พร้อมให้คำแนะนำครับ 🧠\n\nคุณสามารถพิมพ์หรือ กดปุ่มไมค์เพื่อพูดกับผมได้เลยครับ 🎤',
            isBot: true,
            time: TimeOfDay.now().format(context),
          ));
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _messages = [
          ChatMessage(
            text: 'สวัสดีครับ! ผมสมาร์ทเบรน AI ผู้เชี่ยวชาญด้านคลื่นสมองและสุขภาพจิต พร้อมให้คำแนะนำครับ 🧠\n\nคุณสามารถพิมพ์หรือ กดปุ่มไมค์เพื่อพูดกับผมได้เลยครับ 🎤',
            isBot: true,
            time: TimeOfDay.now().format(context),
          ),
        ];
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speakMessage(int index) async {
    final message = _messages[index];

    if (_speakingMessageIndex == index && _ttsService.isSpeaking) {
      await _ttsService.stop();
      setState(() => _speakingMessageIndex = null);
    } else {
      await _ttsService.stop();
      setState(() => _speakingMessageIndex = index);
      await _ttsService.speak(message.text);
      if (mounted) setState(() => _speakingMessageIndex = null);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text;
    
    if (_handleActionCommands(messageText)) {
      _messageController.clear();
      return;
    }

    _messageController.clear();

    setState(() {
      _suggestedQuestions = []; // Clear suggestions
      _messages.add(ChatMessage(
        text: messageText,
        isBot: false,
        time: TimeOfDay.now().format(context),
      ));
      _isSending = true;
    });

    _scrollToBottom();

    final chatHistory = _messages.map((m) => {
      'message': m.text,
      'is_bot': m.isBot,
    }).toList();

    if (widget.user != null) {

      final result = await ApiService.sendChatGPTMessage(
        userId: widget.user!.id,
        message: messageText,
        chatHistory: chatHistory,
      );

      if (result['success'] == true && result['bot_response'] != null) {
        final botResponse = result['bot_response'];

        setState(() {
          _messages.add(ChatMessage(
            text: botResponse,
            isBot: true,
            time: TimeOfDay.now().format(context),
          ));
          _isSending = false;
        });
        _scrollToBottom();
        _generateSuggestedQuestions(messageText); // Generate next recommendations

        if (_autoSpeak) {
          setState(() => _speakingMessageIndex = _messages.length - 1);
          await _ttsService.speak(botResponse);
          if (mounted) setState(() => _speakingMessageIndex = null);
        }
        return;
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      final fallbackResponse = _getLocalBotResponse(messageText);
      setState(() {
        _messages.add(ChatMessage(
          text: fallbackResponse,
          isBot: true,
          time: TimeOfDay.now().format(context),
        ));
        _isSending = false;
      });
      _scrollToBottom();
      _generateSuggestedQuestions(messageText); // Generate next recommendations

      if (_autoSpeak) {
        setState(() => _speakingMessageIndex = _messages.length - 1);
        await _ttsService.speak(fallbackResponse);
        if (mounted) setState(() => _speakingMessageIndex = null);
      }
    }
  }

  String _extractKeyPhrase(String query) {
    String cleaned = query
        .replaceAll('สวัสดี', '')
        .replaceAll('อยาก', '')
        .replaceAll('ช่วย', '')
        .replaceAll('แนะนำ', '')
        .replaceAll('ขอ', '')
        .replaceAll('หน่อย', '')
        .replaceAll('ครับ', '')
        .replaceAll('ค่ะ', '')
        .replaceAll('จ้า', '')
        .replaceAll('?', '')
        .replaceAll('？', '')
        .trim();
        
    if (cleaned.length < 2) {
      return '';
    }
    return cleaned;
  }

  void _generateSuggestedQuestions(String lastQuery) {
    final text = lastQuery.toLowerCase().trim();
    List<String> suggestions = [];
    final phrase = _extractKeyPhrase(lastQuery);

    if (text.contains('นอน') || text.contains('sleep') || text.contains('หลับ')) {
      final topic = phrase.isNotEmpty ? phrase : 'การนอนหลับ';
      suggestions = [
        'ขอวิธีช่วยให้ $topic ดีขึ้น',
        'คลื่นสมองส่งผลต่อ $topic อย่างไร?',
        'อาหารที่ช่วยให้ $topic สบายและหลับลึก',
        'ขอเทคนิคผ่อนคลายเพื่อ $topic'
      ];
    } else if (text.contains('เครียด') || text.contains('stress') || text.contains('กังวล') || text.contains('กลัว')) {
      final topic = phrase.isNotEmpty ? phrase : 'ความเครียด';
      suggestions = [
        'เมนูอาหารช่วยลด $topic',
        'วิธีผ่อนคลายและลด $topic ใน 5 นาที',
        'ทำแบบประเมินเช็คระดับ $topic',
        'สถิติรายงานสุขภาพจิตเรื่อง $topic'
      ];
    } else if (text.contains('อาหาร') || text.contains('กิน') || text.contains('โภชนาการ') || text.contains('เมนู')) {
      final topic = phrase.isNotEmpty ? phrase : 'อาหารและโภชนาการ';
      suggestions = [
        'เมนูแนะนำเพิ่มเติมเกี่ยวกับ $topic',
        'ความสำคัญของ $topic ต่อคลื่นสมอง',
        'อาหารประเภทไหนควรเลี่ยงเกี่ยวกับ $topic',
        'แอปแนะนำโภชนาการ/เมนูลดเครียด'
      ];
    } else if (text.contains('คลื่นสมอง') || text.contains('eeg') || text.contains('muse')) {
      final topic = phrase.isNotEmpty ? phrase : 'คลื่นสมอง';
      suggestions = [
        'อธิบายการทำงานของ $topic เพิ่มเติม',
        'วิธีฝึกควบคุม $topic ด้วยตนเอง',
        'การวิเคราะห์รายงาน $topic รายสัปดาห์',
        'สมาธิและสติส่งผลต่อ $topic อย่างไร?'
      ];
    } else if (text.contains('รายงาน') || text.contains('report') || text.contains('สรุป')) {
      final topic = phrase.isNotEmpty ? phrase : 'รายงานสุขภาพประจำสัปดาห์';
      suggestions = [
        'รายละเอียดข้อมูลของ $topic',
        'วิธีอ่านค่าสถิติจาก $topic',
        'ดาวน์โหลดไฟล์ PDF ของ $topic',
        'ส่ง $topic นี้ให้ผู้ดูแลอย่างไร?'
      ];
    } else if (text.contains('เกม') || text.contains('game') || text.contains('เล่น')) {
      final topic = phrase.isNotEmpty ? phrase : 'เกมเสริมทักษะ';
      suggestions = [
        'เปิดหน้า $topic ให้ฉันหน่อย',
        'ประโยชน์ของ $topic ต่อความจำ',
        'คะแนนสถิติสูงสุดในการเล่น $topic',
        'มี $topic แบบอื่นแนะนำอีกไหม?'
      ];
    } else if (text.contains('ผู้ดูแล') || text.contains('caretaker') || text.contains('caregiver')) {
      final topic = phrase.isNotEmpty ? phrase : 'ระบบผู้ดูแล';
      suggestions = [
        'วิธีตั้งค่าใช้งาน $topic',
        'ฟังก์ชันหลักของ $topic มีอะไรบ้าง?',
        'ส่งข้อความแจ้งเตือนด่วนผ่าน $topic',
        'เบอร์ติดต่อฉุกเฉินสำหรับ $topic'
      ];
    } else if (phrase.isNotEmpty && phrase.length > 2) {
      suggestions = [
        'ขอคำอธิบายเพิ่มเติมเกี่ยวกับ "$phrase"',
        'ความรู้รอบตัวเรื่อง "$phrase" กับสุขภาพจิต',
        'มีคำแนะนำพิเศษเพิ่มเติมสำหรับ "$phrase" ไหม?',
        'ขอเมนูอาหารหรือวิธีดูแลสุขภาพเรื่อง "$phrase"'
      ];
    } else {
      suggestions = [
        'ขอวิธีจัดการความเครียดสะสม',
        'ขอเมนูอาหารบำรุงสมองและอารมณ์',
        'แนะนำวิธีฝึกสมาธิด้วยคลื่นสมอง',
        'อธิบายผลวิเคราะห์สุขภาพจิตล่าสุด'
      ];
    }

    setState(() {
      _suggestedQuestions = suggestions;
    });
  }

  void _onSuggestionTap(String question) {
    _messageController.text = question;
    _sendMessage();
  }

  Widget _buildSuggestedQuestionsArea() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: AppColors.primaryBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                'ถามต่อเกี่ยวกับเรื่องนี้:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _suggestedQuestions.map((question) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => _onSuggestionTap(question),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: AppTheme.glassDecoration(
                        color: AppColors.primaryBlue,
                        opacity: 0.08,
                        borderColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        question,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  bool _handleActionCommands(String text) {
    final lowerText = text.toLowerCase().trim();
    
    String? title;
    String? voiceText;
    Widget Function()? destinationBuilder;
    
    if (lowerText.contains('เกม') || lowerText.contains('game')) {
      title = 'หน้าเกมเสริมทักษะ';
      voiceText = 'กำลังเปิดหน้าเกมเสริมทักษะค่ะ';
      destinationBuilder = () => MiniGamesScreen(user: widget.user);
    } else if (lowerText.contains('แบบทดสอบ') || lowerText.contains('แบบประเมิน') || lowerText.contains('test') || lowerText.contains('phq')) {
      title = 'แบบประเมินสุขภาพจิต PHQ-9';
      voiceText = 'กำลังเปิดแบบประเมินสุขภาพจิตพีเอชคิวเก้าค่ะ';
      destinationBuilder = () => TestScreen(user: widget.user);
    } else if (lowerText.contains('ผู้ดูแล') || lowerText.contains('caretaker') || lowerText.contains('caregiver') || 
               lowerText.contains('หมอ') || lowerText.contains('แพทย์') || lowerText.contains('ฉุกเฉิน') || lowerText.contains('สายด่วน')) {
      title = 'ระบบผู้ดูแลและสายด่วนฉุกเฉิน';
      voiceText = 'กำลังเปิดหน้าผู้ดูแลและสายด่วนฉุกเฉินค่ะ';
      destinationBuilder = () {
        if (widget.user != null && widget.user!.role == 'caretaker') {
          return CaregiverDashboardScreen(user: widget.user!);
        } else {
          return const CaretakerScreen();
        }
      };
    } else if (lowerText.contains('อาหาร') || lowerText.contains('nutrition') || lowerText.contains('กินอะไร')) {
      title = 'คำแนะนำโภชนาการ';
      voiceText = 'กำลังเปิดหน้าคำแนะนำโภชนาการค่ะ';
      destinationBuilder = () => const NutritionScreen();
    } else if (lowerText.contains('รายงาน') || lowerText.contains('weekly report') || lowerText.contains('สรุปสุขภาพ')) {
      title = 'รายงานสรุปประจำสัปดาห์';
      voiceText = 'กำลังเปิดหน้ารายงานสรุปสุขภาพประจำสัปดาห์ค่ะ';
      destinationBuilder = () => WeeklyReportScreen(user: widget.user);
    }

    if (title != null && destinationBuilder != null) {
      final finalTitle = title;
      final finalVoiceText = voiceText ?? 'กำลังเปิดหน้า $title ค่ะ';
      final finalDest = destinationBuilder;

      // Add user message to history
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isBot: false,
          time: TimeOfDay.now().format(context),
        ));
        _isSending = true;
      });
      _scrollToBottom();

      // Trigger bot response and speech immediately, then navigation
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              text: '🤖 กำลังนำคุณไปยังหน้า $finalTitle ใน 2 วินาที...\n(หรือคุณสามารถแตะปุ่มด้านล่างเพื่อไปทันที)',
              isBot: true,
              time: TimeOfDay.now().format(context),
            ));
            _isSending = false;
          });
          _scrollToBottom();
          
          if (_autoSpeak) {
            _ttsService.speak(finalVoiceText);
          }

          // Delay navigation
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => finalDest()),
              );
            }
          });
        }
      });
      return true;
    }
    return false;
  }

  String _getLocalBotResponse(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('ที่มา') || lowerMessage.contains('แนวคิด') || lowerMessage.contains('smartbrain') || lowerMessage.contains('สมาร์ทเบรน')) {
      return 'SmartBrain Care เป็นระบบอัจฉริยะสำหรับคัดกรองและวิเคราะห์สภาวะสมองเชิงรุกเพื่อลดความเสี่ยงภาวะซึมเศร้าและเครียดสะสม พัฒนาขึ้นโดยคณะผู้วิจัยมหาวิทยาลัยวลัยลักษณ์ โดยแปลงสัญญาณ EEG ให้เป็นภาพแผนที่ความร้อน (Topographic Map) และใช้ระบบเรียนรู้แบบถ่ายโอน (Transfer Learning) ร่วมกับปัญญาประดิษฐ์เพื่อจำแนกสภาวะสมองได้อย่างแม่นยำรวดเร็วบนอุปกรณ์พกพาครับ';
    }
    if (lowerMessage.contains('วัตถุประสงค์') || lowerMessage.contains('เป้าหมาย')) {
      return 'วัตถุประสงค์หลักของ SmartBrain Care คือ 1. พัฒนาระบบประเมินสภาวะสมองอัตโนมัติแบบเรียลไทม์เพื่อลดภาระงานการแปลผลกราฟซับซ้อนของแพทย์ 2. ประยุกต์ใช้ AI ในการจำแนกสภาวะสมองผ่านภาพโดยคงความแม่นยำและประหยัดทรัพยากรการประมวลผลสูงสุด 3. ยกระดับการเฝ้าระวังสุขภาพจิตเชิงรุกด้วยอุปกรณ์สวมใส่ไร้สายแบบไม่รุกล้ำและใช้งานง่ายครับ';
    }
    if (lowerMessage.contains('จุดเด่น') || lowerMessage.contains('ต่าง') || lowerMessage.contains('ดีกว่า')) {
      return 'จุดเด่นของระบบคือ 1. วิเคราะห์ผ่านข้อมูลภาพแผนที่ความร้อนลดผลกระทบสัญญาณรบกวน 2. ใช้กลไกเพิ่มข้อมูลน้ำหนักเบา (Lightweight Augmentation) เพื่อขยายฐานข้อมูลในกรณีคลื่นสมองที่หายาก 3. ประยุกต์ใช้ Transfer Learning เพื่อความแม่นยำสูงและประมวลผลเรียลไทม์บน Edge Devices โดยตรง 4. แจ้งเตือนสภาวะวิกฤตได้ทันทีเพื่อการตอบสนองเชิงรุกครับ';
    }
    if (lowerMessage.contains('ขั้นตอน') || lowerMessage.contains('ทำงาน') || lowerMessage.contains('หลักการ')) {
      return 'ขั้นตอนการทำงานของนวัตกรรมประกอบด้วย 5 ขั้นตอนหลัก: 1. รับสัญญาณ EEG ผ่าน BLE จากนั้นกรองคลื่นรบกวนและแปลงเป็นภาพสเปกตรัม/แผนที่ความร้อน 2. ใช้อัลกอริทึมเพิ่มข้อมูลน้ำหนักเบาขยายความยืดหยุ่น 3. จำแนกประเภทสภาวะอารมณ์ 10 ประเภทด้วย Deep Learning 4. คำนวณความเสี่ยงร่วมกับแบบประเมิน PHQ-9 5. แสดงผลบน Dashboard และส่งออกรายงาน PDF ครับ';
    }
    if (lowerMessage.contains('trl') || lowerMessage.contains('srl') || lowerMessage.contains('สิทธิบัตร') || lowerMessage.contains('ความพร้อม')) {
      return 'ปัจจุบันโครงการมีความพร้อมทางเทคโนโลยีระดับ TRL 6 (ตัวแบบทดสอบในสภาพแวดล้อมจำลองชีวิตประจำวัน) และความพร้อมทางสังคมระดับ SRL 6 (สาธิตและรับฟังฟีดแบ็กจากหน่วยงานจิตวิทยา/สาธารณสุขปฐมภูมิ) และอยู่ในขั้นตอนจัดเตรียมคำขอรับสิทธิบัตร/อนุสิทธิบัตรในประเทศไทยเพื่อคุ้มครองสิทธิ์ในงานวิจัยนี้ครับ';
    }
    if (lowerMessage.contains('alpha') || lowerMessage.contains('อัลฟา')) {
      return 'คลื่น Alpha (8-13 Hz) เป็นคลื่นสมองที่เกิดขึ้นเมื่อร่างกายและจิตใจอยู่ในสภาวะผ่อนคลาย สงบ แต่ตื่นตัว เช่น ขณะหลับตาพักผ่อนหรือทำสมาธิ ช่วยลดความเครียดและส่งเสริมการเรียนรู้ได้ดีครับ';
    }
    if (lowerMessage.contains('beta') || lowerMessage.contains('เบตา')) {
      return 'คลื่น Beta (13-30 Hz) สัมพันธ์กับการคิดวิเคราะห์ การทำงาน หรือใช้สมาธิจดจ่ออย่างหนัก หากระดับ Beta สูงเกินไปอาจส่งสัญญาณบ่งชี้สภาวะเครียด วิตกกังวล หรือนอนไม่หลับได้ครับ';
    }
    if (lowerMessage.contains('theta') || lowerMessage.contains('ทีตา')) {
      return 'คลื่น Theta (4-8 Hz) มักเกิดขึ้นขณะเริ่มเคลิ้มหลับ ฝันกลางวัน หรือสมาธิระดับลึก สัมพันธ์กับความสามารถในการจดจำและความคิดสร้างสรรค์ครับ';
    }
    if (lowerMessage.contains('delta') || lowerMessage.contains('เดลตา')) {
      return 'คลื่น Delta (0.5-4 Hz) เป็นคลื่นที่เด่นชัดในระหว่างการนอนหลับลึกโดยไม่มีความฝัน มีความสำคัญอย่างยิ่งต่อการฟื้นฟูซ่อมแซมร่างกายและเสริมสร้างระบบภูมิคุ้มกันครับ';
    }
    if (lowerMessage.contains('นอน') || lowerMessage.contains('หลับ')) {
      return 'เพื่อการนอนหลับที่ดี แนะนำให้เข้านอนและตื่นเวลาเดิมทุกวัน งดดื่มคาเฟอีนหลังช่วงบ่าย หลีกเลี่ยงการใช้งานหน้าจอก่อนนอนอย่างน้อย 1 ชั่วโมง และทำกิจกรรมผ่อนคลายเพื่อกระตุ้นคลื่น Delta และ Alpha ครับ';
    }
    if (lowerMessage.contains('เครียด') || lowerMessage.contains('กังวล')) {
      return 'เมื่อเผชิญกับสภาวะเครียด แนะนำให้ทำกิจกรรมผ่อนคลายสั้นๆ เช่น การฝึกหายใจแบบ 4-7-8 นั่งสมาธิเบื้องต้น 5-10 นาทีเพื่อกระตุ้นคลื่น Alpha หรือลุกขึ้นยืดเส้นยืดสายออกกำลังกายเบาๆ เพื่อลดฮอร์โมนความเครียดครับ';
    }
    if (lowerMessage.contains('คลื่นสมอง') || lowerMessage.contains('brainwave')) {
      return 'คลื่นสมองของมนุษย์มี 5 ประเภทหลัก: Delta (นอนหลับลึก), Theta (ผ่อนคลายลึก/ครุ่นคิด), Alpha (ผ่อนคลายอย่างสงบ), Beta (ตื่นตัวทำงาน/คิดวิเคราะห์) และ Gamma (การประมวลผลข้อมูลระดับสูงและสมาธิขั้นสูง) ครับ';
    }

    return 'สวัสดีครับ ผมสมาร์ทเบรน AI พร้อมให้คำปรึกษาเชิงวิชาการด้านคลื่นสมองและสุขภาพจิต คุณสามารถถามคำถามเกี่ยวกับ คลื่นสมองแต่ละชนิด, ความเครียด, การนอนหลับ หรือข้อมูลโครงงาน SmartBrain Care (เช่น วัตถุประสงค์ ขั้นตอนการทำงาน จุดเด่น และ TRL/SRL) ได้เลยครับ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                  // Clean Header Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.psychology_outlined,
                            color: AppColors.primaryBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'สมาร์ทเบรน AI',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                _isVoiceMode ? '🎤 กำลังฟัง...' : 'ผู้เชี่ยวชาญคลื่นสมอง',
                                style: TextStyle(
                                  color: _isVoiceMode ? AppColors.error : AppColors.textGray,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Volume toggle
                        IconButton(
                          onPressed: () {
                            setState(() => _autoSpeak = !_autoSpeak);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(_autoSpeak ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_autoSpeak ? 'เปิดพูดอัตโนมัติ 🔊' : 'ปิดพูดอัตโนมัติ 🔇'),
                                  ],
                                ),
                                duration: const Duration(seconds: 1),
                                backgroundColor: _autoSpeak ? Colors.green : Colors.grey,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          icon: Icon(
                            _autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            color: _autoSpeak ? AppColors.primaryBlue : AppColors.textLight,
                          ),
                        ),
                        // Settings
                        GestureDetector(
                          onTap: () {
                            if (widget.user != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user!)),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: AppTheme.glassDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.settings_outlined,
                              color: AppColors.textDark,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message, index);
                    },
                  ),
                ),

                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.psychology, color: AppColors.primaryBlue, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'สมาร์ทเบรน กำลังคิด...',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_isVoiceMode) _buildVoiceListeningBar(),

                if (_suggestedQuestions.isNotEmpty && !_isSending && !_isVoiceMode) ...[
                  const SizedBox(height: 4),
                  _buildSuggestedQuestionsArea(),
                ],

                const SizedBox(height: 8),

                _buildInputArea(),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildVoiceListeningBar() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withValues(alpha: 0.1),
                Colors.orange.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [

              AnimatedBuilder(
                animation: _micPulseController,
                builder: (context, child) {
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(
                        alpha: 0.3 + (_micPulseController.value * 0.4),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.red, size: 20),
                  );
                },
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _partialText.isNotEmpty ? _partialText : 'กำลังฟัง... พูดได้เลย',
                      style: TextStyle(
                        color: _partialText.isNotEmpty ? Colors.black87 : Colors.grey[600],
                        fontSize: 14,
                        fontWeight: _partialText.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_partialText.isEmpty)
                      Row(
                        children: List.generate(5, (i) =>
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              final height = 4.0 + (8.0 * _waveController.value * (i % 2 == 0 ? 1 : 0.5));
                              return Container(
                                width: 3,
                                height: height,
                                margin: const EdgeInsets.only(right: 3, top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: () async {
                  await _sttService.cancelListening();
                  setState(() {
                    _isVoiceMode = false;
                    _partialText = '';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
      decoration: AppTheme.glassDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        opacity: 0.75,
      ),
      child: Row(
        children: [

          GestureDetector(
            onTap: _isSending ? null : _toggleVoiceInput,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isVoiceMode
                    ? Colors.red
                    : AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: _isVoiceMode ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Icon(
                _isVoiceMode ? Icons.mic : Icons.mic_none,
                color: _isVoiceMode ? Colors.white : AppColors.primaryBlue,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: AppTheme.glassDecoration(
                color: AppColors.bgBlue,
                opacity: 0.5,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'พิมพ์หรือกดไมค์เพื่อพูด...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _isSending ? null : AppGradients.primaryBlue,
                color: _isSending ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
                boxShadow: _isSending ? [] : [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isSpeaking = _speakingMessageIndex == index;

    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: message.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: message.isBot
                  ? AppTheme.glassDecoration(
                      borderRadius: BorderRadius.circular(24).copyWith(
                        bottomLeft: const Radius.circular(6),
                      ),
                    )
                  : AppTheme.glassDecoration(
                      color: AppColors.primaryBlue,
                      opacity: 0.18,
                      borderColor: AppColors.primaryBlue.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24).copyWith(
                        bottomRight: const Radius.circular(6),
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (message.isBot && message.text.contains('🤖 กำลังนำคุณไปยังหน้า')) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Widget dest;
                        if (message.text.contains('หน้าเกมเสริมทักษะ')) {
                          dest = MiniGamesScreen(user: widget.user);
                        } else if (message.text.contains('แบบประเมินสุขภาพจิต PHQ-9')) {
                          dest = TestScreen(user: widget.user);
                        } else if (message.text.contains('ระบบผู้ดูแลและสายด่วนฉุกเฉิน')) {
                          if (widget.user != null && widget.user!.role == 'caretaker') {
                            dest = CaregiverDashboardScreen(user: widget.user!);
                          } else {
                            dest = const CaretakerScreen();
                          }
                        } else if (message.text.contains('คำแนะนำโภชนาการ')) {
                          dest = const NutritionScreen();
                        } else if (message.text.contains('รายงานสรุปประจำสัปดาห์')) {
                          dest = WeeklyReportScreen(user: widget.user);
                        } else {
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => dest),
                        );
                      },
                      icon: const Icon(Icons.rocket_launch, size: 16, color: Colors.white),
                      label: const Text('ไปทันที', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),

                if (message.isBot) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _speakMessage(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSpeaking
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: isSpeaking
                            ? Border.all(color: Colors.green.withValues(alpha: 0.5))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpeaking ? Icons.stop_circle : Icons.volume_up,
                            size: 16,
                            color: isSpeaking ? Colors.green : Colors.grey[500],
                          ),
                          if (isSpeaking) ...[
                            const SizedBox(width: 4),
                            Text(
                              'กำลังพูด',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isBot;
  final String time;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.time,
  });
}
