import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../main_navigation.dart';
import 'register_screen.dart';

/// LoginScreen เป็นหน้าจอล็อกอินสำหรับการเข้าสู่ระบบผู้ใช้งาน
/// รองรับ 2 ช่องทาง:
///   1. Email + Password (ผ่าน Supabase Auth)
///   2. Google Sign-In (OAuth 2.0)
/// มีระบบจดจำ Email ผ่าน SharedPreferences และฟังก์ชันลืมรหัสผ่าน
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // คอนโทรลเลอร์สำหรับเก็บค่าข้อมูลการกรอกฟอร์มล็อกอิน
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true; // ควบคุมสถานะการซ่อน/แสดงรหัสผ่าน
  bool _isLoading = false;      // ใช้แสดงโหลดดิ้งขณะเชื่อมต่อ API
  bool _isGoogleLoading = false; // ใช้แสดงโหลดดิ้งขณะ Google Sign-In
  bool _rememberMe = false;     // ติ๊กบันทึก email ในเครื่องหรือไม่

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// โหลดข้อมูลล็อกอินที่เคยบันทึกไว้จาก SharedPreferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = rememberMe;
      });
    }
  }

  /// บันทึกหรือลบข้อมูล email ใน SharedPreferences ตามสถานะ Remember Me
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// เข้าสู่ระบบด้วย Email + Password ผ่าน Supabase Auth
  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      await _saveCredentials();
      final user = User.fromJson(result['user']);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainNavigation(user: user)),
          (route) => false,
        );
      }
    } else {
      _showError(result['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

  /// เข้าสู่ระบบด้วย Google Sign-In
  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    final result = await AuthService.signInWithGoogle();

    setState(() => _isGoogleLoading = false);

    if (result['success'] == true) {
      final user = User.fromJson(result['user']);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainNavigation(user: user)),
          (route) => false,
        );
      }
    } else {
      // ถ้าผู้ใช้กดยกเลิกเอง ไม่ต้องแสดง error
      if (result['message'] != 'ยกเลิกการเข้าสู่ระบบด้วย Google') {
        _showError(result['message'] ?? 'เกิดข้อผิดพลาด');
      }
    }
  }

  /// แสดง Dialog สำหรับกรอก email เพื่อรีเซ็ตรหัสผ่าน
  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'ลืมรหัสผ่าน',
          style: GoogleFonts.prompt(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'กรุณากรอกอีเมลที่ใช้สมัครสมาชิก\nระบบจะส่งลิงก์รีเซ็ตรหัสผ่านไปให้',
              style: GoogleFonts.prompt(fontSize: 13, color: AppColors.textGray, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.prompt(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'ระบุอีเมลของคุณ',
                prefixIcon: const Icon(Icons.email_outlined),
                hintStyle: GoogleFonts.prompt(color: AppColors.textLight),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: GoogleFonts.prompt(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('ส่งอีเมลรีเซ็ต', style: GoogleFonts.prompt(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && emailController.text.isNotEmpty) {
      final result = await AuthService.sendPasswordResetEmail(emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? ''),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );
      }
    }

    emailController.dispose();
  }

  /// แสดง Snackbar แจ้งข้อผิดพลาดภาษาไทย
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.glassBackgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'เข้าสู่ระบบ',
            style: GoogleFonts.prompt(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SizedBox(
          height: double.infinity,
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'ยินดีต้อนรับกลับมา',
                style: GoogleFonts.prompt(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณาเข้าสู่ระบบเพื่อใช้งานฟีเจอร์ต่างๆ และเริ่มต้นตรวจสอบวิเคราะห์สถานะสมองของคุณ',
                style: GoogleFonts.prompt(
                  fontSize: 13,
                  color: AppColors.textGray,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 36),

              // ช่อง Email
              _buildLabel('อีเมล'),
              _buildTextField(
                controller: _emailController,
                hintText: 'ระบุอีเมลของคุณ',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),

              const SizedBox(height: 20),

              // ช่องรหัสผ่าน
              _buildLabel('รหัสผ่าน'),
              _buildTextField(
                controller: _passwordController,
                hintText: 'ระบุรหัสผ่านของคุณ',
                obscureText: _obscurePassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textGray,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),

              const SizedBox(height: 12),

              // จดจำรหัสผ่าน + ลืมรหัสผ่าน
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.textLight, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'จดจำอีเมล',
                        style: GoogleFonts.prompt(
                          fontSize: 13,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      'ลืมรหัสผ่าน?',
                      style: GoogleFonts.prompt(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ปุ่มเข้าสู่ระบบด้วย Email
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'เข้าสู่ระบบ',
                          style: GoogleFonts.prompt(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // เส้นคั่น "หรือ"
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.textLight.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'หรือ',
                      style: GoogleFonts.prompt(color: AppColors.textGray, fontSize: 13),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.textLight.withValues(alpha: 0.5))),
                ],
              ),

              const SizedBox(height: 24),

              // ปุ่มเข้าสู่ระบบด้วย Google
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Image.network(
                          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          height: 22,
                          width: 22,
                          errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata_rounded, size: 28),
                        ),
                  label: Text(
                    'เข้าสู่ระบบด้วย Google',
                    style: GoogleFonts.prompt(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ลิงก์ไปหน้าสมัครสมาชิก
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ยังไม่มีบัญชีใช่ไหม? ',
                    style: GoogleFonts.prompt(color: AppColors.textGray, fontSize: 13.5),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      'สมัครสมาชิก',
                      style: GoogleFonts.prompt(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  /// สร้างป้ายชื่อเหนือช่องกรอกข้อมูล
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.prompt(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  /// สร้างช่องกรอกข้อมูลพร้อมไอคอน
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    Widget? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.prompt(fontSize: 15, color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );
  }
}
