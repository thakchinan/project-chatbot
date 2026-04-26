import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import 'settings_screen.dart';

class TestScreen extends StatefulWidget {
  final User? user;

  const TestScreen({super.key, this.user});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with SingleTickerProviderStateMixin {
  bool _hasStarted = false;
  int _currentQuestion = 0;
  List<int> _answers = [];
  int? _selectedAnswer;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const String _phq9Instruction =
    'ในช่วง 2 สัปดาห์ที่ผ่านมา คุณได้รับความเดือดร้อนจากปัญหาต่อไปนี้ มากน้อยเพียงใด';

  static const List<String> _answerOptions = [
    'ไม่เลย',
    'หลายวัน',
    'มากกว่าครึ่งหนึ่งของวัน',
    'เกือบทุกวัน',
  ];

  static const List<Map<String, String>> _phq9Questions = [
    {
      'question': 'รู้สึกเบื่อ ไม่สนใจอยากทำอะไร',
      'en': 'Little interest or pleasure in doing things',
    },
    {
      'question': 'รู้สึกหดหู่ ท้อแท้ หรือสิ้นหวัง',
      'en': 'Feeling down, depressed, or hopeless',
    },
    {
      'question': 'นอนไม่หลับ หรือหลับมากเกินไป',
      'en': 'Trouble falling or staying asleep, or sleeping too much',
    },
    {
      'question': 'รู้สึกเหนื่อย ไม่มีแรง หรืออ่อนเพลีย',
      'en': 'Feeling tired or having little energy',
    },
    {
      'question': 'เบื่ออาหาร หรือกินมากเกินไป',
      'en': 'Poor appetite or overeating',
    },
    {
      'question': 'รู้สึกไม่ดีกับตัวเอง คิดว่าตัวเองล้มเหลว\nหรือทำให้ตัวเองหรือครอบครัวผิดหวัง',
      'en': 'Feeling bad about yourself — or that you are a failure\nor have let yourself or your family down',
    },
    {
      'question': 'ไม่มีสมาธิในการทำสิ่งต่างๆ เช่น อ่านหนังสือ\nหรือดูโทรทัศน์',
      'en': 'Trouble concentrating on things, such as reading\nthe newspaper or watching television',
    },
    {
      'question': 'พูดหรือเคลื่อนไหวช้าจนคนอื่นสังเกตเห็น\nหรือกระสับกระส่ายจนอยู่ไม่นิ่งมากกว่าปกติ',
      'en': 'Moving or speaking so slowly that other people could\nhave noticed? Or the opposite — being fidgety or restless',
    },
    {
      'question': 'คิดว่าตัวเองตายไปจะดีกว่า หรือคิดจะ\nทำร้ายตัวเอง',
      'en': 'Thoughts that you would be better off dead\nor of hurting yourself in some way',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _hasStarted = true;
      _currentQuestion = 0;
      _answers = [];
      _selectedAnswer = null;
    });
    _animController.reset();
    _animController.forward();
  }

