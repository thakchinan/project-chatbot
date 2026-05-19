import 'package:flutter/material.dart';
import '../models/user.dart';
import 'dashboard/home_screen.dart';
import 'dashboard/phq9_tab_screen.dart';
import 'dashboard/recommendation_screen.dart';
import 'dashboard/profile_screen.dart';
import 'dashboard/activities_dashboard_screen.dart';

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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A7FC1), Color(0xFF6BA3E8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A7FC1).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 10 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isActive ? 26 : 24,
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isActive ? 10 : 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
