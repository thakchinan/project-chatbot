import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../auth/welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'weekly_report_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final Function(User)? onUserUpdated;

  const ProfileScreen({super.key, required this.user, this.onUserUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.fullName != widget.user.fullName ||
        oldWidget.user.email != widget.user.email ||
        oldWidget.user.phone != widget.user.phone) {
      setState(() => _currentUser = widget.user);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final result = await ApiService.getProfile(_currentUser.id);
      if (result['success'] == true && result['profile'] != null) {
        final freshUser = User.fromJson(result['profile']);
        if (mounted) {
          setState(() {
            _currentUser = freshUser;
            _isLoading = false;
          });
          widget.onUserUpdated?.call(freshUser);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditProfile() async {
    final updatedUser = await Navigator.push<User>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _currentUser)),
    );

    if (updatedUser != null) {
      setState(() => _currentUser = updatedUser);
      widget.onUserUpdated?.call(updatedUser);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                  children: [

                    // Premium Patient Profile Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.glassDecoration(
                              color: AppColors.primaryBlue,
                              opacity: 0.1,
                              borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primaryBlue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'โปรไฟล์ผู้ใช้งาน',
                                  style: GoogleFonts.prompt(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'ข้อมูลระเบียนคนไข้และการตั้งค่าระบบ',
                                  style: GoogleFonts.prompt(
                                    fontSize: 12,
                                    color: AppColors.textGray,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SettingsScreen(user: _currentUser)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: AppTheme.glassDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                                opacity: 0.8,
                              ),
                              child: const Icon(
                                Icons.settings_outlined,
                                color: AppColors.textDark,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Centered User Bio HUD Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(22),
                      width: double.infinity,
                      decoration: AppTheme.glassDecoration(
                        color: Colors.white,
                        opacity: 0.9,
                        borderColor: Colors.white.withValues(alpha: 0.6),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _openEditProfile,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing Avatar Ring
                                Container(
                                  width: 102,
                                  height: 102,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                        blurRadius: 14,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    image: _currentUser.avatarUrl != null && _currentUser.avatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(_currentUser.avatarUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _currentUser.avatarUrl == null || _currentUser.avatarUrl!.isEmpty
                                      ? const Icon(Icons.person_rounded, size: 45, color: AppColors.primaryBlue)
                                      : null,
                                ),
                                // Pulse Status Badge on Avatar
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.neonGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.neonGreen.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _currentUser.fullName ?? _currentUser.username,
                            style: GoogleFonts.prompt(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentUser.email ?? '',
                            style: GoogleFonts.prompt(
                              fontSize: 13,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Premium Hospital ID Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'PATIENT ID: #SM-${_currentUser.id.toString().padLeft(4, '0')}',
                              style: GoogleFonts.prompt(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: AppTheme.glassDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.white,
                              opacity: 0.9,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.primaryBlue,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'ข้อมูลส่วนตัวผู้ป่วย',
                                      style: GoogleFonts.prompt(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(Icons.person_outline_rounded, 'ชื่อจริง-นามสกุล', _currentUser.fullName ?? '-'),
                                _buildProfileField(Icons.phone_outlined, 'เบอร์โทรศัพท์', _currentUser.phone ?? '-'),
                                _buildProfileField(Icons.email_outlined, 'อีเมล', _currentUser.email ?? '-'),
                                _buildProfileField(Icons.cake_outlined, 'วันเกิด', _currentUser.birthDate ?? '-', isLast: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          _buildMenuItem(
                            context,
                            icon: Icons.assignment_outlined,
                            label: 'รายงานประจำสัปดาห์ AI',
                            color: AppColors.primaryBlue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => WeeklyReportScreen(user: _currentUser)),
                              );
                            },
                          ),

                          _buildMenuItem(
                            context,
                            icon: Icons.person_outline_rounded,
                            label: 'แก้ไขข้อมูลส่วนตัว',
                            color: const Color(0xFF667eea),
                            onTap: _openEditProfile,
                          ),
                          _buildMenuItem(
                            context,
                            icon: Icons.settings_outlined,
                            label: 'ตั้งค่าการใช้งาน',
                            color: const Color(0xFF4CAF50),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(user: _currentUser)));
                            },
                          ),
                          _buildMenuItem(
                            context,
                            icon: Icons.help_outline_rounded,
                            label: 'ช่วยเหลือผู้ใช้',
                            color: const Color(0xFF2196F3),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
                            },
                          ),
                          _buildMenuItem(
                            context,
                            icon: Icons.logout_rounded,
                            label: 'ออกจากระบบ',
                            isDestructive: true,
                            color: Colors.red,
                            onTap: () => _showLogoutConfirmation(context),
                          ),
                          const SizedBox(height: 100), // Spacing for floating navigation bar
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildProfileField(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15), width: 1),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.prompt(
                        fontSize: 11,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.prompt(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    Color color = const Color(0xFF667eea),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: AppTheme.glassDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDestructive ? Colors.red : color,
          opacity: 0.06,
          borderColor: (isDestructive ? Colors.red : color).withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isDestructive ? Colors.red : color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.prompt(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? Colors.red : AppColors.textDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textLight.withValues(alpha: 0.6), size: 22),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'ออกจากระบบ',
          style: GoogleFonts.prompt(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Text(
          'คุณต้องการออกจากระบบการใช้งานในขณะนี้หรือไม่?',
          style: GoogleFonts.prompt(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'ยกเลิก',
              style: GoogleFonts.prompt(color: AppColors.textGray, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushAndRemoveUntil(
                  parentContext,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'ออกจากระบบ',
              style: GoogleFonts.prompt(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
