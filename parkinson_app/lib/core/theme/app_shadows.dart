import 'package:flutter/material.dart';

class AppShadows {
  static const BoxShadow soft = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const BoxShadow medium = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  static List<BoxShadow> get card => [soft];
  static List<BoxShadow> get elevated => [medium];
}
