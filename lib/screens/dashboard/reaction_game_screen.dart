import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

/// ReactionGameScreen คือหน้าจอมินิเกมทดสอบปฏิกิริยาการตอบสนอง (Reaction Time Game)
/// สุ่มสีของหน้าจอให้เปลี่ยนเป็นสีเขียว แล้ววัดความเร็วหน่วยมิลลิวินาที (ms) ที่ผู้เล่นกดแตะตอบสนองความเร็วปฏิกิริยาของสมอง
class ReactionGameScreen extends StatefulWidget {
  final User? user;

  const ReactionGameScreen({super.key, this.user});

  @override
  State<ReactionGameScreen> createState() => _ReactionGameScreenState();
}

class _ReactionGameScreenState extends State<ReactionGameScreen> {
  int score = 0;
  int round = 0;
  int maxRounds = 5;
  bool isWaiting = false;
  bool isReady = false;
  bool tooEarly = false;
  DateTime? showTime;
  int? reactionTime;
  List<int> reactionTimes = [];
  Timer? waitTimer;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    waitTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (round >= maxRounds) {
      _showResults();
      return;
    }

    setState(() {
      isWaiting = true;
      isReady = false;
      tooEarly = false;
      reactionTime = null;
    });

    final waitDuration = Duration(milliseconds: 1500 + Random().nextInt(3000));

    waitTimer = Timer(waitDuration, () {
      if (mounted) {
        setState(() {
          isWaiting = false;
          isReady = true;
          showTime = DateTime.now();
        });
      }
    });
  }

  void _onTap() {
    if (!isWaiting && !isReady && round < maxRounds) {
      _startRound();
      return;
    }

    if (isWaiting) {
      waitTimer?.cancel();
      setState(() {
        tooEarly = true;
        isWaiting = false;
      });
      return;
    }

    if (isReady) {
      final now = DateTime.now();
      final reaction = now.difference(showTime!).inMilliseconds;
      reactionTimes.add(reaction);

      setState(() {
        reactionTime = reaction;
        isReady = false;
        round++;

        if (reaction < 300) {
          score += 30;
        } else if (reaction < 500) {
          score += 20;
        } else {
          score += 10;
        }
      });
    }
  }

  Future<void> _showResults() async {
    final avgReaction = reactionTimes.isNotEmpty
        ? (reactionTimes.reduce((a, b) => a + b) / reactionTimes.length).round()
        : 0;

    final duration = DateTime.now().difference(_startTime!).inMinutes;

    if (widget.user != null) {
      await ApiService.saveActivity(
        userId: widget.user!.id,
        activityType: 'game',
        activityName: 'ทดสอบปฏิกิริยา',
        score: score,
        durationMinutes: duration > 0 ? duration : 1,
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🏆 สรุปผล'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('คะแนน: $score', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
            const SizedBox(height: 8),
            Text('เวลาตอบสนองเฉลี่ย: ${avgReaction}ms'),
            const SizedBox(height: 4),
            Text(
              avgReaction < 300 ? '⚡ เร็วมาก!' : (avgReaction < 500 ? '✨ ดี!' : '💪 พยายามต่อไป!'),
              style: TextStyle(color: Colors.grey[600]),
            ),
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
              setState(() {
                score = 0;
                round = 0;
                reactionTimes = [];
                reactionTime = null;
                isWaiting = false;
                isReady = false;
                tooEarly = false;
                _startTime = DateTime.now();
              });
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
    Color bgColor;
    String text;

    if (tooEarly) {
      bgColor = Colors.red;
      text = '❌ เร็วไป!\nแตะเพื่อลองใหม่';
    } else if (isWaiting) {
      bgColor = Colors.orange;
      text = '⏳ รอ...\nอย่าแตะ!';
    } else if (isReady) {
      bgColor = Colors.green;
      text = '🟢 แตะเลย!';
    } else if (reactionTime != null) {
      bgColor = AppColors.primaryBlue;
      text = '⏱️ ${reactionTime}ms\n\nแตะเพื่อเล่นต่อ';
    } else {
      bgColor = AppColors.primaryBlue;
      text = '🎮 แตะเพื่อเริ่มเกม\n\nรอจนหน้าจอเป็นสีเขียว\nแล้วแตะให้เร็วที่สุด!';
    }

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
          'ทดสอบปฏิกิริยา',
          style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('รอบ: $round/$maxRounds', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                Text('คะแนน: $score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: _onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
