import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class CheckersGameScreen extends StatefulWidget {
  final User? user;

  const CheckersGameScreen({super.key, this.user});

  @override
  State<CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<CheckersGameScreen> {

  List<List<int>> board = [];
  int? selectedRow;
  int? selectedCol;
  bool isBlackTurn = true;
  int moveCount = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initBoard();
    _startTime = DateTime.now();
  }

  void _initBoard() {
    board = List.generate(8, (row) {
      return List.generate(8, (col) {
        if ((row + col) % 2 == 1) {
          if (row < 3) return 2;
          if (row > 4) return 1;
        }
        return 0;
      });
    });
    selectedRow = null;
    selectedCol = null;
    isBlackTurn = true;
    moveCount = 0;
    _startTime = DateTime.now();
  }

  void _onCellTap(int row, int col) {

    if ((row + col) % 2 == 0) return;

    final piece = board[row][col];

    if (piece != 0) {
      if ((isBlackTurn && piece == 1) || (!isBlackTurn && piece == 2)) {
        setState(() {
          selectedRow = row;
          selectedCol = col;
        });
      }
      return;
    }

    if (selectedRow != null && selectedCol != null) {
      final selectedPiece = board[selectedRow!][selectedCol!];
      final rowDiff = row - selectedRow!;
      final colDiff = (col - selectedCol!).abs();

      bool validMove = false;
      if (colDiff == 1) {
        if (selectedPiece == 1 && rowDiff == -1) validMove = true;
        if (selectedPiece == 2 && rowDiff == 1) validMove = true;
      }

      if (colDiff == 2 && rowDiff.abs() == 2) {
        final midRow = (selectedRow! + row) ~/ 2;
        final midCol = (selectedCol! + col) ~/ 2;
        final midPiece = board[midRow][midCol];

        if (midPiece != 0 && midPiece != selectedPiece) {
          if ((selectedPiece == 1 && rowDiff == -2) || (selectedPiece == 2 && rowDiff == 2)) {
            validMove = true;

            setState(() {
              board[midRow][midCol] = 0;
            });

            _checkWin();
          }
        }
      }

      if (validMove) {
        setState(() {
          board[row][col] = selectedPiece;
          board[selectedRow!][selectedCol!] = 0;
          selectedRow = null;
          selectedCol = null;
          isBlackTurn = !isBlackTurn;
          moveCount++;
        });
      }
    }
  }

  void _checkWin() {
    int blackCount = 0;
    int whiteCount = 0;

    for (var row in board) {
      for (var cell in row) {
        if (cell == 1) blackCount++;
        if (cell == 2) whiteCount++;
      }
    }

    if (blackCount == 0 || whiteCount == 0) {
      final winner = blackCount == 0 ? 'ขาว' : 'ดำ';
      _showGameOver(winner);
    }
  }

  Future<void> _showGameOver(String winner) async {
    final duration = DateTime.now().difference(_startTime!).inMinutes;

    if (widget.user != null) {
      await ApiService.saveActivity(
        userId: widget.user!.id,
        activityType: 'game',
        activityName: 'หมากฮอส',
        score: moveCount,
        durationMinutes: duration > 0 ? duration : 1,
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('🎉 เกมจบแล้ว!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ฝ่าย$winner ชนะ!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text('จำนวนการเดิน: $moveCount'),
            if (widget.user != null) ...[
              const SizedBox(height: 8),
              const Text(
                '✓ บันทึกกิจกรรมแล้ว',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _initBoard();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
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
          'หมากฮอส',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings, color: AppColors.primaryBlue),
          ),
        ],
      ),
      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isBlackTurn ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isBlackTurn ? 'ตาฝ่ายดำ' : 'ตาฝ่ายขาว',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                Text(
                  'การเดิน: $moveCount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.brown, width: 4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                    ),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      final row = index ~/ 8;
                      final col = index % 8;
                      final isLight = (row + col) % 2 == 0;
                      final piece = board[row][col];
                      final isSelected = row == selectedRow && col == selectedCol;

                      return GestureDetector(
                        onTap: () => _onCellTap(row, col),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.withValues(alpha: 0.5)
                                : (isLight ? const Color(0xFFFFE4C4) : const Color(0xFF8B4513)),
                          ),
                          child: piece != 0
                              ? Center(
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: piece == 1 ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: piece == 1 ? Colors.grey : Colors.black,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _initBoard();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'เริ่มใหม่',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
