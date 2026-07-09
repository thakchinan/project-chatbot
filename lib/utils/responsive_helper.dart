import 'package:flutter/material.dart';

/// Utility class for responsive design helper methods
class ResponsiveHelper {
  /// Gets the screen width
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Gets the screen height
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Returns true if the screen width is less than 600 (Mobile)
  static bool isMobile(BuildContext context) =>
      screenWidth(context) < 600;

  /// Returns true if the screen width is between 600 and 1200 (Tablet)
  static bool isTablet(BuildContext context) =>
      screenWidth(context) >= 600 && screenWidth(context) < 1200;

  /// Returns true if the screen width is 1200 or larger (Desktop/Web)
  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= 1200;

  /// Helper to return values dynamically based on current screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = screenWidth(context);
    if (width >= 1200 && desktop != null) {
      return desktop;
    }
    if (width >= 600 && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// Calculates a responsive text scale factor to prevent overflows on small screens
  /// and take advantage of larger screen real estate.
  static double getResponsiveTextScale(BuildContext context, double baseScale) {
    final width = screenWidth(context);
    
    // Scale down on very small screens to avoid overflow
    if (width < 360) {
      return baseScale * 0.75;
    }
    // Standard phone screen
    if (width < 450) {
      return baseScale * 0.9;
    }
    // Large phone or small tablet
    if (width < 600) {
      return baseScale * 1.0;
    }
    // Tablet
    if (width < 900) {
      return baseScale * 1.15;
    }
    // Large tablet / Desktop
    return baseScale * 1.3;
  }
}
