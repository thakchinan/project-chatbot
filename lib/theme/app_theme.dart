import 'package:flutter/material.dart';

class AppColors {

  static const Color primaryBlue = Color(0xFF4A7FC1);
  static const Color primaryLightBlue = Color(0xFF89B4E8);
  static const Color accentBlue = Color(0xFF5B9BD5);

  static const Color primaryGreen = Color(0xFF6BBF7A);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color softGreen = Color(0xFFE8F8EA);

  static const Color bgBlue = Color(0xFFE8F4FD);
  static const Color bgGreen = Color(0xFFE8F8EA);
  static const Color bgPurple = Color(0xFFF0F8FF);
  static const Color bgYellow = Color(0xFFFFF8E8);

  static const Color textDark = Color(0xFF1e293b);
  static const Color textGray = Color(0xFF64748b);
  static const Color textLight = Color(0xFF94a3b8);
  

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color orange = Color(0xFFFF9800);

  static const Color chartPurple = Color(0xFF8B5CF6);
  static const Color chartBlue = Color(0xFF5B9BD5);
  static const Color chartGreen = Color(0xFF66BB6A);

  static const Color gameRed = Color(0xFFFF6B6B);
  static const Color gameTeal = Color(0xFF4ECDC4);
  static const Color gameYellow = Color(0xFFFFE66D);
  static const Color gameMint = Color(0xFF95E1D3);
}

class AppGradients {
  static const LinearGradient primaryBlue = LinearGradient(
    colors: [Color(0xFF4A7FC1), Color(0xFF89B4E8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient green = LinearGradient(
    colors: [Color(0xFF6BBF7A), Color(0xFF4CAF50)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient headerBlue = LinearGradient(
    colors: [Color(0xFFE8F4FD), Color(0xFFD4E8F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerGreen = LinearGradient(
    colors: [Color(0xFFE8F8EA), Color(0xFFD5F5E3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerPurple = LinearGradient(
    colors: [Color(0xFFF0F8FF), Color(0xFFE0F2F1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerYellow = LinearGradient(
    colors: [Color(0xFFFFF8E8), Color(0xFFFFF5E6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient memoryGame = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient colorGame = LinearGradient(
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient triviaGame = LinearGradient(
    colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTextStyles {
  static const TextStyle headerTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle heroTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue,
  );

  static const TextStyle heroSubtitle = TextStyle(
    fontSize: 16,
    color: AppColors.textGray,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12,
    color: AppColors.textGray,
  );

  static const TextStyle buttonText = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
}
