import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/muse_service.dart';
import 'caretaker_screen.dart';
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
                        'เลือกกิจกรรม',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'กิจกรรมช่วยคลายเครียดและดูแลสุขภาพจิต',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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

                          Row(
                            children: [
                              Expanded(
                                child: _buildPremiumCard(
                                  icon: Icons.people_alt_rounded,
                                  label: 'ผู้ดูแล',
                                  subtitle: 'ติดต่อผู้ดูแลของคุณ',
                                  gradient: AppGradients.primaryBlue,
                                  iconBgColor: Colors.white.withValues(alpha: 0.2),
                                  delay: 0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CaretakerScreen()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildPremiumCard(
                                  icon: Icons.sports_esports_rounded,
                                  label: 'เกมคลายเครียด',
                                  subtitle: 'บริหารสมองด้วยมินิเกม',
                                  gradient: AppGradients.green,
                                  iconBgColor: Colors.white.withValues(alpha: 0.2),
                                  delay: 1,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => MiniGamesScreen(user: widget.user)),
                                    );
                                  },
                                ),
                              ),
                            ],
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
                            'เคล็ดลับสุขภาพจิต',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: AppColors.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'กิจกรรม',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'คุณ${widget.user.fullName ?? widget.user.username} • ดูแลสุขภาพจิตกันเถอะ!',
                  style: const TextStyle(
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
                MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user)),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: AppTheme.glassDecoration(
                borderRadius: BorderRadius.circular(20),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (delay * 150)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 160,
          decoration: AppTheme.glassDecoration(
            color: gradient.colors[0],
            opacity: 0.12,
            borderColor: gradient.colors[0].withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradient.colors[0].withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -10,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradient.colors[0].withValues(alpha: 0.03),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: gradient.colors[0].withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: gradient.colors[0], size: 26),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: gradient.colors[0],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGray,
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
          height: 120,
          decoration: AppTheme.glassDecoration(
            color: AppColors.primaryBlue,
            opacity: 0.15,
            borderColor: AppColors.primaryBlue.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10, top: -10,
                child: Container(
                  width: 100, height: 100,
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
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: AppColors.primaryBlue, size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'เก็บข้อมูลอารมณ์',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'บันทึก EEG พร้อมกระตุ้นอารมณ์ 6 แบบ เพื่อวิเคราะห์สุขภาพจิต',
                            style: TextStyle(fontSize: 12, color: AppColors.textGray, height: 1.3),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primaryBlue, size: 16),
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
          height: 120,
          decoration: AppTheme.glassDecoration(
            color: const Color(0xFFFFAE96),
            opacity: 0.15,
            borderColor: const Color(0xFFFFAE96).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFAE96).withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: -20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFAE96).withValues(alpha: 0.03),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAE96).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFFFAE96), size: 30),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'โภชนาการคลายเครียด',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'อาหารและสารอาหารที่ช่วยลดความเครียด พร้อมสรรพคุณ',
                            style: TextStyle(
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAE96).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFAE96), size: 16),
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
        color: color,
        opacity: 0.08,
        borderColor: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
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
