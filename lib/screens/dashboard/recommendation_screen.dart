import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/tts_service.dart';
import '../../services/stt_service.dart';
import 'settings_screen.dart';
import 'mini_games_screen.dart';
import 'test_screen.dart';
import 'nutrition_screen.dart';
import 'weekly_report_screen.dart';

/// RecommendationScreen เป็นหน้าจอให้คำปรึกษา แชทบอท และข้อเสนอแนะอัจฉริยะ (สมาร์ทเบรน AI)
/// รองรับการพูดโต้ตอบด้วยเสียง (Speech-to-Text & Text-to-Speech)
/// มีระบบคำถามลัด คำถามเจาะลึก แนะนำกิจกรรม นำทางหน้าเมนูอัตโนมัติ และ RAG Context
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
      ];
    } else if (text.contains('เกม') || text.contains('game') || text.contains('เล่น')) {
      final topic = phrase.isNotEmpty ? phrase : 'เกมเสริมทักษะ';
      suggestions = [
        'เปิดหน้า $topic ให้ฉันหน่อย',
        'ประโยชน์ของ $topic ต่อความจำ',
        'คะแนนสถิติสูงสุดในการเล่น $topic',
        'มี $topic แบบอื่นแนะนำอีกไหม?'
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: AppColors.primaryBlue, size: 16),
              const SizedBox(width: 8),
              Text(
                'คำถามแนะนำเพื่อเจาะลึก:',
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGray,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _suggestedQuestions.map((question) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: GestureDetector(
                    onTap: () => _onSuggestionTap(question),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white,
                        opacity: 0.9,
                        borderColor: AppColors.primaryBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            question,
                            style: GoogleFonts.prompt(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
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
                  // Clinic-Grade AI Telemetry Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        // Pulsing Hexagon AI Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AppTheme.glassDecoration(
                            color: AppColors.primaryBlue,
                            opacity: 0.1,
                            borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.psychology_outlined,
                                color: AppColors.primaryBlue,
                                size: 26,
                              ),
                              // Small Pulse Online Indicator
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isVoiceMode ? AppColors.error : AppColors.neonGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isVoiceMode ? AppColors.error : AppColors.neonGreen).withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'สมาร์ทเบรน AI',
                                    style: GoogleFonts.prompt(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (_isVoiceMode ? AppColors.error : AppColors.primaryGreen).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: (_isVoiceMode ? AppColors.error : AppColors.primaryGreen).withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _isVoiceMode ? 'LISTENING' : 'ONLINE',
                                      style: GoogleFonts.prompt(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: _isVoiceMode ? AppColors.error : AppColors.primaryGreen,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _isVoiceMode ? 'กำลังประมวลผลสัญญาณเสียง...' : 'ระบบวิเคราะห์สภาวะจิตใจและคลื่นสมอง',
                                style: GoogleFonts.prompt(
                                  color: _isVoiceMode ? AppColors.error : AppColors.textGray,
                                  fontSize: 12,
                                  fontWeight: _isVoiceMode ? FontWeight.w600 : FontWeight.w400,
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
                                backgroundColor: _autoSpeak ? AppColors.primaryGreen : AppColors.textGray,
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
                              color: Colors.white,
                              opacity: 0.8,
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: AppTheme.glassDecoration(
            color: AppColors.deepSpaceBlue,
            opacity: 0.9,
            borderColor: AppColors.electricCyan.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _micPulseController,
                builder: (context, child) {
                  return Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.electricCyan.withValues(
                        alpha: 0.2 + (_micPulseController.value * 0.3),
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.electricCyan.withValues(
                            alpha: 0.2 * _micPulseController.value,
                          ),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic, color: AppColors.electricCyan, size: 20),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _partialText.isNotEmpty ? _partialText : 'กำลังรับสัญญาณเสียง... พูดได้เลย',
                      style: GoogleFonts.prompt(
                        color: _partialText.isNotEmpty ? Colors.white : AppColors.textLight,
                        fontSize: 13.5,
                        fontWeight: _partialText.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (_partialText.isEmpty)
                      Row(
                        children: List.generate(8, (i) =>
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              final height = 4.0 + (12.0 * _waveController.value * (i % 3 == 0 ? 1.0 : (i % 3 == 1 ? 0.6 : 0.3)));
                              return Container(
                                width: 3,
                                height: height,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: (i % 2 == 0 ? AppColors.electricCyan : AppColors.neonGreen).withValues(alpha: 0.8),
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
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
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
      padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 24),
      decoration: AppTheme.glassDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        opacity: 0.9,
        borderColor: Colors.white.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          // Voice Input Mic Button
          GestureDetector(
            onTap: _isSending ? null : _toggleVoiceInput,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isVoiceMode
                    ? AppColors.electricCyan
                    : AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: _isVoiceMode ? [
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Icon(
                _isVoiceMode ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isVoiceMode ? Colors.black87 : AppColors.primaryBlue,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Message Input Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              height: 48,
              alignment: Alignment.center,
              decoration: AppTheme.glassDecoration(
                color: AppColors.bgBlue,
                opacity: 0.6,
                borderColor: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.prompt(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อมูลหรือสั่งงานด้วยเสียง...',
                  hintStyle: GoogleFonts.prompt(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send Message Button
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isSending ? null : AppGradients.primaryBlue,
                color: _isSending ? Colors.grey.shade300 : null,
                shape: BoxShape.circle,
                boxShadow: _isSending ? [] : [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: message.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Message Bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: message.isBot
                  ? AppTheme.glassDecoration(
                      color: Colors.white,
                      opacity: 0.9,
                      borderColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                      ),
                    )
                  : AppTheme.glassDecoration(
                      color: AppColors.primaryBlue,
                      opacity: 0.9,
                      borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bot label
                  if (message.isBot) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.android_rounded, size: 12, color: AppColors.primaryGreen),
                        const SizedBox(width: 4),
                        Text(
                          'AI CLINICAL ADVISOR',
                          style: GoogleFonts.prompt(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    message.text,
                    style: GoogleFonts.prompt(
                      color: message.isBot ? AppColors.textDark : Colors.white,
                      fontSize: 14.5,
                      height: 1.55,
                      fontWeight: message.isBot ? FontWeight.w500 : FontWeight.w500,
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
                      icon: const Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
                      label: Text(
                        'ไปทันที',
                        style: GoogleFonts.prompt(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Message Metadata (Time and TTS trigger)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.time,
                    style: GoogleFonts.prompt(
                      color: AppColors.textLight,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (message.isBot) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _speakMessage(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSpeaking
                              ? AppColors.primaryGreen.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: isSpeaking
                              ? Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4), width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                              size: 14,
                              color: isSpeaking ? AppColors.primaryGreen : AppColors.textLight,
                            ),
                            if (isSpeaking) ...[
                              const SizedBox(width: 4),
                              Text(
                                'กำลังอ่านออกเสียง',
                                style: GoogleFonts.prompt(
                                  fontSize: 9,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
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
