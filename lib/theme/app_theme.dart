import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Premium, softer and slate-like pastel blues
  static const Color primaryBlue = Color(0xFF7E9CB9);
  static const Color primaryLightBlue = Color(0xFFC4D3E3);
  static const Color accentBlue = Color(0xFF9EBAE3);

  // Soft pastel greens
  static const Color primaryGreen = Color(0xFF8EBAA7);
  static const Color lightGreen = Color(0xFFB3D4C5);
  static const Color softGreen = Color(0xFFE5F5EE);

  // Elegant Backgrounds (very light and clean)
  static const Color bgBlue = Color(0xFFF2F6FC);
  static const Color bgGreen = Color(0xFFF3FAF6);
  static const Color bgPurple = Color(0xFFF7F6FC);
  static const Color bgYellow = Color(0xFFFCFAF5);

  // Sophisticated Text Colors
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGray = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Softer Semantic Colors
  static const Color success = Color(0xFF89C9B1);
  static const Color warning = Color(0xFFF7C882);
  static const Color error = Color(0xFFECA3A3);
  static const Color orange = Color(0xFFF7B08B);

  // Chart
  static const Color chartPurple = Color(0xFFC3B0E9);
  static const Color chartBlue = Color(0xFF9CB8E2);
  static const Color chartGreen = Color(0xFF8BC5AE);

  // Games
  static const Color gameRed = Color(0xFFF3A0A0);
  static const Color gameTeal = Color(0xFF9AD5D1);
  static const Color gameYellow = Color(0xFFFFF09E);
  static const Color gameMint = Color(0xFFC7EDE6);
}

class AppGradients {
  static const LinearGradient primaryBlue = LinearGradient(
    colors: [Color(0xFF7E9CB9), Color(0xFF9EBAE3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient green = LinearGradient(
    colors: [Color(0xFF8EBAA7), Color(0xFFB3D4C5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerBlue = LinearGradient(
    colors: [Color(0xFFF2F6FC), Color(0xFFE4ECF6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerGreen = LinearGradient(
    colors: [Color(0xFFF3FAF6), Color(0xFFE4F3EC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerPurple = LinearGradient(
    colors: [Color(0xFFF7F6FC), Color(0xFFECEAF7)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerYellow = LinearGradient(
    colors: [Color(0xFFFCFAF5), Color(0xFFF6F0E4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient memoryGame = LinearGradient(
    colors: [Color(0xFF9DA8E3), Color(0xFFC0AEE3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient colorGame = LinearGradient(
    colors: [Color(0xFFF9B8CE), Color(0xFFF9A8BA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient triviaGame = LinearGradient(
    colors: [Color(0xFF8EC4BA), Color(0xFFAFE3D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassBackgroundGradient = LinearGradient(
    colors: [Color(0xFFEBF2FA), Color(0xFFFAFDFF), Color(0xFFF4F7F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTextStyles {
  static const TextStyle headerTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: -0.5,
  );

  static const TextStyle heroTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryBlue,
    letterSpacing: -0.5,
  );

  static const TextStyle heroSubtitle = TextStyle(
    fontSize: 16,
    color: AppColors.textGray,
    height: 1.4,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textGray,
    height: 1.3,
  );

  static const TextStyle buttonText = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentBlue,
        background: Colors.white,
        surface: Colors.white,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: AppColors.textDark,
        onSurface: AppColors.textDark,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFBFF), // Extremely light blue/grey
      textTheme: GoogleFonts.promptTextTheme().apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: GoogleFonts.prompt(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.prompt(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.prompt(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.prompt(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.prompt(color: AppColors.textLight),
        labelStyle: GoogleFonts.prompt(color: AppColors.textGray),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.textDark,
        contentTextStyle: GoogleFonts.prompt(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 20,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: GoogleFonts.prompt(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.prompt(fontWeight: FontWeight.w400, fontSize: 12),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Premium subtle shadow for cards and containers
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get coloredShadow => [
    BoxShadow(
      color: AppColors.primaryBlue.withValues(alpha: 0.2),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static BoxDecoration glassDecoration({
    BorderRadiusGeometry? borderRadius,
    Color? color,
    double opacity = 0.55,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      border: Border.all(
        color: (borderColor ?? Colors.white).withValues(alpha: 0.65),
        width: 1.5,
      ),
      boxShadow: glassShadow,
    );
  }
}
