import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'dashboard/home_screen.dart';
import 'dashboard/phq9_tab_screen.dart';
import 'dashboard/recommendation_screen.dart';
import 'dashboard/profile_screen.dart';
import 'dashboard/activities_dashboard_screen.dart';
import '../theme/app_theme.dart';

class MainNavigation extends StatefulWidget {
  final User user;

  const MainNavigation({super.key, required this.user});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _onUserUpdated(User updatedUser) {
    setState(() => _currentUser = updatedUser);
  }

  List<Widget> get _screens => [
    HomeScreen(user: _currentUser),
    Phq9TabScreen(user: _currentUser),
    RecommendationScreen(user: _currentUser),
    ActivitiesDashboardScreen(user: _currentUser),
    ProfileScreen(user: _currentUser, onUserUpdated: _onUserUpdated),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows body to scroll behind the floating nav bar
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.85),
                    AppColors.accentBlue.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, 'หน้าแรก'),
                      _buildNavItem(1, Icons.quiz_rounded, 'PHQ-9'),
                      _buildNavItem(2, Icons.chat_bubble_rounded, 'คำแนะนำ'),
                      _buildNavItem(3, Icons.grid_view_rounded, 'กิจกรรม'),
                      _buildNavItem(4, Icons.person_rounded, 'โปรไฟล์'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isActive
                ? Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  )
                : const SizedBox.shrink(), // Hide label when inactive for cleaner look
            ),
          ],
        ),
      ),
    );
  }
}
