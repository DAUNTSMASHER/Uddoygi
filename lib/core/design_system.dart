import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Central Design System for Uddoygi.
/// Follows the 8px grid system and premium aesthetics.
class UddoygiDesign {
  // ── Spacing (8px Grid) ──────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space18 = 18.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  static const Color surface = Color(0xFFF8FAFC);
  static final NumberFormat moneyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '৳', decimalDigits: 0);

  // ── Corners (Border Radii) ──────────────────────────────────────
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 99.0;

  static BorderRadius get borderS => BorderRadius.circular(radiusS);
  static BorderRadius get borderM => BorderRadius.circular(radiusM);
  static BorderRadius get borderL => BorderRadius.circular(radiusL);
  static BorderRadius get borderXL => BorderRadius.circular(radiusXL);
  static BorderRadius get borderFull => BorderRadius.circular(radiusFull);

  // ── Shadows (Premium Multi-layered) ─────────────────────────────
  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowFloating => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  // ── Glassmorphism Helper ────────────────────────────────────────
  static BoxDecoration glass({
    required Color color,
    double opacity = 0.1,
    double blur = 10.0,
    BorderRadius? radius,
    Border? border,
  }) {
    return BoxDecoration(
      color: color.withOpacity(opacity),
      borderRadius: radius ?? borderM,
      border: border ?? Border.all(color: Colors.white.withOpacity(0.2)),
    );
  }

  // ── Color Utilities ─────────────────────────────────────────────
  /// Creates a harmonious HSL-based palette from a seed color.
  static MaterialColor createPalette(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).toInt()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).toInt(),
        g + ((ds < 0 ? g : (255 - g)) * ds).toInt(),
        b + ((ds < 0 ? b : (255 - b)) * ds).toInt(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}
