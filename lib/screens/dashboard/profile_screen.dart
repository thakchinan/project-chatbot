import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../auth/welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

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

                    // Header Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primaryBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'โปรไฟล์',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'ข้อมูลส่วนตัวและการตั้งค่า',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray,
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
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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

                    // Centered User Avatar Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _openEditProfile,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade100, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
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
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentUser.fullName ?? _currentUser.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentUser.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textGray,
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
                                'ข้อมูลส่วนตัว',
                                style: TextStyle(
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
                      icon: Icons.person_outline_rounded,
                      label: 'แก้ไขข้อมูลส่วนตัว',
                      color: const Color(0xFF667eea),
                      onTap: _openEditProfile,
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      label: 'ตั้งค่า',
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(user: _currentUser)));
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.help_outline_rounded,
                      label: 'ช่วยเหลือ',
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[200]),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: AppTheme.glassDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDestructive ? Colors.red : color,
          opacity: 0.08,
          borderColor: (isDestructive ? Colors.red : color).withValues(alpha: 0.25),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isDestructive ? Colors.red : color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : AppColors.textDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 22),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ออกจากระบบ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
