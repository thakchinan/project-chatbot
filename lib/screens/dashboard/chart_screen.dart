import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import 'settings_screen.dart';

class ChartScreen extends StatefulWidget {
  final User? user;

  const ChartScreen({super.key, this.user});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<double> _weeklyData = [45, 70, 85, 60];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await ApiService.getTestResults(widget.user!.id);

    if (result['success'] == true && result['results'] != null) {
      final results = result['results'] as List;
      if (results.isNotEmpty) {
        final data = results.take(4).map((r) {
          return (r['stress_score'] as num?)?.toDouble() ?? 0;
        }).toList();

        setState(() {
          _weeklyData = data.map((s) => (s / 12 * 100).clamp(0.0, 100.0).toDouble()).toList();
          while (_weeklyData.length < 4) {
            _weeklyData.add(0);
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
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
          'แผนภูมิ',
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

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 100,
                              barTouchData: BarTouchData(enabled: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      const labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
                                      if (value.toInt() < labels.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            labels[value.toInt()],
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 10,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: FlGridData(show: false),
                              barGroups: [
                                _buildBarGroup(0, _weeklyData.isNotEmpty ? _weeklyData[0] : 0, Colors.blue),
                                _buildBarGroup(1, _weeklyData.length > 1 ? _weeklyData[1] : 0, Colors.red),
                                _buildBarGroup(2, _weeklyData.length > 2 ? _weeklyData[2] : 0, Colors.green),
                                _buildBarGroup(3, _weeklyData.length > 3 ? _weeklyData[3] : 0, Colors.orange),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildLegend('Alpha', Colors.blue),
                      _buildLegend('Beta', Colors.red),
                      _buildLegend('Theta', Colors.green),
                      _buildLegend('Delta', Colors.orange),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Text(
                    'สรุปผลรายสัปดาห์',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'ค่าเฉลี่ย',
                          '${_weeklyData.isNotEmpty ? (_weeklyData.reduce((a, b) => a + b) / _weeklyData.length).round() : 0}%',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'สูงสุด',
                          '${_weeklyData.isNotEmpty ? _weeklyData.reduce((a, b) => a > b ? a : b).round() : 0}%',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'ต่ำสุด',
                          '${_weeklyData.isNotEmpty ? _weeklyData.reduce((a, b) => a < b ? a : b).round() : 0}%',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 30,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
