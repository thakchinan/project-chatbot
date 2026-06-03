import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/eeg_pdf_service.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  final User user;

  const CaregiverDashboardScreen({super.key, required this.user});

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  final _usernameController = TextEditingController();
  final _verificationController = TextEditingController();
  List<User> _linkedPatients = [];
  bool _isLoading = true;
  bool _isLinking = false;
  Map<int, Map<String, dynamic>> _patientStatuses = {}; // Cache for latest stress level/emotion per patient

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    await _loadLinkedPatients();
    await _fetchPatientStatuses();
    setState(() => _isLoading = false);
  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/caregiver_links_${widget.user.id}.json');
  }

  Future<void> _loadLinkedPatients() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        if (jsonStr.isNotEmpty) {
          final List<dynamic> decoded = json.decode(jsonStr);
          setState(() {
            _linkedPatients = decoded.map((p) => User.fromJson(p)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading linked patients: $e');
    }
  }

  Future<void> _saveLinkedPatients() async {
    try {
      final file = await _getCacheFile();
      final jsonList = _linkedPatients.map((p) => p.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving linked patients: $e');
    }
  }

  Future<void> _fetchPatientStatuses() async {
    final statuses = <int, Map<String, dynamic>>{};
    for (final patient in _linkedPatients) {
      try {
        final summary = await ApiService.getEmotionSummary(patient.id);
        final eegReports = await SupabaseService.getEegAssessmentReports(patient.id);
        
        String latestEmotion = 'ไม่มีข้อมูล';
        double latestIntensity = 0;
        String latestStressLevel = 'ปกติ';
        String rawDate = '';
        
        if (summary['success'] == true && (summary['logs'] as List).isNotEmpty) {
          final lastLog = (summary['logs'] as List).first;
          latestEmotion = lastLog['emotion_type'] ?? 'ไม่มีข้อมูล';
          latestIntensity = (lastLog['intensity'] as num?)?.toDouble() ?? 5.0;
          rawDate = lastLog['created_at'] ?? '';
        }

        if (eegReports['success'] == true && (eegReports['reports'] as List).isNotEmpty) {
          final lastReport = (eegReports['reports'] as List).first;
          latestStressLevel = lastReport['risk_level'] ?? 'ปกติ';
        }

        final isNegative = latestEmotion.toLowerCase() == 'sad' || latestEmotion.toLowerCase() == 'anxious' || latestEmotion.toLowerCase() == 'angry';
        statuses[patient.id] = {
          'latest_emotion': latestEmotion,
          'latest_intensity': latestIntensity,
          'latest_stress_level': latestStressLevel,
          'date': rawDate,
          'has_alert': latestStressLevel == 'high' || (isNegative && latestIntensity >= 7),
        };
      } catch (e) {
        debugPrint('Error fetching status for patient ${patient.id}: $e');
      }
    }
    setState(() {
      _patientStatuses = statuses;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _linkPatient() async {
    final username = _usernameController.text.trim();
    final verificationCode = _verificationController.text.trim();

    if (username.isEmpty) {
      _showSnackBar('กรุณาป้อนชื่อผู้ใช้', Colors.red);
      return;
    }
    if (verificationCode.isEmpty) {
      _showSnackBar('กรุณาป้อนเลขท้ายเบอร์โทรศัพท์ 4 หลักเพื่อยืนยันตัวตน', Colors.red);
      return;
    }

    setState(() => _isLinking = true);

    try {
      final response = await SupabaseService.client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        _showSnackBar('ไม่พบชื่อผู้ใช้นี้ในระบบ', Colors.red);
        setState(() => _isLinking = false);
        return;
      }

      final patientUser = User.fromJson(response);

      // Verify last 4 digits of patient phone number
      final patientPhone = patientUser.phone ?? '';
      final cleanedPhone = patientPhone.replaceAll(RegExp(r'\D'), '');
      final last4Digits = cleanedPhone.length >= 4 
          ? cleanedPhone.substring(cleanedPhone.length - 4) 
          : '';

      if (last4Digits.isEmpty || last4Digits != verificationCode) {
        _showSnackBar('เลขท้ายเบอร์โทรศัพท์ยืนยันตัวตนไม่ถูกต้อง', Colors.red);
        setState(() => _isLinking = false);
        return;
      }

      if (patientUser.id == widget.user.id) {
        _showSnackBar('คุณไม่สามารถเชื่อมโยงกับตัวเองได้', Colors.red);
        setState(() => _isLinking = false);
        return;
      }

      if (_linkedPatients.any((p) => p.id == patientUser.id)) {
        _showSnackBar('คุณเชื่อมโยงผู้ใช้รายนี้อยู่แล้ว', Colors.orange);
        setState(() => _isLinking = false);
        return;
      }

      setState(() {
        _linkedPatients.add(patientUser);
      });

      await _saveLinkedPatients();
      await _fetchPatientStatuses();
      _showSnackBar('เชื่อมโยงผู้รับการดูแลสำเร็จ!', Colors.green);
      _usernameController.clear();
      _verificationController.clear();
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e', Colors.red);
    } finally {
      setState(() => _isLinking = false);
    }
  }

  void _unlinkPatient(User patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการเชื่อมโยง'),
        content: Text('คุณต้องการยกเลิกการดูแล ${patient.displayName} หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _linkedPatients.removeWhere((p) => p.id == patient.id);
                _patientStatuses.remove(patient.id);
              });
              await _saveLinkedPatients();
              _showSnackBar('ยกเลิกการเชื่อมโยงแล้ว', Colors.green);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'แดชบอร์ดผู้ดูแล (Caretaker)',
          style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.glassBackgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildLinkSection(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildPatientList()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLinkSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เชื่อมโยงผู้รับการดูแลใหม่',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'ป้อนชื่อผู้ใช้ (Username)',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _verificationController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        hintText: 'ป้อนเลขท้ายเบอร์โทรศัพท์ 4 หลักของผู้ป่วย',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primaryBlue),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.8),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLinking ? null : _linkPatient,
                    icon: _isLinking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.add_link_rounded, color: Colors.white, size: 18),
                    label: const Text('เชื่อมโยง', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    if (_linkedPatients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('ยังไม่มีการเชื่อมโยงผู้รับการดูแล', style: TextStyle(color: AppColors.textGray)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _linkedPatients.length,
      itemBuilder: (ctx, index) {
        final patient = _linkedPatients[index];
        final status = _patientStatuses[patient.id] ?? {};
        final isAlert = status['has_alert'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Container(
            decoration: AppTheme.glassDecoration(
              borderColor: isAlert ? Colors.red.withValues(alpha: 0.4) : null,
              color: isAlert ? Colors.red.withValues(alpha: 0.05) : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                backgroundImage: patient.avatarUrl != null && patient.avatarUrl!.isNotEmpty
                    ? NetworkImage(patient.avatarUrl!)
                    : null,
                child: patient.avatarUrl == null || patient.avatarUrl!.isEmpty
                    ? const Icon(Icons.person, color: AppColors.primaryBlue)
                    : null,
              ),
              title: Text(patient.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('อารมณ์ล่าสุด: ${_translateEmotion(status['latest_emotion'] ?? '')} (ระดับ ${status['latest_intensity'] ?? 0})',
                        style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
                    const SizedBox(height: 2),
                    Text('สภาวะสมอง/ความเครียด: ${_translateStress(status['latest_stress_level'] ?? '')}',
                        style: TextStyle(
                            fontSize: 13,
                            color: status['latest_stress_level'] == 'high' ? Colors.red : AppColors.textGray)),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAlert)
                    const Tooltip(
                      message: 'มีสัญญาณเตือนระดับความเครียดสูง!',
                      child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PatientMonitorScreen(patient: patient)),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _unlinkPatient(patient),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _translateEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return 'มีความสุข 😊';
      case 'calm':
        return 'ผ่อนคลาย 😌';
      case 'sad':
        return 'ซึมเศร้า 😢';
      case 'anxious':
        return 'วิตกกังวล 😰';
      case 'angry':
        return 'หงุดหงิด/โกรธ 😡';
      default:
        return 'ปกติ/ไม่ระบุ';
    }
  }

  String _translateStress(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return 'ต่ำ (ปกติ)';
      case 'moderate':
        return 'ปานกลาง';
      case 'high':
        return 'สูง (เสี่ยง)';
      default:
        return 'ปกติ';
    }
  }
}

// ---------------------------------------------------------------------
// Patient detailed monitoring screen
// ---------------------------------------------------------------------
class PatientMonitorScreen extends StatefulWidget {
  final User patient;

  const PatientMonitorScreen({super.key, required this.patient});

  @override
  State<PatientMonitorScreen> createState() => _PatientMonitorScreenState();
}

class _PatientMonitorScreenState extends State<PatientMonitorScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _elderlyProfile = {};
  Map<String, dynamic> _emotionSummary = {};
  List<dynamic> _reports = [];

  List<FlSpot> _chartSpots = [];
  List<String> _chartDates = [];

  double get _avgStressIndex {
    final logs = _emotionSummary['logs'] as List? ?? [];
    if (logs.isEmpty) return 0.0;

    double totalWeighted = 0;
    for (final log in logs) {
      final type = (log['emotion_type'] as String? ?? 'happy').toLowerCase();
      final intensity = (log['intensity'] as num?)?.toDouble() ?? 5.0;
      if (type == 'sad' || type == 'anxious' || type == 'angry') {
        totalWeighted += intensity;
      } else {
        totalWeighted += 1.0; // Low stress/depression contribution for happy/calm
      }
    }
    return totalWeighted / logs.length;
  }

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() => _isLoading = true);
    try {
      final patientId = widget.patient.id;

      // 1. Fetch health profile
      final profileRes = await ApiService.getElderlyProfile(patientId);
      if (profileRes['success'] == true) {
        _elderlyProfile = profileRes['profile'] ?? {};
      }

      // 2. Fetch emotion summary
      final emotionRes = await ApiService.getEmotionSummary(patientId);
      if (emotionRes['success'] == true) {
        _emotionSummary = emotionRes;
      }

      // 3. Fetch EEG assessment reports
      final reportRes = await SupabaseService.getEegAssessmentReports(patientId);
      if (reportRes['success'] == true) {
        _reports = reportRes['reports'] ?? [];
      }

      _processChartData();
    } catch (e) {
      debugPrint('Error loading patient data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processChartData() {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    final dates = <String>[];

    final days = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
    final logs = _emotionSummary['logs'] as List? ?? [];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      dates.add('${day.day}/${day.month}');

      final dayLogs = logs.where((log) {
        final createdAt = log['created_at'];
        if (createdAt == null) return false;
        final logDate = DateTime.parse(createdAt.toString()).toLocal();
        return logDate.year == day.year && logDate.month == day.month && logDate.day == day.day;
      }).toList();

      if (dayLogs.isNotEmpty) {
        final avgInt = dayLogs.map((l) => (l['intensity'] as num?)?.toDouble() ?? 5.0).reduce((a, b) => a + b) / dayLogs.length;
        spots.add(FlSpot(i.toDouble(), avgInt));
      } else {
        spots.add(FlSpot(i.toDouble(), 0));
      }
    }

    setState(() {
      _chartSpots = spots;
      _chartDates = dates;
    });
  }

  Map<String, dynamic> _castMap(Map? map) {
    if (map == null) return {};
    return map.map((key, value) {
      final newKey = key.toString();
      if (value is Map) {
        return MapEntry(newKey, _castMap(value));
      } else if (value is List) {
        return MapEntry(
          newKey,
          value.map((e) => e is Map ? _castMap(e) : e).toList(),
        );
      }
      return MapEntry(newKey, value);
    });
  }

  void _exportReportPDF(dynamic report) async {
    try {
      final castedReport = _castMap(report as Map?);
      final reportData = _castMap(castedReport['report_data'] as Map?);
      final pdfBytes = await EegPdfService.generateReport(reportData, widget.patient);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถพิมพ์รายงาน PDF ได้: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.primaryBlue),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'ติดตาม: ${widget.patient.displayName}',
            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.favorite_rounded), text: 'ข้อมูลสุขภาพ'),
              Tab(icon: Icon(Icons.show_chart_rounded), text: 'สถิติอารมณ์'),
              Tab(icon: Icon(Icons.assignment_turned_in_rounded), text: 'ประวัติตรวจสมอง'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.glassBackgroundGradient),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildHealthTab(),
                    _buildEmotionTab(),
                    _buildEEGReportTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHealthTab() {
    final bloodType = _elderlyProfile['blood_type'] ?? '-';
    final height = _elderlyProfile['height_cm'] != null ? '${_elderlyProfile['height_cm']} ซม.' : '-';
    final weight = _elderlyProfile['weight_kg'] != null ? '${_elderlyProfile['weight_kg']} กก.' : '-';
    final cognitive = _elderlyProfile['cognitive_status'] ?? '-';
    final mobility = _elderlyProfile['mobility_status'] ?? '-';
    final doctor = _elderlyProfile['doctor_name'] ?? '-';
    final doctorPhone = _elderlyProfile['doctor_phone'] ?? '-';
    final hospital = _elderlyProfile['hospital_name'] ?? '-';

    final medicalConditions = (_elderlyProfile['medical_conditions'] as List?)?.join(', ') ?? 'ไม่มี';
    final allergies = (_elderlyProfile['allergies'] as List?)?.join(', ') ?? 'ไม่มี';
    final medications = (_elderlyProfile['current_medications'] as List?)?.join(', ') ?? 'ไม่มี';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_ind_outlined, color: AppColors.primaryBlue),
                    SizedBox(width: 8),
                    Text('ข้อมูลพื้นฐานทางการแพทย์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Divider(height: 20),
                _buildInfoRow('กรุ๊ปเลือด', bloodType),
                _buildInfoRow('ส่วนสูง / น้ำหนัก', '$height / $weight'),
                _buildInfoRow('สภาวะทางความคิด', cognitive),
                _buildInfoRow('สถานะการเคลื่อนไหว', mobility),
                _buildInfoRow('โรคประจำตัว', medicalConditions),
                _buildInfoRow('ประวัติการแพ้', allergies),
                _buildInfoRow('ยาที่กำลังทาน', medications),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_hospital_outlined, color: AppColors.primaryBlue),
                    SizedBox(width: 8),
                    Text('ข้อมูลการรักษาพยาบาล', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Divider(height: 20),
                _buildInfoRow('แพทย์ผู้ดูแลประจำตัว', doctor),
                _buildInfoRow('เบอร์ติดต่อแพทย์', doctorPhone),
                _buildInfoRow('โรงพยาบาลประจำ', hospital),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 14))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildEmotionTab() {
    final totalLogs = _emotionSummary['total_logs'] ?? 0;
    final avgIntensity = _avgStressIndex;
    final activeSpots = _chartSpots.where((s) => s.y > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: AppColors.primaryBlue),
                    SizedBox(width: 8),
                    Text('สรุปความเครียดประจำสัปดาห์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('บันทึกอารมณ์', '$totalLogs ครั้ง'),
                    _buildSummaryItem('ระดับความเครียดเฉลี่ย', '${avgIntensity.toStringAsFixed(1)}/10'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('กราฟดัชนีความเครียด (ย้อนหลัง 7 วัน)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: activeSpots.isEmpty
                      ? const Center(child: Text('ไม่มีข้อมูลความเครียดย้อนหลังในสัปดาห์นี้'))
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 1 || value == 5 || value == 10) {
                                      return Text(value.toInt().toString(),
                                          style: const TextStyle(color: AppColors.textGray, fontSize: 10));
                                    }
                                    return const SizedBox();
                                  },
                                  reservedSize: 20,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx >= 0 && idx < _chartDates.length) {
                                      return Text(_chartDates[idx],
                                          style: const TextStyle(color: AppColors.textGray, fontSize: 9));
                                    }
                                    return const SizedBox();
                                  },
                                  reservedSize: 20,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0,
                            maxX: 6,
                            minY: 0,
                            maxY: 10,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _chartSpots,
                                isCurved: true,
                                color: AppColors.primaryBlue,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
      ],
    );
  }

  Widget _buildEEGReportTab() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('ยังไม่มีข้อมูลการวิเคราะห์สัญญาณคลื่นสมอง (qEEG)', style: TextStyle(color: AppColors.textGray)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reports.length,
      itemBuilder: (ctx, index) {
        final r = _reports[index];
        final rawDate = r['recorded_at'] ?? r['created_at'] ?? '';
        final date = rawDate.isNotEmpty ? DateTime.parse(rawDate.toString()).toLocal() : DateTime.now();
        final dateStr = '${date.day}/${date.month}/${date.year}';
        final stressLevel = r['risk_level'] ?? 'ปกติ';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: AppTheme.glassDecoration(),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text('ผลตรวจ qEEG วันที่ $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'ระดับความเครียดสะสม: ${_translateStress(stressLevel)}',
                  style: TextStyle(
                    color: stressLevel == 'high' ? Colors.red : AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing: ElevatedButton.icon(
                onPressed: () => _exportReportPDF(r),
                icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
                label: const Text('รายงาน', style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _translateStress(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return 'ต่ำ (ปกติ)';
      case 'moderate':
        return 'ปานกลาง';
      case 'high':
        return 'สูง (เสี่ยง)';
      default:
        return 'ปกติ';
    }
  }
}
