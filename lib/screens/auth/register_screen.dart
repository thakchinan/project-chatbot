import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1970),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _register() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty || _emailController.text.isEmpty) {
      _showError('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showError('อีเมลต้องมีเครื่องหมาย @');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }

    if (_phoneController.text.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(_phoneController.text)) {
      _showError('เบอร์โทรศัพท์ต้องเป็นตัวเลข 10 หลักเท่านั้น');
      return;
    }

    setState(() => _isLoading = true);

    String? birthDate;
    if (_birthDateController.text.isNotEmpty) {
      final parts = _birthDateController.text.split('/');
      if (parts.length == 3) {
        birthDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }

    final result = await ApiService.register(
      username: _usernameController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      birthDate: birthDate,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      _showError(result['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

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
          'สร้างบัญชีใหม่',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildLabel('ชื่อผู้ใช้งาน'),
            _buildTextField(
              controller: _usernameController,
              hintText: 'username',
            ),

            const SizedBox(height: 16),

            _buildLabel('อีเมล'),
            _buildTextField(
              controller: _emailController,
              hintText: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            _buildLabel('รหัสผ่าน'),
            _buildTextField(
              controller: _passwordController,
              hintText: '••••••••',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),

            const SizedBox(height: 16),

            _buildLabel('ชื่อ-นามสกุล'),
            _buildTextField(
              controller: _fullNameController,
              hintText: 'example@example.com',
            ),

            const SizedBox(height: 16),

            _buildLabel('เบอร์โทรศัพท์'),
            _buildTextField(
              controller: _phoneController,
              hintText: '0xxxxxxxxx',
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),

            const SizedBox(height: 16),

            _buildLabel('วัน/เดือน/ปีเกิด'),
            GestureDetector(
              onTap: _selectDate,
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: _birthDateController,
                  hintText: 'DD / MM / YYY',
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'การสร้างบัญชีหมายความว่าคุณยอมรับ เงื่อนไขการใช้งาน\nและ นโยบายความเป็นส่วนตัว ของเรา',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'สมัครบัญชี',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'มีบัญชีอยู่แล้วใช่ไหม? ',
                  style: TextStyle(color: Colors.grey[600]),
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
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
