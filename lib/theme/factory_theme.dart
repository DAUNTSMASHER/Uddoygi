import 'package:flutter/material.dart';
import 'app_theme.dart';

class FactoryColors {
  static const Color brandRed  = Color(0xFF7A0613);
  static const Color redMid    = Color(0xFFDC2626);
  static const Color surface   = Color(0xFFFEF6F6);
  static const Color cardBorder= Color(0x1A7A0613);
  static const Color shadowLite= Color(0x14000000);
}

const LinearGradient factoryHeaderGradient = LinearGradient(
  colors: [FactoryColors.brandRed, FactoryColors.redMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Optimized Factory Theme using global factory.
ThemeData buildFactoryTheme() {
  return createDepartmentTheme(
    seedColor: FactoryColors.brandRed,
  );
}
