import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../services/api_service.dart';
import '../auth/welcome_screen.dart';
import 'notification_settings_screen.dart';
import 'change_password_screen.dart';

/// SettingsScreen หน้าจอการตั้งค่าการแจ้งเตือน รหัสผ่าน และการขอลบบัญชีผู้ใช้งานระบบ
class SettingsScreen extends StatefulWidget {
  final User user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false; // ตัวควบคุมสปินเนอร์ตอนขอลบบัญชีออกจากระบบฐานข้อมูล

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
          'ตั้งค่า',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSettingItem(
              icon: Icons.notifications_outlined,
              label: 'การตั้งค่าการแจ้งเตือน',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationSettingsScreen(user: widget.user)),
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.lock_outline,
              label: 'ตั้งค่ารหัสผ่าน',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChangePasswordScreen(user: widget.user)),
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.delete_outline,
              label: 'ลบบัญชี',
              isDestructive: true,
              onTap: () {
                _showDeleteAccountDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFF0F0F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withValues(alpha: 0.1)
                      : AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDestructive ? Colors.red : AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext parentContext) {

    final navigator = Navigator.of(parentContext);

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('ลบบัญชี'),
            content: _isDeleting
                ? const Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Expanded(child: Text('กำลังลบบัญชี...')),
                    ],
                  )
                : const Text('คุณแน่ใจหรือไม่? การลบบัญชีจะไม่สามารถย้อนกลับได้'),
            actions: _isDeleting
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('ยกเลิก'),
                    ),
                    ElevatedButton(
                      onPressed: () async {

                        setState(() {
                          _isDeleting = true;
                        });
                        setDialogState(() {});

                        final result = await SupabaseService.deleteAccount(widget.user.id);

                        if (result['success'] == true) {
                          // ล้างเซสชันผู้ใช้ออกจากระบบเนื่องจากบัญชีถูกลบแล้ว
                          await ApiService.signOut();

                          Navigator.pop(dialogContext);

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          });
                        } else {
                          setState(() {
                            _isDeleting = false;
                          });
                          setDialogState(() {});

                          if (!mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? 'เกิดข้อผิดพลาด'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'ลบบัญชี',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }
}
