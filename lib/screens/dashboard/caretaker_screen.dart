import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/weekly_report_service.dart';
import '../../theme/app_theme.dart';
import '../auth/welcome_screen.dart';
import 'weekly_report_screen.dart';

class CaretakerScreen extends StatefulWidget {
  final User? user;
  final bool isRoot;

  const CaretakerScreen({super.key, this.user, this.isRoot = false});

  @override
  State<CaretakerScreen> createState() => _CaretakerScreenState();
}

class _CaretakerScreenState extends State<CaretakerScreen> {
  late Future<Map<String, dynamic>> _summaryFuture;
  RealtimeChannel? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
    _setupRealtime();
  }

  @override
  void dispose() {
    _alertSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    if (widget.user == null) return;
    
    // Register FCM Token for Push Notifications
    _registerFCMToken();

    try {
      _alertSubscription = ApiService.subscribeToCaregiverAlerts(
        widget.user!.id,
        (payload) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ มีการแจ้งเตือนใหม่จากผู้สูงอายุ')),
          );
          setState(() {
            _summaryFuture = _loadSummary();
          });
        },
      );
    } catch (e) {
      debugPrint('Realtime setup failed: $e');
    }
  }

  Future<void> _registerFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        String platform = 'web';
        try {
          if (Platform.isAndroid) platform = 'android';
          else if (Platform.isIOS) platform = 'ios';
        } catch (_) {} // Fallback for web where Platform is not available
        
        await ApiService.saveFCMToken(widget.user!.id, token, platform);
        debugPrint('📲 FCM Token saved: $token');
      }
    } catch (e) {
      debugPrint('⚠️ FCM Token fetch failed (Needs real device/config): $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (widget.user == null) return;
    await ApiService.markAllAlertsRead(widget.user!.id);
    setState(() {
      _summaryFuture = _loadSummary();
    });
  }

  Future<void> _markAsRead(int alertId) async {
    await ApiService.markCaregiverAlertRead(alertId);
    setState(() {
      _summaryFuture = _loadSummary();
    });
  }

  Future<Map<String, dynamic>> _loadSummary() async {
    if (widget.user == null) return {};
    final report = await WeeklyReportService.generate(widget.user!.id);
    final contacts = await ApiService.getEmergencyContacts(widget.user!.id);
    final savedAlerts = await ApiService.getCaregiverAlerts(
      widget.user!.id,
      unreadOnly: true,
    );
    return {
      'report': report,
      'contacts': contacts['success'] == true ? contacts['contacts'] ?? [] : [],
      'savedAlerts': savedAlerts['success'] == true ? savedAlerts['alerts'] ?? [] : [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.isRoot,
        leading: widget.isRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryBlue),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Caregiver Mode',
          style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: widget.isRoot
            ? [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('saved_user');
                    await prefs.remove('is_caregiver_device');
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          final report = snapshot.data?['report'] as Map<String, dynamic>?;
          final mood = report?['mood'] as Map<String, dynamic>?;
          final eeg = report?['eeg'] as Map<String, dynamic>?;
          final activity = report?['activity'] as Map<String, dynamic>?;
          final reportAlerts = ((report?['alerts'] as List?) ?? const []).cast<Map<String, dynamic>>();
          final savedAlerts = ((snapshot.data?['savedAlerts'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final alerts = savedAlerts.isNotEmpty ? savedAlerts : reportAlerts;
          final contacts = ((snapshot.data?['contacts'] as List?) ?? const []).cast<dynamic>();
          final highAlerts = alerts.where((a) => a['level'] == 'high').length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _hero(highAlerts),
              const SizedBox(height: 16),
              if (snapshot.connectionState != ConnectionState.done)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ))
              else ...[
                Row(
                  children: [
                    Expanded(child: _statusTile('Alert', '$highAlerts', Icons.warning_rounded, highAlerts > 0 ? AppColors.error : AppColors.primaryGreen)),
                    const SizedBox(width: 12),
                    Expanded(child: _statusTile('Mood', mood?['topEmotion']?.toString() ?? '-', Icons.mood_rounded, AppColors.primaryBlue)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _statusTile('EEG', eeg?['label']?.toString() ?? '-', Icons.psychology_rounded, AppColors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _statusTile('Activity', '${activity?['sessions'] ?? 0} ครั้ง', Icons.directions_walk_rounded, AppColors.primaryGreen)),
                  ],
                ),
                const SizedBox(height: 18),
                _section(
                  title: 'Proactive Alerts',
                  icon: Icons.notifications_active_rounded,
                  actions: [
                    if (alerts.any((a) => a['is_read'] == false))
                      TextButton.icon(
                        onPressed: _markAllAsRead,
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('อ่านทั้งหมด'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                  children: alerts.isEmpty
                      ? [_plainText('ยังไม่มีข้อมูลแจ้งเตือน')]
                      : [
                          _plainText('สถานะนี้อัปเดตแบบเรียลไทม์ (Realtime)'),
                          const SizedBox(height: 10),
                          ...alerts.map(_alertCard),
                        ],
                ),
                _section(
                  title: 'Sleep & High Stress Days',
                  icon: Icons.bedtime_rounded,
                  children: [
                    _checkItem('แนวโน้มการนอน: ${eeg?['sleepTrend'] ?? 'ไม่มีข้อมูล'}'),
                    _checkItem('วันที่ควรติดตาม: ${_riskDays(eeg?['highStressDays'])}'),
                  ],
                ),
                _section(
                  title: 'Care Plan สำหรับผู้ดูแล',
                  icon: Icons.fact_check_rounded,
                  children: ((report?['carePlan'] as List?) ?? const [])
                      .map((e) => _checkItem(e.toString()))
                      .toList(),
                ),
                _section(
                  title: 'Emergency Contacts',
                  icon: Icons.phone_in_talk_rounded,
                  children: [
                    ...contacts.map((contact) {
                      final row = Map<String, dynamic>.from(contact as Map);
                      return _contactCard(
                        row['contact_name']?.toString() ?? 'ผู้ติดต่อฉุกเฉิน',
                        row['phone_number']?.toString() ?? '',
                        row['relationship']?.toString() ?? '',
                      );
                    }),
                    _contactCard('สายด่วนสุขภาพจิต', '1323', 'บริการปรึกษา 24 ชั่วโมง'),
                    _contactCard('แพทย์ฉุกเฉิน', '1669', 'เหตุฉุกเฉินทางการแพทย์'),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _hero(int highAlerts) {
    final hasRisk = highAlerts > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasRisk
              ? const [Color(0xFFE53935), Color(0xFFFF8A65)]
              : const [Color(0xFF4A7FC1), Color(0xFF6BBF7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(
            hasRisk ? 'ต้องติดตามผู้สูงอายุใกล้ชิด' : 'ภาพรวมอยู่ในเกณฑ์ติดตามปกติ',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'ระบบรวมข้อมูล EEG, อารมณ์, แบบประเมิน และข้อความแชท เพื่อช่วยผู้ดูแลตัดสินใจได้เร็วขึ้น',
            style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          if (widget.user != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WeeklyReportScreen(user: widget.user!)),
                );
              },
              icon: const Icon(Icons.auto_graph_rounded),
              label: const Text('เปิดรายงานรายสัปดาห์'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusTile(String label, String value, IconData icon, Color color) {
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
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _section({required String title, required IconData icon, required List<Widget> children, List<Widget>? actions}) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              if (actions != null) Row(children: actions),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final level = alert['level'];
    final color = level == 'high'
        ? AppColors.error
        : level == 'medium'
            ? AppColors.orange
            : AppColors.primaryGreen;
    final isRead = alert['is_read'] == true;
    final alertId = alert['alert_id'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRead ? Colors.grey[100] : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRead ? Colors.grey[300]! : color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Icon(Icons.priority_high_rounded, color: isRead ? Colors.grey : color),
              if (!isRead)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['title'].toString(), style: TextStyle(fontWeight: FontWeight.w800, color: isRead ? Colors.grey[700] : null)),
                const SizedBox(height: 2),
                Text(alert['message'].toString(), style: TextStyle(fontSize: 12, color: isRead ? Colors.grey[500] : Colors.grey[700])),
              ],
            ),
          ),
          if (!isRead && alertId != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              color: color,
              tooltip: 'Mark as read',
              onPressed: () => _markAsRead(alertId),
            ),
        ],
      ),
    );
  }

  Widget _checkItem(String text) {
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

  Widget _plainText(String text) {
    return Text(text, style: TextStyle(color: Colors.grey[600]));
  }

  String _riskDays(dynamic value) {
    if (value is! List || value.isEmpty) return 'ไม่มีข้อมูล';
    return value.take(3).map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      final score = (row['stressIndex'] as num?)?.toDouble() ?? 0;
      return '${row['day']} (${score.toStringAsFixed(1)})';
    }).join(', ');
  }

  Widget _contactCard(String name, String phone, String relation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_rounded, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (relation.isNotEmpty)
                  Text(relation, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: phone.isEmpty ? null : () => _launchUrl('tel:$phone'),
            child: Text(phone.isEmpty ? '-' : phone),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
