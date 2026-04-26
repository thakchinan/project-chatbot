import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class NumberPuzzleScreen extends StatefulWidget {
  final User? user;

  const NumberPuzzleScreen({super.key, this.user});

  @override
  State<NumberPuzzleScreen> createState() => _NumberPuzzleScreenState();
}

class _NumberPuzzleScreenState extends State<NumberPuzzleScreen> {
  List<int> tiles = [];
  int moves = 0;
  DateTime? _startTime;
  bool _hasWon = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    tiles = [1, 2, 3, 4, 5, 6, 7, 8, 0];
    moves = 0;
    _hasWon = false;
    _startTime = DateTime.now();
    _shuffleTiles();
  }

  void _shuffleTiles() {
    final random = Random();
    for (int i = 0; i < 50; i++) {
      final emptyIndex = tiles.indexOf(0);
      final possibleMoves = _getValidMoves(emptyIndex);
      if (possibleMoves.isNotEmpty) {
        final randomMove = possibleMoves[random.nextInt(possibleMoves.length)];
        final temp = tiles[emptyIndex];
        tiles[emptyIndex] = tiles[randomMove];
        tiles[randomMove] = temp;
      }
    }
    setState(() {});
  }

  List<int> _getValidMoves(int emptyIndex) {
    final List<int> validMoves = [];
    final row = emptyIndex ~/ 3;
    final col = emptyIndex % 3;

    if (row > 0) validMoves.add(emptyIndex - 3);
    if (row < 2) validMoves.add(emptyIndex + 3);
    if (col > 0) validMoves.add(emptyIndex - 1);
    if (col < 2) validMoves.add(emptyIndex + 1);

    return validMoves;
  }

  void _onTileTap(int tappedIndex) {
    if (_hasWon) return;

    final emptyIndex = tiles.indexOf(0);
    final validMoves = _getValidMoves(emptyIndex);

    if (validMoves.contains(tappedIndex)) {
      setState(() {
        tiles[emptyIndex] = tiles[tappedIndex];
        tiles[tappedIndex] = 0;
        moves++;
      });

      if (_checkWin()) {
        setState(() => _hasWon = true);
        _showWinDialog();
      }
    }
  }

  bool _checkWin() {
    for (int i = 0; i < 8; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles[8] == 0;
  }

  Future<void> _showWinDialog() async {
    final duration = DateTime.now().difference(_startTime!).inMinutes;

    if (widget.user != null) {
      await ApiService.saveActivity(
        userId: widget.user!.id,
        activityType: 'game',
        activityName: 'ปริศนาตัวเลข',
        score: (100 - moves).clamp(0, 100),
        durationMinutes: duration > 0 ? duration : 1,
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 ชนะแล้ว!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('คุณเรียงตัวเลขครบแล้ว!', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('จำนวนการเลื่อน: $moves ครั้ง', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('กลับ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _initGame());
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
    final screenHeight = MediaQuery.of(context).size.height;
    final puzzleSize = screenHeight < 700 ? 200.0 : 280.0;

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
          'ปริศนาตัวเลข',
          style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'การเลื่อน: $moves',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: puzzleSize,
                height: puzzleSize,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final tile = tiles[index];

                      if (tile == 0) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () => _onTileTap(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$tile',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('เป้าหมาย: ', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [1, 2, 3, 4, 5, 6, 7, 8, 0].map((n) {
                          return Container(
                            decoration: BoxDecoration(
                              color: n == 0 ? Colors.grey[300] : Colors.green,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Center(
                              child: Text(
                                n == 0 ? '' : '$n',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () => setState(() => _initGame()),
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                label: const Text('เริ่มใหม่', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
