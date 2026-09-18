import 'package:flutter/material.dart';

/// Calm premium health-tech palette — spacious, minimal, trustworthy.
/// Dark identity refined: navy/charcoal base, warm white light, single accent.
class AppColors {
  // Brand — refined calmer
  static const Color primary = Color(0xFF0F766E); // calm teal (muted)
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color secondary = Color(0xFFF97364); // soft coral, less saturated
  static const Color accent = Color(0xFFFACC15); // muted gold

  // Backgrounds — deep navy / charcoal vs warm white
  static const Color backgroundDark = Color(0xFF0F172A); // slate-900 navy
  static const Color surfaceDark = Color(0xFF1E293B); // slate-800
  static const Color surfaceDarkElevated = Color(0xFF273449);
  static const Color backgroundLight = Color(0xFFF8FAFC); // slate-50
  static const Color surfaceLight = Colors.white;
  static const Color surfaceLightElevated = Color(0xFFF1F5F9);

  // Text — warm white / soft gray, accessible contrast
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFFF1F5F9);
  static const Color textMutedDark = Color(0xFF94A3B8);
  static const Color textMutedLight = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Status — green / amber / red (red only for genuine attention)
  static const Color statusNormal = Color(0xFF10B981); // emerald
  static const Color statusWatch = Color(0xFFF59E0B); // amber
  static const Color statusAttention = Color(0xFFEF4444); // red, only when important

  // Legacy aliases
  static const Color backgroundLightAlias = backgroundLight;

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
