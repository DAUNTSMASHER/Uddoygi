import 'package:flutter/material.dart';
import 'app_theme.dart';

class MarketingColors {
  static const Color brandBlue  = Color(0xFF0D47A1);
  static const Color blueMid    = Color(0xFF1D5DF1);
  static const Color surface    = Color(0xFFF6F8FF);
  static const Color cardBorder = Color(0x1A0D47A1);
  static const Color shadowLite = Color(0x14000000);
}

const LinearGradient marketingHeaderGradient = LinearGradient(
  colors: [MarketingColors.brandBlue, MarketingColors.blueMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Optimized Marketing Theme using global factory.
ThemeData buildMarketingTheme() {
  return createDepartmentTheme(
    seedColor: MarketingColors.brandBlue,
  );
}
