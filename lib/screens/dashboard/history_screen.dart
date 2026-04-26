import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import 'settings_screen.dart';

class HistoryScreen extends StatefulWidget {
  final User? user;

  const HistoryScreen({super.key, this.user});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _testHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await ApiService.getTestResults(widget.user!.id);

    if (result['success'] == true && result['results'] != null) {
      setState(() {
        _testHistory = List<Map<String, dynamic>>.from(result['results']);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
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
          'ประวัติ',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ประวัติการทดสอบ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_testHistory.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('ยังไม่มีประวัติการทดสอบ'),
                      ),
                    )
                  else
                    ..._testHistory.map((test) {
                      final stressLevel = test['stress_level'] ?? 'normal';
                      String result;
                      Color color;

                      switch (stressLevel) {
                        case 'mild':
                          result = 'เครียดเล็กน้อย';
                          color = Colors.orange;
                          break;
                        case 'moderate':
                          result = 'เครียดปานกลาง';
                          color = Colors.deepOrange;
                          break;
                        case 'high':
                          result = 'เครียดมาก';
                          color = Colors.red;
                          break;
                        default:
                          result = 'ปกติ';
                          color = Colors.green;
                      }

                      return _buildHistoryItem(
                        date: test['test_date']?.toString().substring(0, 10) ?? '',
                        result: result,
                        color: color,
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildHistoryItem({
    required String date,
    required String result,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'ผลการทดสอบ: $result',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
