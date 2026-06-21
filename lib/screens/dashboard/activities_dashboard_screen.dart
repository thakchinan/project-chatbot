import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import 'eeg_session_screen.dart';
import 'mini_games_screen.dart';
import 'nutrition_screen.dart';
import 'settings_screen.dart';

class ActivitiesDashboardScreen extends StatefulWidget {
  final User user;

  const ActivitiesDashboardScreen({super.key, required this.user});

  @override
  State<ActivitiesDashboardScreen> createState() => _ActivitiesDashboardScreenState();
}

class _ActivitiesDashboardScreenState extends State<ActivitiesDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                _buildHeader(),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เลือกกิจกรรมประเมิน',
                        style: GoogleFonts.prompt(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'กิจกรรมจำลองและฝึกบริหารสภาวะจิตเชิงรุก',
                        style: GoogleFonts.prompt(
                          fontSize: 12.5,
                          color: AppColors.textGray,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [

                          _buildPremiumCard(
                            icon: Icons.sports_esports_rounded,
                            label: 'เกมคลายเครียด',
                            subtitle: 'บริหารสมองด้วยมินิเกม',
                            gradient: AppGradients.green,
                            iconBgColor: Colors.white.withValues(alpha: 0.2),
                            delay: 0,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => MiniGamesScreen(user: widget.user)),
                              );
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildFeaturedEegSessionCard(),

                          const SizedBox(height: 14),

                          _buildFeaturedNutritionCard(),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'คำแนะนำสุขภาพจิต',
                            style: GoogleFonts.prompt(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildTipCard(
                        icon: Icons.self_improvement_rounded,
                        title: 'หายใจลึกๆ 4-7-8',
                        description: 'หายใจเข้า 4 วินาที กลั้น 7 วินาที หายใจออก 8 วินาที ช่วยลดความเครียดทันที',
                        color: const Color(0xFF6C63FF),
                      ),
                      _buildTipCard(
                        icon: Icons.directions_walk_rounded,
                        title: 'เดินเล่น 15 นาที',
                        description: 'การเดินเล่นในธรรมชาติช่วยลดระดับ cortisol (ฮอร์โมนความเครียด) ได้ถึง 20%',
                        color: const Color(0xFF4CAF50),
                      ),
                      _buildTipCard(
                        icon: Icons.music_note_rounded,
                        title: 'ฟังเพลงที่ชอบ',
                        description: 'ดนตรีช่วยกระตุ้นการหลั่ง dopamine ทำให้รู้สึกมีความสุขและผ่อนคลาย',
                        color: const Color(0xFFFF6B6B),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          // Activity Hexagon badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.glassDecoration(
              color: AppColors.primaryBlue,
              opacity: 0.1,
              borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
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
                  'ศูนย์รวมกิจกรรม',
                  style: GoogleFonts.prompt(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'คุณ${widget.user.fullName ?? widget.user.username} • บริหารสมองและการควบคุมอารมณ์',
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
                MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user)),
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
    );
  }

  Widget _buildPremiumCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Gradient gradient,
    required Color iconBgColor,
    required int delay,
    required VoidCallback onTap,
  }) {
    final cardColor = gradient.colors[0];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (delay * 150)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + (0.15 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 150,
          decoration: AppTheme.glassDecoration(
            color: cardColor,
            opacity: 0.12,
            borderColor: cardColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              // Subtle Medical Grid Pattern overlay (Visual effect)
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPatternPainter(color: cardColor.withValues(alpha: 0.05)),
                ),
              ),
              Positioned(
                top: -15,
                right: -15,
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Icon(icon, color: cardColor, size: 24),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'TRAINING',
                            style: GoogleFonts.prompt(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: cardColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.prompt(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: cardColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.prompt(
                            fontSize: 12,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedEegSessionCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EegSessionScreen(
                user: widget.user,
                museService: MuseService(),
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          height: 125,
          decoration: AppTheme.glassDecoration(
            color: AppColors.primaryBlue,
            opacity: 0.15,
            borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPatternPainter(color: AppColors.primaryBlue.withValues(alpha: 0.04)),
                ),
              ),
              Positioned(
                right: -15, top: -15,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: AppColors.primaryBlue, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                'บันทึกข้อมูลอารมณ์',
                                style: GoogleFonts.prompt(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.neonGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'เชื่อมต่อเซนเซอร์ EEG เพื่อเริ่มทำการบันทึกและประเมินจิตวิทยาคลินิก',
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              color: AppColors.textGray,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: AppTheme.glassDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        opacity: 0.8,
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primaryBlue, size: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedNutritionCard() {
    const nutritionColor = Color(0xFFE27455);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NutritionScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          height: 125,
          decoration: AppTheme.glassDecoration(
            color: nutritionColor,
            opacity: 0.12,
            borderColor: nutritionColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPatternPainter(color: nutritionColor.withValues(alpha: 0.04)),
                ),
              ),
              Positioned(
                right: -15,
                top: -15,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nutritionColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: nutritionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: nutritionColor.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: nutritionColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'โภชนาการคลายเครียด',
                            style: GoogleFonts.prompt(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'เลือกรับประทานอาหารที่อุดมสารอาหารบำรุงระบบประสาท',
                            style: GoogleFonts.prompt(
                              fontSize: 12,
                              color: AppColors.textGray,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: AppTheme.glassDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        opacity: 0.8,
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: nutritionColor, size: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        color: Colors.white,
        opacity: 0.9,
        borderColor: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // Left visual indicator tag line
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.prompt(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.prompt(
                    fontSize: 12,
                    color: AppColors.textGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple Painter for medical-grade grid pattern overlay
class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 15.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
