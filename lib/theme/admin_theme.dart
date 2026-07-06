import 'package:flutter/material.dart';
import 'app_theme.dart';

class AdminColors {
  static const Color brandPurple = Color(0xFF2A0A4B);
  static const Color purpleMid   = Color(0xFF5C2EA0);
  static const Color surface     = Color(0xFFF7F4FF);
  static const Color cardBorder  = Color(0x1A2A0A4B);
  static const Color shadowLite  = Color(0x14000000);
}

const LinearGradient adminHeaderGradient = LinearGradient(
  colors: [AdminColors.brandPurple, AdminColors.purpleMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Optimized Admin Theme using global factory.
ThemeData buildAdminTheme() {
  return createDepartmentTheme(
    seedColor: AdminColors.brandPurple,
  );
}
