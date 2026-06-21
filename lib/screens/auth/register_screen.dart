import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _agreeToTerms = false;
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

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
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }


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

  Future<void> _register() async {
    if (!_agreeToTerms) {
      _showError('กรุณายอมรับเงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัวก่อนสมัครสมาชิก');
      return;
    }

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
              _buildLabel('ชื่อผู้ใช้งาน'),
              _buildTextField(
                controller: _usernameController,
                hintText: 'ระบุชื่อผู้ใช้งาน',
              ),

              const SizedBox(height: 16),

              _buildLabel('อีเมล'),
              _buildTextField(
                controller: _emailController,
                hintText: 'ระบุอีเมลของคุณ',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              _buildLabel('รหัสผ่าน'),
              _buildTextField(
                controller: _passwordController,
                hintText: 'ระบุรหัสผ่านอย่างน้อย 6 ตัวอักษร',
                obscureText: _obscurePassword,
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

              const SizedBox(height: 16),

              _buildLabel('ชื่อ-นามสกุล'),
              _buildTextField(
                controller: _fullNameController,
                hintText: 'ระบุชื่อและนามสกุลจริง',
              ),

              const SizedBox(height: 16),

              _buildLabel('เบอร์โทรศัพท์'),
              _buildTextField(
                controller: _phoneController,
                hintText: 'ระบุเบอร์โทรศัพท์ 10 หลัก',
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),

              const SizedBox(height: 16),

              _buildLabel('วัน/เดือน/ปีเกิด'),
              _buildTextField(
                controller: _birthDateController,
                hintText: 'เลือกวัน/เดือน/ปีเกิดของคุณ',
                readOnly: true,
                onTap: _selectDate,
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),

              const SizedBox(height: 16),

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

              const SizedBox(height: 28),

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
                      : const Text(
                          'สมัครบัญชีใช้งาน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
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
      ),
    );
  }

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
                // Top Handle bar
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
                // Header Row
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
                // TabBar
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
                // TabBarView Content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTermsContent(),
                      _buildPrivacyContent(),
                    ],
                  ),
                ),
                // Bottom Button
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
