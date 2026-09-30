import 'package:flutter/material.dart';

// All colors of the app are here. Change a color here and it changes everywhere.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF8F9FA); // screen background
  static const Color primary = Color(0xFF3CB67C); // green (buttons, links)
  static const Color textDark = Color(0xFF111827); // headings
  static const Color textGrey = Color(0xFF4B5563); // subtitle text
  static const Color icon = Color(0xFF5F6368); // field icons and hint text
  static const Color divider = Color(0xFFDADDE1);
  static const Color error = Color(0xFFE53935); // red error text

  // Soft shadows (color with some transparency)
  static const Color shadow = Color(0x14000000);
  static const Color buttonShadow = Color(0x663CB67C);
}
