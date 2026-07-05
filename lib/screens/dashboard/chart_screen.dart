import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import 'settings_screen.dart';

/// ChartScreen เป็นหน้าจอสำหรับแสดงแนวโน้มสถิติกราฟรายงานระดับความเครียดสะสมของผู้ใช้
/// ดึงสถิติย้อนหลังจากแบบทดสอบ PHQ-9 ล่าสุด 4 ครั้งมาแปลงเป็นเปอร์เซ็นต์และแสดงผลกราฟแท่ง (Bar Chart)
class ChartScreen extends StatefulWidget {
  final User? user;

  const ChartScreen({super.key, this.user});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  List<double> _weeklyData = [45, 70, 85, 60]; // ข้อมูลคะแนนความเครียดเริ่มต้นสำหรับพล็อตกราฟแท่งรายสัปดาห์
  bool _isLoading = true;                       // ตัวบ่งชี้สถานะการโหลดข้อมูลประวัติจากฐานข้อมูล

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'รายงานระดับความเครียด',
          style: GoogleFonts.prompt(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
            icon: Icon(Icons.settings_outlined, color: AppColors.textDark),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // กล่องกราฟแท่งหลักแสดงผลคะแนนเปอร์เซ็นต์ความเครียด
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white,
                        opacity: 0.75,
                        borderColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.bar_chart_rounded, color: AppColors.primaryBlue, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'แนวโน้มระดับความเครียดสะสม',
                                style: GoogleFonts.prompt(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 100,
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (group) => AppColors.textDark.withValues(alpha: 0.95),
                                    tooltipRoundedRadius: 8,
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        '${rod.toY.round()}%',
                                        GoogleFonts.prompt(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        const labels = ['สัปดาห์ 1', 'สัปดาห์ 2', 'สัปดาห์ 3', 'สัปดาห์ 4'];
                                        if (value.toInt() < labels.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              labels[value.toInt()],
                                              style: GoogleFonts.prompt(
                                                color: AppColors.textGray,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                      reservedSize: 26,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 20,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}%',
                                          style: GoogleFonts.prompt(
                                            color: AppColors.textLight,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                      reservedSize: 32,
                                    ),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 20,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: AppColors.textLight.withValues(alpha: 0.1),
                                    strokeWidth: 0.8,
                                    dashArray: [4, 4],
                                  ),
                                ),
                                barGroups: [
                                  _buildBarGroup(0, _weeklyData.isNotEmpty ? _weeklyData[0] : 0, const Color(0xFF046BD2), const Color(0xFF045CB4)),
                                  _buildBarGroup(1, _weeklyData.length > 1 ? _weeklyData[1] : 0, const Color(0xFF00A79D), const Color(0xFF33D9C9)),
                                  _buildBarGroup(2, _weeklyData.length > 2 ? _weeklyData[2] : 0, const Color(0xFF9B59B6), const Color(0xFFC39BD3)),
                                  _buildBarGroup(3, _weeklyData.length > 3 ? _weeklyData[3] : 0, const Color(0xFFE67E22), const Color(0xFFF5B041)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // กล่องคำอธิบายแถบสีแสดงผลของแต่ละสัปดาห์
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white,
                        opacity: 0.6,
                        borderColor: Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildLegend('สัปดาห์ 1', const Color(0xFF046BD2)),
                          _buildLegend('สัปดาห์ 2', const Color(0xFF00A79D)),
                          _buildLegend('สัปดาห์ 3', const Color(0xFF9B59B6)),
                          _buildLegend('สัปดาห์ 4', const Color(0xFFE67E22)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ส่วนหัวข้อแสดงสถิติความเครียดรายสัปดาห์ (สถิติรวม)
                    Text(
                      'สรุปเกณฑ์ดัชนีสุขภาพสมอง',
                      style: GoogleFonts.prompt(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'ค่าเฉลี่ย',
                            '${_weeklyData.isNotEmpty ? (_weeklyData.reduce((a, b) => a + b) / _weeklyData.length).round() : 0}%',
                            const Color(0xFF046BD2),
                            Icons.trending_up_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'สูงสุด',
                            '${_weeklyData.isNotEmpty ? _weeklyData.reduce((a, b) => a > b ? a : b).round() : 0}%',
                            const Color(0xFF00A79D),
                            Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            'ต่ำสุด',
                            '${_weeklyData.isNotEmpty ? _weeklyData.reduce((a, b) => a < b ? a : b).round() : 0}%',
                            const Color(0xFFE67E22),
                            Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color1, Color color2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 24,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: Colors.black.withValues(alpha: 0.03),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.prompt(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.75,
        borderColor: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.prompt(
                    fontSize: 10.5,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.prompt(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
