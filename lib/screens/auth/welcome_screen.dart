import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F4FD), Colors.white], // Light blue to white gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              children: [
                const SizedBox(height: 40),

                Column(
                  children: [
                    Text(
                      'Smart',
                      style: AppTextStyles.heroTitle.copyWith(
                        color: AppColors.primaryBlue,
                        fontSize: 48,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Brain',
                      style: AppTextStyles.heroTitle.copyWith(
                        color: AppColors.primaryBlue,
                        fontSize: 48,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  'Smart Brain Center',
                  style: AppTextStyles.heroSubtitle.copyWith(
                    color: AppColors.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'แอปพลิเคชันนี้ช่วยให้ผู้สูงอายุสามารถดูแลสุขภาพสมองและสุข\nภาวะทางอารมณ์ได้โดยสามารถติดตามและตรวจสอบสภาพของ\nตนเองได้อย่างง่ายดาย',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardSubtitle.copyWith(
                      color: AppColors.textGray,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 5, // Added elevation for a subtle shadow
                            shadowColor: AppColors.primaryBlue.withOpacity(0.3),
                          ),
                          child: Text(
                            'เข้าสู่ระบบ',
                            style: AppTextStyles.buttonText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: AppColors.primaryBlue, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'สมัครบัญชี',
                            style: AppTextStyles.buttonText.copyWith(color: AppColors.primaryBlue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
