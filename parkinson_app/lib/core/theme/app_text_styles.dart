import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Outfit for headings, Inter for body — calm, legible, accessible.
class AppTextStyles {
  static TextStyle get display =>
      GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5);
  static TextStyle get headingLarge =>
      GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3);
  static TextStyle get headingMedium =>
      GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25);
  static TextStyle get headingSmall =>
      GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);
  static TextStyle get titleSmall =>
      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3);
  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);
  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get labelButton =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4);
  static TextStyle get monoSmall =>
      GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w400);
}
