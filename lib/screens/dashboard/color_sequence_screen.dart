import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

/// ColorSequenceScreen คือหน้าจอมินิเกมฝึกความจำสีตามลำดับ (Color Sequence Memory Game)
/// ระบบจะแสดงลำดับสีทีละสีให้ผู้ใช้ดู แล้วให้กดตามลำดับที่ถูกต้องเพื่อพัฒนาทักษะความจำระดับสมอง
class ColorSequenceScreen extends StatefulWidget {
  final User? user;

  const ColorSequenceScreen({super.key, this.user});

  @override
  State<ColorSequenceScreen> createState() => _ColorSequenceScreenState();
}

class _ColorSequenceScreenState extends State<ColorSequenceScreen> {
  final List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow]; // กลุ่มสีมาตรฐานที่นำมาใช้ทดสอบ
  List<int> sequence = [];           // ลำดับดัชนีสีที่ระบบสุ่มขึ้นมาทีละเลเวล
  List<int> playerInput = [];        // ลำดับดัชนีสีที่ผู้เล่นป้อนเข้ามาจริง
  int level = 1;                     // ระดับเลเวลความยากปัจจุบัน
  bool isShowingSequence = false;    // บอกว่าระบบกำลังเล่นลำดับสีแสงไฟให้ดูอยู่หรือไม่
  int currentShowIndex = -1;         // ดัชนีปุ่มไฟสีที่กำลังแสดงเอฟเฟกต์กระพริบ
  bool gameOver = false;             // ตรวจสอบว่าแพ้หรือจบเกมการเล่นไปแล้วหรือยัง
  DateTime? _startTime;              // บันทึกเวลาที่เริ่มต้นเล่นเกมเพื่อสรุปผลเวลารวม

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    sequence = [];
    playerInput = [];
    level = 1;
    gameOver = false;
    _startTime = DateTime.now();
    _addToSequence();
  }

  void _addToSequence() {
    sequence.add(Random().nextInt(4));
    playerInput = [];
    _showSequence();
  }

  void _showSequence() async {
    setState(() {
      isShowingSequence = true;
      currentShowIndex = -1;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < sequence.length; i++) {
      if (!mounted) return;
      setState(() => currentShowIndex = sequence[i]);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => currentShowIndex = -1);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      setState(() => isShowingSequence = false);
    }
  }

  void _onColorTap(int colorIndex) {
    if (isShowingSequence || gameOver) return;

    setState(() {
      playerInput.add(colorIndex);
    });

    if (playerInput[playerInput.length - 1] != sequence[playerInput.length - 1]) {
      setState(() => gameOver = true);
      _showGameOver();
      return;
    }

    if (playerInput.length == sequence.length) {
      setState(() => level++);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _addToSequence();
      });
    }
  }

  Future<void> _showGameOver() async {
    final duration = DateTime.now().difference(_startTime!).inMinutes;

    if (widget.user != null) {
      await ApiService.saveActivity(
        userId: widget.user!.id,
        activityType: 'game',
        activityName: 'จำสี',
        score: level * 10,
        durationMinutes: duration > 0 ? duration : 1,
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('😅 เกมจบ!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('คุณกดผิดลำดับ', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('คะแนน: Level $level', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _startGame());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('เล่นอีกครั้ง', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
          'เกมจำสี',
          style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Level: $level',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            Text(
              isShowingSequence ? 'จดจำลำดับสี...' : 'กดตามลำดับ!',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                children: List.generate(4, (index) {
                  final isHighlighted = currentShowIndex == index;
                  return GestureDetector(
                    onTap: () => _onColorTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isHighlighted ? colors[index] : colors[index].withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isHighlighted
                            ? [
                                BoxShadow(
                                  color: colors[index].withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                playerInput.length.clamp(0, 10),
                (index) => Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors[playerInput[index]],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _startGame()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('เริ่มใหม่', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
