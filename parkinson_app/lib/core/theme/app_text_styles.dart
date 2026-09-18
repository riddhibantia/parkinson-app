import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inter for body, Outfit for headings.
class AppTextStyles {
  static TextStyle get headingLarge =>
      GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2);

  static TextStyle get headingMedium =>
      GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25);

  static TextStyle get headingSmall =>
      GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get labelButton =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);
}
