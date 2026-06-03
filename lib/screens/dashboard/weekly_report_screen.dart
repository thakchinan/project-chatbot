import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user.dart';
import '../../services/weekly_report_service.dart';
import '../../services/weekly_report_pdf_service.dart';
import '../../theme/app_theme.dart';

class WeeklyReportScreen extends StatefulWidget {
  final User user;

  const WeeklyReportScreen({super.key, required this.user});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  late Future<Map<String, dynamic>> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = WeeklyReportService.generate(widget.user.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _reportFuture = WeeklyReportService.generate(widget.user.id);
    });
    await _reportFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Weekly Report',
          style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          FutureBuilder<Map<String, dynamic>>(
            future: _reportFuture,
            builder: (context, snapshot) {
              final canExport = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
              return IconButton(
                tooltip: 'Export PDF',
                onPressed: canExport ? () => _exportPdf(snapshot.data!) : null,
                icon: Icon(Icons.ios_share_rounded, color: canExport ? AppColors.primaryBlue : Colors.grey),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildEmpty('ยังสร้างรายงานไม่ได้');
          }

          final report = snapshot.data!;
          final eeg = report['eeg'] as Map<String, dynamic>;
          final mood = report['mood'] as Map<String, dynamic>;
          final stress = report['stress'] as Map<String, dynamic>;
          final activity = report['activity'] as Map<String, dynamic>;
          final alerts = (report['alerts'] as List).cast<Map<String, dynamic>>();
          final carePlan = (report['carePlan'] as List).cast<String>();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHero(report['aiSummary']?.toString() ?? report['insight'].toString()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _metric('EEG Samples', '${report['brainwaveCount']}', Icons.psychology_rounded, AppColors.primaryBlue)),
                    const SizedBox(width: 12),
                    Expanded(child: _metric('Mood Logs', '${report['emotionCount']}', Icons.mood_rounded, AppColors.primaryGreen)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _metric('Activities', '${activity['sessions']}', Icons.directions_walk_rounded, AppColors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _metric('Chat Signals', '${mood['riskChatCount']}', Icons.chat_rounded, AppColors.error)),
                  ],
                ),
                const SizedBox(height: 18),
                _section(
                  title: 'Brainwave Insight',
                  icon: Icons.insights_rounded,
                  children: [
                    _progress('Stress Index', (eeg['stressIndex'] as num).toDouble(), AppColors.error),
                    _progress('Attention', (eeg['attention'] as num).toDouble(), AppColors.primaryBlue),
                    _progress('Meditation', (eeg['meditation'] as num).toDouble(), AppColors.primaryGreen),
                    _kv('สถานะ EEG', eeg['label'].toString()),
                    _kv('แนวโน้มการนอน', eeg['sleepTrend'].toString()),
                    _kv('วันที่เครียดสูง', _riskDays(eeg['highStressDays'])),
                    _kv('Alpha / Beta', '${_f(eeg['alpha'])} / ${_f(eeg['beta'])}'),
                  ],
                ),
                _section(
                  title: 'Mood & Stress',
                  icon: Icons.favorite_rounded,
                  children: [
                    _kv('อารมณ์ที่พบบ่อย', mood['topEmotion'].toString()),
                    _kv('ความเข้มเฉลี่ย', _f(mood['avgIntensity'])),
                    _kv('ผลประเมินล่าสุด', stress['latestLevel'].toString()),
                    _kv('คะแนนเครียดเฉลี่ย', _f(stress['avgScore'])),
                  ],
                ),
                if (report['emotionDistribution'] != null)
                  _section(
                    title: 'Emotion Distribution',
                    icon: Icons.pie_chart_rounded,
                    children: [_buildEmotionChart(Map<String, int>.from(report['emotionDistribution'] as Map))],
                  ),
                if (report['dailyTrend'] != null)
                  _section(
                    title: 'Daily Stress Trend',
                    icon: Icons.show_chart_rounded,
                    children: [_buildTrendChart(List<Map<String, dynamic>>.from(report['dailyTrend'] as List))],
                  ),
                if (report['comparison'] != null && report['comparison']['hasData'] == true)
                  _section(
                    title: 'Week-over-Week',
                    icon: Icons.compare_arrows_rounded,
                    children: [_buildComparison(Map<String, dynamic>.from(report['comparison'] as Map))],
                  ),
                _section(
                  title: 'Caregiver Alerts',
                  icon: Icons.notifications_active_rounded,
                  children: alerts.map(_alert).toList(),
                ),
                _section(
                  title: 'Next Week Care Plan',
                  icon: Icons.fact_check_rounded,
                  children: carePlan.map((text) => _bullet(text)).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'รายงานนี้เป็นข้อมูลประกอบการดูแลและการสื่อสารกับแพทย์ ไม่ใช่การวินิจฉัยทางการแพทย์',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(String insight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primaryBlue,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          const Text(
            'สรุปสุขภาพสมองและอารมณ์ 7 วันล่าสุด',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(insight, style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.45)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _section({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _progress(String label, double value, Color color) {
    final normalized = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_f(value), style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _alert(Map<String, dynamic> alert) {
    final level = alert['level'];
    final color = level == 'high'
        ? AppColors.error
        : level == 'medium'
            ? AppColors.orange
            : AppColors.primaryGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle_notifications_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(alert['message'].toString(), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Text(message, style: const TextStyle(color: AppColors.textGray)),
    );
  }

  String _f(dynamic value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return n.toStringAsFixed(1);
  }

  String _riskDays(dynamic value) {
    if (value is! List || value.isEmpty) return 'ไม่มีข้อมูล';
    return value.take(3).map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      return '${row['day']} (${_f(row['stressIndex'])})';
    }).join(', ');
  }

  Future<void> _exportPdf(Map<String, dynamic> report) async {
    try {
      final bytes = await WeeklyReportPdfService.generate(report, widget.user);
      await WeeklyReportPdfService.shareReport(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถสร้าง PDF ได้: $e')));
    }
  }

  Widget _buildTrendChart(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) return _buildEmpty('ไม่มีข้อมูลกราฟ');

    final spots = <FlSpot>[];
    for (int i = 0; i < trend.length; i++) {
      final val = (trend[i]['stress'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < trend.length) {
                    return Text(trend[idx]['day'].toString().substring(0, 1), style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.error,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.error.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionChart(Map<String, int> dist) {
    if (dist.isEmpty) return _buildEmpty('ไม่มีข้อมูลอารมณ์');
    final total = dist.values.reduce((a, b) => a + b);

    final colors = {
      'happy': Colors.green,
      'calm': Colors.blue,
      'neutral': Colors.grey,
      'anxious': Colors.orange,
      'stress': Colors.redAccent,
      'sad': Colors.deepPurple,
    };

    int i = 0;
    final sections = dist.entries.map((e) {
      final val = (e.value / total) * 100;
      final color = colors[e.key] ?? Colors.accents[i++ % Colors.accents.length];
      return PieChartSectionData(
        color: color,
        value: val,
        title: '${val.toStringAsFixed(0)}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: sections,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: dist.entries.map((e) {
              final color = colors[e.key] ?? Colors.grey;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildComparison(Map<String, dynamic> comp) {
    return Column(
      children: [
        _compRow('Stress Index', comp['stressDelta'], inverted: true),
        _compRow('Sleep Score', comp['sleepDelta'], inverted: false),
        _compRow('Activities', comp['activityDelta'], inverted: false),
      ],
    );
  }

  Widget _compRow(String label, dynamic deltaVal, {required bool inverted}) {
    final delta = (deltaVal as num?)?.toDouble() ?? 0;
    if (delta == 0) return _kv(label, 'คงที่');
    
    final isGood = inverted ? delta < 0 : delta > 0;
    final icon = delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final color = isGood ? AppColors.primaryGreen : AppColors.error;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text('${delta.abs().toStringAsFixed(1)}', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
