import 'package:flutter/material.dart';

class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));

  static RoundedRectangleBorder cardShape =
      RoundedRectangleBorder(borderRadius: radiusLg);
  static RoundedRectangleBorder buttonShape =
      RoundedRectangleBorder(borderRadius: radiusMd);
}
