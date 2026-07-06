import 'package:flutter/material.dart';
import 'app_theme.dart';

class HRColors {
  static const Color brandGreen = Color(0xFF065F46);
  static const Color greenMid   = Color(0xFF10B981);
  static const Color surface    = Color(0xFFF1F8F4);
  static const Color cardBorder = Color(0x1A065F46);
  static const Color shadowLite = Color(0x14000000);
}

const LinearGradient hrHeaderGradient = LinearGradient(
  colors: [HRColors.brandGreen, HRColors.greenMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Optimized HR Theme using global factory.
ThemeData buildHRTheme() {
  return createDepartmentTheme(
    seedColor: HRColors.brandGreen,
  );
}