  void _selectAnswer(int score) {
    setState(() {
      _selectedAnswer = score;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _answers.add(score);
        _selectedAnswer = null;
      });

      if (_currentQuestion < _phq9Questions.length - 1) {
        _animController.reset();
        _animController.forward();
        setState(() {
          _currentQuestion++;
        });
      } else {
        _showResults();
      }
    });
  }

  Map<String, dynamic> _interpretScore(int totalScore) {
    if (totalScore <= 4) {
      return {
        'level': 'ปกติ / น้อยมาก',
        'levelEn': 'Minimal Depression',
        'stressLevel': 'normal',
        'color': const Color(0xFF4CAF50),
        'icon': Icons.sentiment_very_satisfied,
        'recommendation': 'ไม่พบอาการซึมเศร้า สุขภาพจิตของคุณอยู่ในเกณฑ์ดี',
        'action': 'ดูแลสุขภาพกายใจเช่นเดิม ออกกำลังกาย นอนหลับพักผ่อนให้เพียงพอ',
      };
    } else if (totalScore <= 9) {
      return {
        'level': 'ซึมเศร้าเล็กน้อย',
        'levelEn': 'Mild Depression',
        'stressLevel': 'mild',
        'color': const Color(0xFFFFC107),
        'icon': Icons.sentiment_satisfied,
        'recommendation': 'มีอาการซึมเศร้าเล็กน้อย ควรเฝ้าระวังและติดตามอาการ',
        'action': 'แนะนำให้ทำกิจกรรมที่ชอบ ออกกำลังกาย พูดคุยกับคนใกล้ชิด',
      };
    } else if (totalScore <= 14) {
      return {
        'level': 'ซึมเศร้าปานกลาง',
        'levelEn': 'Moderate Depression',
        'stressLevel': 'moderate',
        'color': const Color(0xFFFF9800),
        'icon': Icons.sentiment_neutral,
        'recommendation': 'มีอาการซึมเศร้าปานกลาง ควรปรึกษาผู้เชี่ยวชาญ',
        'action': 'ควรพบแพทย์หรือนักจิตวิทยาเพื่อวางแผนการดูแลรักษา',
      };
    } else if (totalScore <= 19) {
      return {
        'level': 'ซึมเศร้าค่อนข้างรุนแรง',
        'levelEn': 'Moderately Severe Depression',
        'stressLevel': 'high',
        'color': const Color(0xFFFF5722),
        'icon': Icons.sentiment_dissatisfied,
        'recommendation': 'มีอาการซึมเศร้าค่อนข้างรุนแรง จำเป็นต้องได้รับการดูแล',
        'action': 'ควรพบจิตแพทย์โดยเร็ว เพื่อรับการรักษาที่เหมาะสม',
      };
    } else {
      return {
        'level': 'ซึมเศร้ารุนแรง',
        'levelEn': 'Severe Depression',
        'stressLevel': 'severe',
        'color': const Color(0xFFF44336),
        'icon': Icons.sentiment_very_dissatisfied,
        'recommendation': 'มีอาการซึมเศร้าระดับรุนแรง ต้องได้รับการรักษาทันที',
        'action': 'กรุณาพบจิตแพทย์โดยด่วน สายด่วนสุขภาพจิต 1323',
      };
    }
  }

  Future<void> _showResults() async {
    final totalScore = _answers.reduce((a, b) => a + b);
    final maxScore = _phq9Questions.length * 3;
    final interpretation = _interpretScore(totalScore);

    if (widget.user != null) {
      final saveResult = await ApiService.saveTestResult(
        userId: widget.user!.id,
        stressScore: totalScore,
        depressionScore: totalScore,
        stressLevel: interpretation['stressLevel'],
      );
      print('💾 [TestScreen] saveTestResult: $saveResult');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResultSheet(totalScore, maxScore, interpretation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _hasStarted ? 'แบบประเมิน PHQ-9' : 'แบบทดสอบ',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (widget.user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user!)),
                );
              }
            },
            icon: Icon(Icons.settings, color: AppColors.primaryBlue),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _hasStarted ? _buildQuiz() : _buildStart(),
      ),
    );
  }

  Widget _buildStart() {
    return SingleChildScrollView(
      child: Column(
        children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PHQ-9',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patient Health Questionnaire-9',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'แบบประเมินภาวะซึมเศร้ามาตรฐานสากล',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'เกี่ยวกับแบบทดสอบ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('📋', 'จำนวนคำถาม: 9 ข้อ'),
                _buildInfoRow('⏱️', 'ใช้เวลา: ประมาณ 2-3 นาที'),
                _buildInfoRow('📊', 'คะแนนเต็ม: 27 คะแนน'),
                _buildInfoRow('🏥', 'มาตรฐาน: WHO / APA'),
                const SizedBox(height: 8),
                Text(
                  'แบบทดสอบนี้ใช้เป็นเครื่องมือคัดกรองเบื้องต้น ไม่สามารถใช้วินิจฉัยโรคได้',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เกณฑ์ประเมินผล',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildScoreRange('0-4', 'ปกติ', const Color(0xFF4CAF50)),
                _buildScoreRange('5-9', 'ซึมเศร้าเล็กน้อย', const Color(0xFFFFC107)),
                _buildScoreRange('10-14', 'ซึมเศร้าปานกลาง', const Color(0xFFFF9800)),
                _buildScoreRange('15-19', 'ค่อนข้างรุนแรง', const Color(0xFFFF5722)),
                _buildScoreRange('20-27', 'รุนแรง', const Color(0xFFF44336)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
                shadowColor: AppColors.primaryBlue.withOpacity(0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'เริ่มทำแบบประเมิน',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildScoreRange(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 45,
            child: Text(
              range,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz() {
    final question = _phq9Questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _phq9Questions.length;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Text(
                  'ข้อ ${_currentQuestion + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                Text(
                  ' / ${_phq9Questions.length}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _phq9Instruction,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question['question']!,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    question['en']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            ...List.generate(_answerOptions.length, (index) {
              final isSelected = _selectedAnswer == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: isSelected
                    ? AppColors.primaryBlue.withOpacity(0.1)
                    : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _selectAnswer(index),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                ? AppColors.primaryBlue
                                : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$index',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _answerOptions[index],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: AppColors.primaryBlue, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            if (_currentQuestion == 8)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_in_talk, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'หากคุณมีความคิดทำร้ายตัวเอง กรุณาโทรสายด่วนสุขภาพจิต 1323 ตลอด 24 ชม.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSheet(int totalScore, int maxScore, Map<String, dynamic> interpretation) {
    final Color resultColor = interpretation['color'];
    final IconData resultIcon = interpretation['icon'];
    final double percentage = totalScore / maxScore;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(resultIcon, size: 50, color: resultColor),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ผลประเมิน PHQ-9',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              interpretation['level'],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: resultColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              interpretation['levelEn'],
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$totalScore',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: resultColor,
                        ),
                      ),
                      Text(
                        ' / $maxScore',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(resultColor),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: resultColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_hospital_outlined, color: resultColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'การประเมิน',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: resultColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    interpretation['recommendation'],
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: resultColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'สิ่งที่ควรทำ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: resultColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    interpretation['action'],
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            if (widget.user != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_done, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'บันทึกผลลง Supabase แล้ว',
                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                  ),
                ],
              ),
            ],

            if (totalScore >= 15) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สายด่วนสุขภาพจิต',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                          Text(
                            '1323 (24 ชม.) · สมาริตันส์ 02-713-6793',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('ปิด', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startTest();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ทดสอบอีกครั้ง',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
