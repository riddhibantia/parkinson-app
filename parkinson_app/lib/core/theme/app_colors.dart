import 'package:flutter/material.dart';

/// Calming, accessible, health-oriented palette.
/// NOT generic blues. Status colors never use red.
class AppColors {
  // Brand
  static const Color primary = Color(0xFF0D6E6E); // Deep Teal
  static const Color secondary = Color(0xFFFF6B6B); // Warm Coral
  static const Color accent = Color(0xFFFFD93D); // Soft Gold

  // Backgrounds
  static const Color backgroundDark = Color(0xFF0A0E21); // Off-Black
  static const Color backgroundLight = Color(0xFFFAF9F6); // Warm White

  // Status — green / amber / orange only, never red.
  static const Color statusNormal = Color(0xFF2EAD6B);
  static const Color statusWatch = Color(0xFFE5A800);
  static const Color statusAttention = Color(0xFFE67E22);

  // Text
  static const Color textDark = Color(0xFF0A0E21);
  static const Color textLight = Color(0xFFF5F4EF);
  static const Color textMutedDark = Color(0xFF8A8FA3);
  static const Color textMutedLight = Color(0xFF6B6F7E);

  static Color statusFor(String status) {
    switch (status) {
      case 'watch':
        return statusWatch;
      case 'attention':
        return statusAttention;
      case 'normal':
      default:
        return statusNormal;
    }
  }
}
