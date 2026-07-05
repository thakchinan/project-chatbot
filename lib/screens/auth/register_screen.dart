import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/password_validator.dart';
import 'login_screen.dart';

/// RegisterScreen เป็นหน้าจอกรอกข้อมูลสมัครสมาชิกใหม่สำหรับแอปพลิเคชัน
/// รองรับ:
///   1. สมัครด้วย Email + Password (ผ่าน Supabase Auth) พร้อม Password Strength Indicator
///   2. สมัครด้วย Google Sign-In
/// ประกอบด้วย Bottom Sheet กฎเงื่อนไขการใช้บริการ (Terms) และนโยบายความเป็นส่วนตัว (Privacy Policy)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // คอนโทรลเลอร์ควบคุมช่องกรอกข้อมูลฟอร์มลงทะเบียน
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  bool _obscurePassword = true;        // เปิด/ปิด การซ่อนรหัสผ่านในกล่องข้อความ
  bool _obscureConfirmPassword = true;  // เปิด/ปิด การซ่อนช่องยืนยันรหัสผ่าน
  bool _isLoading = false;             // บอกสถานะการโหลดระหว่างส่งข้อมูล API
  bool _isGoogleLoading = false;       // บอกสถานะการโหลด Google Sign-In
  bool _agreeToTerms = false;          // เช็คว่ายอมรับข้อตกลงการใช้งานหรือยัง
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  // ผลลัพธ์การตรวจสอบรหัสผ่าน — อัปเดตเมื่อผู้ใช้พิมพ์
  PasswordResult? _passwordResult;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        _showTermsAndPrivacyBottomSheet(context, initialTab: 0);
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        _showTermsAndPrivacyBottomSheet(context, initialTab: 1);
      };

    // ติดตามการพิมพ์รหัสผ่านเพื่ออัปเดตแถบความแข็งแรงแบบเรียลไทม์
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  /// เรียกเมื่อรหัสผ่านเปลี่ยน เพื่ออัปเดตแถบความแข็งแรงแบบเรียลไทม์
  void _onPasswordChanged() {
    setState(() {
      _passwordResult = PasswordValidator.evaluate(_passwordController.text);
    });
  }

  /// เปิด Date Picker เลือกวันเกิด
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1970),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  /// สมัครสมาชิกด้วย Email + Password ผ่าน Supabase Auth
  Future<void> _register() async {
    if (!_agreeToTerms) {
      _showError('กรุณายอมรับเงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัวก่อนสมัครสมาชิก');
      return;
    }

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    // ตรวจสอบรูปแบบอีเมล
    if (!PasswordValidator.isValidEmail(_emailController.text.trim())) {
      _showError('กรุณากรอกอีเมลให้ถูกต้อง เช่น example@gmail.com');
      return;
    }

    // ตรวจสอบความแข็งแรงของรหัสผ่าน
    if (!PasswordValidator.isAcceptable(_passwordController.text)) {
      _showError('รหัสผ่านไม่ผ่านเกณฑ์ความปลอดภัย กรุณาตรวจสอบเงื่อนไขรหัสผ่าน');
      return;
    }

    // ตรวจสอบรหัสผ่านยืนยัน
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('รหัสผ่านและรหัสผ่านยืนยันไม่ตรงกัน');
      return;
    }

    // ตรวจสอบเบอร์โทรศัพท์ (ถ้ากรอก)
    if (_phoneController.text.isNotEmpty) {
      if (_phoneController.text.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(_phoneController.text)) {
        _showError('เบอร์โทรศัพท์ต้องเป็นตัวเลข 10 หลักเท่านั้น');
        return;
      }
    }

    setState(() => _isLoading = true);

    // แปลงวันเกิดเป็นรูปแบบ YYYY-MM-DD
    String? birthDate;
    if (_birthDateController.text.isNotEmpty) {
      final parts = _birthDateController.text.split('/');
      if (parts.length == 3) {
        birthDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    final result = await AuthService.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      birthDate: birthDate,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        // แสดง Dialog แจ้งให้ยืนยัน email
        _showVerificationDialog();
      }
    } else {
      _showError(result['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

  /// สมัครด้วย Google Sign-In
  Future<void> _registerWithGoogle() async {
    if (!_agreeToTerms) {
      _showError('กรุณายอมรับเงื่อนไขการใช้งานก่อนสมัครด้วย Google');
      return;
    }

    setState(() => _isGoogleLoading = true);

    final result = await AuthService.signInWithGoogle();

    setState(() => _isGoogleLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกด้วย Google สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      if (result['message'] != 'ยกเลิกการเข้าสู่ระบบด้วย Google') {
        _showError(result['message'] ?? 'เกิดข้อผิดพลาด');
      }
    }
  }

  /// แสดง Dialog ให้ผู้ใช้กรอก OTP 6-8 หลักจากอีเมลเพื่อยืนยันตัวตน
  void _showVerificationDialog() {
    final otpController = TextEditingController();
    int countdown = 60;
    bool canResend = false;
    bool isVerifying = false;
    bool timerStarted = false;
    String? errorText;
    Timer? countdownTimer;

    void startTimer(StateSetter setState) {
      countdown = 60;
      canResend = false;
      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown > 0) {
          setState(() => countdown--);
        } else {
          setState(() => canResend = true);
          timer.cancel();
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            // เริ่มนับถอยหลังเมื่อ Dialog เปิดขึ้นมาครั้งแรก
            if (!timerStarted) {
              timerStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                startTimer(setDialogState);
              });
            }

            Future<void> verify() async {
              final code = otpController.text.trim();
              if (code.length < 6 || code.length > 8) {
                setDialogState(() => errorText = 'กรุณากรอกรหัสยืนยัน 6-8 หลักให้ครบถ้วน');
                return;
              }
              setDialogState(() { isVerifying = true; errorText = null; });

              final result = await AuthService.verifySignUpOTP(
                email: _emailController.text.trim(),
                token: code,
              );

              if (!mounted) return;
              setDialogState(() => isVerifying = false);

              if (result['success'] == true) {
                Navigator.pop(dialogContext);
                _showSuccessAndNavigate();
              } else {
                setDialogState(() => errorText = result['message'] ?? 'รหัสยืนยันไม่ถูกต้อง');
              }
            }

            Future<void> resend() async {
              setDialogState(() { errorText = null; canResend = false; });
              final result = await AuthService.resendVerificationEmail(_emailController.text.trim());
              if (result['success'] == true) {
                startTimer(setDialogState);
              } else {
                setDialogState(() => errorText = result['message']);
              }
            }

            return PopScope(
              canPop: false,
              child: AlertDialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ปุ่มปิด (ข้ามการยืนยัน → ไปหน้า Login)
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(dialogContext);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: AppColors.textGray, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ไอคอนอีเมล
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mark_email_read_rounded, size: 48, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 16),

                      // หัวข้อ
                      Text(
                        'ยืนยันอีเมลของคุณ',
                        style: GoogleFonts.prompt(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'เราได้ส่งรหัสยืนยันไปยังอีเมลของคุณแล้ว',
                        style: GoogleFonts.prompt(fontSize: 13, color: AppColors.textGray),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text.trim(),
                        style: GoogleFonts.prompt(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // ช่องกรอก OTP (รองรับ 6-8 หลัก)
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: otpController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          style: GoogleFonts.prompt(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'กรอกรหัสยืนยัน',
                            hintStyle: GoogleFonts.prompt(
                              fontSize: 14,
                              letterSpacing: 0,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.normal,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          onChanged: (_) {
                            setDialogState(() => errorText = null);
                          },
                        ),
                      ),

                      // ข้อความ error
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText!,
                          style: GoogleFonts.prompt(fontSize: 12, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ปุ่มยืนยันรหัส OTP
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isVerifying ? null : verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isVerifying
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text('ยืนยันรหัส', style: GoogleFonts.prompt(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ส่งรหัส OTP ซ้ำ พร้อมนับถอยหลัง
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ไม่ได้รับรหัส? ', style: GoogleFonts.prompt(fontSize: 12.5, color: AppColors.textGray)),
                          canResend
                              ? GestureDetector(
                                  onTap: resend,
                                  child: Text(
                                    'ส่งรหัสอีกครั้ง',
                                    style: GoogleFonts.prompt(fontSize: 12.5, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : Text(
                                  'ส่งอีกครั้งใน ${countdown}s',
                                  style: GoogleFonts.prompt(fontSize: 12.5, color: AppColors.textGray),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      countdownTimer?.cancel();
      otpController.dispose();
    });
  }

  /// แสดงข้อความยืนยันสำเร็จ แล้วนำไปหน้าเข้าสู่ระบบ
  void _showSuccessAndNavigate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ยืนยันอีเมลสำเร็จ! กรุณาเข้าสู่ระบบ', style: GoogleFonts.prompt()),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// แสดง Snackbar แจ้งข้อผิดพลาด
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
            'สร้างบัญชีใหม่',
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
              // อีเมล
              _buildLabel('อีเมล'),
              _buildTextField(
                controller: _emailController,
                hintText: 'ระบุอีเมลของคุณ เช่น example@gmail.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),

              const SizedBox(height: 16),

              // รหัสผ่าน
              _buildLabel('รหัสผ่าน'),
              _buildTextField(
                controller: _passwordController,
                hintText: 'ตั้งรหัสผ่านอย่างน้อย 8 ตัวอักษร',
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

              // แถบความแข็งแรงของรหัสผ่าน
              if (_passwordController.text.isNotEmpty && _passwordResult != null)
                _buildPasswordStrengthIndicator(),

              const SizedBox(height: 16),

              // ยืนยันรหัสผ่าน
              _buildLabel('ยืนยันรหัสผ่าน'),
              _buildTextField(
                controller: _confirmPasswordController,
                hintText: 'กรอกรหัสผ่านอีกครั้ง',
                obscureText: _obscureConfirmPassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textGray,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ชื่อ-นามสกุล
              _buildLabel('ชื่อ-นามสกุล'),
              _buildTextField(
                controller: _fullNameController,
                hintText: 'ระบุชื่อและนามสกุลจริง',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),

              const SizedBox(height: 16),

              // เบอร์โทรศัพท์
              _buildLabel('เบอร์โทรศัพท์'),
              _buildTextField(
                controller: _phoneController,
                hintText: 'ระบุเบอร์โทรศัพท์ 10 หลัก',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              ),

              const SizedBox(height: 16),

              // วันเกิด
              _buildLabel('วัน/เดือน/ปีเกิด'),
              _buildTextField(
                controller: _birthDateController,
                hintText: 'เลือกวัน/เดือน/ปีเกิดของคุณ',
                readOnly: true,
                onTap: _selectDate,
                prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),

              const SizedBox(height: 16),

              // ข้อตกลงการใช้งาน
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
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
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.prompt(
                          fontSize: 12,
                          color: AppColors.textGray,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'ฉันยอมรับ '),
                          TextSpan(
                            text: 'เงื่อนไขการใช้งาน',
                            style: GoogleFonts.prompt(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _termsRecognizer,
                          ),
                          const TextSpan(text: ' และ '),
                          TextSpan(
                            text: 'นโยบายความเป็นส่วนตัว',
                            style: GoogleFonts.prompt(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: _privacyRecognizer,
                          ),
                          const TextSpan(text: ' ของแอปพลิเคชัน'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ปุ่มสมัครสมาชิก
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
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
                          'สมัครบัญชีใช้งาน',
                          style: GoogleFonts.prompt(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

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

              const SizedBox(height: 20),

              // ปุ่มสมัครด้วย Google
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isGoogleLoading ? null : _registerWithGoogle,
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
                    'สมัครด้วย Google',
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

              const SizedBox(height: 20),

              // ลิงก์ไปหน้าเข้าสู่ระบบ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'มีบัญชีอยู่แล้วใช่ไหม? ',
                    style: GoogleFonts.prompt(color: AppColors.textGray, fontSize: 13.5),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      'เข้าสู่ระบบ',
                      style: GoogleFonts.prompt(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ═══════════════════════════════════════════
  //  Widget ย่อย — Password Strength Indicator
  // ═══════════════════════════════════════════

  /// แสดงแถบวัดความแข็งแรงของรหัสผ่าน + Checklist เกณฑ์แต่ละข้อ
  Widget _buildPasswordStrengthIndicator() {
    final result = _passwordResult!;
    final checks = result.checks;

    // เลือกสี/ข้อความตามระดับความแข็งแรง
    Color strengthColor;
    String strengthLabel;
    double strengthProgress;

    switch (result.strength) {
      case PasswordStrength.weak:
        strengthColor = Colors.red;
        strengthLabel = 'อ่อน';
        strengthProgress = result.score / 5;
      case PasswordStrength.medium:
        strengthColor = Colors.orange;
        strengthLabel = 'ปานกลาง';
        strengthProgress = result.score / 5;
      case PasswordStrength.strong:
        strengthColor = Colors.green;
        strengthLabel = 'แข็งแรง';
        strengthProgress = 1.0;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // แถบความแข็งแรง
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strengthProgress,
                    backgroundColor: Colors.grey.shade200,
                    color: strengthColor,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthLabel,
                style: GoogleFonts.prompt(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Checklist เกณฑ์แต่ละข้อ
          _buildCheckItem('อย่างน้อย 8 ตัวอักษร', checks.minLength),
          _buildCheckItem('มีตัวพิมพ์ใหญ่ (A-Z)', checks.hasUppercase),
          _buildCheckItem('มีตัวพิมพ์เล็ก (a-z)', checks.hasLowercase),
          _buildCheckItem('มีตัวเลข (0-9)', checks.hasDigit),
          _buildCheckItem('มีอักขระพิเศษ (!@#\$%)', checks.hasSpecialChar),
        ],
      ),
    );
  }

  /// สร้างเช็คมาร์กสำหรับเกณฑ์รหัสผ่านแต่ละข้อ
  Widget _buildCheckItem(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: passed ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.prompt(
              fontSize: 12,
              color: passed ? Colors.green.shade700 : AppColors.textGray,
              fontWeight: passed ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Widget ย่อย — Build Helper
  // ═══════════════════════════════════════════

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
    int? maxLength,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      readOnly: readOnly,
      onTap: onTap,
      style: GoogleFonts.prompt(fontSize: 15, color: AppColors.textDark),
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  Bottom Sheet — เงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัว
  // ═══════════════════════════════════════════

  void _showTermsAndPrivacyBottomSheet(BuildContext context, {required int initialTab}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DefaultTabController(
          length: 2,
          initialIndex: initialTab,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // แถบจับด้านบน
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 8),
                // หัวข้อ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ข้อตกลงและนโยบาย',
                        style: GoogleFonts.prompt(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // แท็บเลือกหมวด
                TabBar(
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textGray,
                  indicatorColor: AppColors.primaryBlue,
                  labelStyle: GoogleFonts.prompt(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: GoogleFonts.prompt(fontWeight: FontWeight.normal, fontSize: 14),
                  tabs: const [
                    Tab(text: 'เงื่อนไขการใช้งาน'),
                    Tab(text: 'นโยบายความเป็นส่วนตัว'),
                  ],
                ),
                // เนื้อหา
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTermsContent(),
                      _buildPrivacyContent(),
                    ],
                  ),
                ),
                // ปุ่มยอมรับ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _agreeToTerms = true;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'ยอมรับและดำเนินการต่อ',
                          style: GoogleFonts.prompt(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('เงื่อนไขการใช้บริการแอปพลิเคชัน (Terms of Use)'),
          const SizedBox(height: 12),
          _buildSectionText(
            'ยินดีต้อนรับสู่แอปพลิเคชันวิเคราะห์สภาวะสมองและอารมณ์ของเรา กรุณาอ่านและทำความเข้าใจข้อตกลงและเงื่อนไขการใช้บริการนี้โดยละเอียดก่อนเริ่มต้นใช้งาน',
          ),
          const Divider(height: 32),
          _buildSectionTitle('1. วัตถุประสงค์และการจำกัดความรับผิดชอบ'),
          _buildSectionBody(
            'แอปพลิเคชันนี้ออกแบบมาสำหรับการประเมินสภาวะทางอารมณ์ ระดับความเครียด และการฝึกสมาธิเบื้องต้นผ่านสัญญาณคลื่นไฟฟ้าสมอง (EEG) ผลลัพธ์และคำแนะนำทั้งหมดใช้เพื่อวัตถุประสงค์ในการศึกษา ติดตามแนวโน้มส่วนบุคคล และเพื่อความบันเทิงเท่านั้น "ไม่ใช่ข้อมูลวินิจฉัยทางการแพทย์" และไม่สามารถใช้ทดแทนคำปรึกษาจากแพทย์ผู้เชี่ยวชาญได้',
          ),
          _buildSectionTitle('2. ความรับผิดชอบต่อบัญชีผู้ใช้'),
          _buildSectionBody(
            'ผู้ใช้บริการตกลงที่จะให้ข้อมูลที่เป็นจริง ถูกต้อง และเป็นปัจจุบันในการลงทะเบียนเข้าใช้งาน และมีหน้าที่รักษาความลับของชื่อผู้ใช้งานและรหัสผ่าน หากตรวจพบกิจกรรมที่น่าสงสัยเกี่ยวกับการใช้งานบัญชีผู้ใช้ คุณตกลงที่จะแจ้งให้ทีมงานทราบทันที',
          ),
          _buildSectionTitle('3. การเชื่อมต่ออุปกรณ์ตรวจวัด'),
          _buildSectionBody(
            'การประมวลผลคลื่นสมองในแอปพลิเคชันจำเป็นต้องเชื่อมต่อกับอุปกรณ์ตรวจวัดสัญญาณสมองที่รองรับ (เช่น แถบคาดศีรษะ Muse) ผู้ใช้บริการต้องมีอุปกรณ์ดังกล่าวและมีหน้าที่รับผิดชอบต่อความเสี่ยง ความปลอดภัย และการจัดเก็บแบตเตอรี่ของอุปกรณ์ตนเอง',
          ),
          _buildSectionTitle('4. การจำกัดสิทธิ์และการอนุญาตสิทธิ์การใช้งาน'),
          _buildSectionBody(
            'ทางระบบมอบสิทธิ์การใช้งานแอปพลิเคชันแบบจำกัด ไม่สามารถโอนสิทธิ์ได้ และห้ามนำโค้ด ส่วนติดต่อผู้ใช้ หรือข้อมูลในแอปพลิเคชันไปดัดแปลง คัดลอก หรือนำไปใช้ในเชิงพาณิชย์โดยไม่ได้รับความยินยอมเป็นลายลักษณ์อักษรจากเรา',
          ),
          _buildSectionTitle('5. การปรับปรุงและการยุติการให้บริการ'),
          _buildSectionBody(
            'เราขอสงวนสิทธิ์ในการปรับปรุง เปลี่ยนแปลง หรือยุติการให้บริการส่วนใดส่วนหนึ่ง หรือทั้งหมดของแอปพลิเคชัน โดยอาจจะมีการแจ้งให้ผู้ใช้ทราบล่วงหน้าผ่านทางระบบ',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('นโยบายความเป็นส่วนตัว (Privacy Policy)'),
          const SizedBox(height: 12),
          _buildSectionText(
            'เราตระหนักถึงความสำคัญของข้อมูลส่วนบุคคลของคุณ นโยบายนี้อธิบายถึงวิธีการจัดเก็บ นำไปใช้ และปกป้องข้อมูลของคุณเมื่อใช้งานแอปพลิเคชันนี้',
          ),
          const Divider(height: 32),
          _buildSectionTitle('1. ข้อมูลที่เราจัดเก็บและวิธีจัดเก็บ'),
          _buildSectionBody(
            '- ข้อมูลส่วนตัวพื้นฐาน: ชื่อผู้ใช้งาน, อีเมล, เบอร์โทรศัพท์ และวันเกิด สำหรับการลงทะเบียนและระบุตัวตน\n'
            '- ข้อมูลสรีรวิทยาและสมอง: สัญญาณคลื่นไฟฟ้าสมองดิบ (Raw EEG data) ที่ตรวจวัดได้จากอุปกรณ์เชื่อมต่อ, ระดับคลื่นสมองแยกตามย่านความถี่ (Alpha, Beta, Gamma, Delta, Theta)\n'
            '- ข้อมูลผลลัพธ์การใช้งาน: ผลการประเมินสมาธิ, คะแนนความผ่อนคลาย, และระดับสภาวะทางอารมณ์',
          ),
          _buildSectionTitle('2. การนำข้อมูลไปใช้งาน'),
          _buildSectionBody(
            'เรานำข้อมูลที่รวบรวมมาใช้เพื่อ:\n'
            '- ประมวลผลและจำลองความเปลี่ยนแปลงทางอารมณ์ สมาธิ และทัศนคติในแอปพลิเคชัน\n'
            '- พัฒนาและปรับปรุงอัลกอริทึมการเรียนรู้ของเครื่อง (Machine Learning) ให้มีความแม่นยำยิ่งขึ้น\n'
            '- แสดงรายงานประวัติย้อนหลังและข้อมูลสรุปเพื่อการดูแลสุขภาพทางใจส่วนตัวของคุณ',
          ),
          _buildSectionTitle('3. การรักษาความปลอดภัยและความเป็นส่วนตัว'),
          _buildSectionBody(
            'ข้อมูลคลื่นสมองและสุขภาพของคุณถือเป็นความลับสูงสุด เราใช้มาตรการเข้ารหัสข้อมูล (Encryption) ทั้งในส่วนการส่งผ่านข้อมูลและการจัดเก็บ และจะไม่เปิดเผย ขาย หรือแบ่งปันข้อมูลส่วนบุคคลของท่านแก่บุคคลภายนอก เว้นแต่จะได้รับความยินยอมโดยชัดแจ้งจากท่าน',
          ),
          _buildSectionTitle('4. สิทธิ์ของเจ้าของข้อมูลส่วนบุคคล'),
          _buildSectionBody(
            'คุณมีสิทธิ์เข้าถึง ขอรับสำเนา ขอให้แก้ไข หรือขอให้ลบข้อมูลส่วนบุคคลทั้งหมดรวมถึงประวัติคลื่นสมองของคุณออกจากฐานข้อมูลของเราเมื่อใดก็ได้ โดยสามารถทำเรื่องผ่านเมนูการตั้งค่า หรือติดต่อฝ่ายสนับสนุนของเรา',
          ),
          _buildSectionTitle('5. การติดต่อเรา'),
          _buildSectionBody(
            'หากคุณมีข้อสงสัยหรือข้อคำถามเกี่ยวกับเงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัวนี้ สามารถติดต่อทีมงานผู้พัฒนาผ่านช่องทางติดต่อในแอปพลิเคชัน',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: GoogleFonts.prompt(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Text(
      text,
      style: GoogleFonts.prompt(
        fontSize: 13,
        color: AppColors.textDark,
        height: 1.6,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.prompt(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: GoogleFonts.prompt(
        fontSize: 13,
        color: AppColors.textGray,
        height: 1.6,
      ),
    );
  }
}
