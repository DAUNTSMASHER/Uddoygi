import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/design_system.dart';

export 'admin_theme.dart';
export 'hr_theme.dart';
export 'marketing_theme.dart';
export 'factory_theme.dart';
export 'app_fonts.dart';

/// Global app theme — Outfit font applied for a premium feel.
ThemeData buildAppTheme() {
  return createDepartmentTheme(
    seedColor: const Color(0xFF0D47A1),
    brightness: Brightness.light,
  );
}

/// Factory method to build consistent themes for different departments.
ThemeData createDepartmentTheme({
  required Color seedColor,
  Brightness brightness = Brightness.light,
}) {
  final palette = UddoygiDesign.createPalette(seedColor);
  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      primary: palette[700],
      secondary: palette[500],
      surface: brightness == Brightness.light ? const Color(0xFFFAFAFE) : const Color(0xFF0F0F12),
    ),
    fontFamily: 'BanglaPrimary',
    textTheme: GoogleFonts.outfitTextTheme().apply(fontFamily: 'BanglaPrimary'),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    
    // Smooth Transitions
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),

    // Standardized Card Theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: UddoygiDesign.borderM,
        side: BorderSide(color: palette[500]!.withOpacity(0.1)),
      ),
      color: Colors.white,
    ),

    // Standardized Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: UddoygiDesign.borderM),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),

    // Standardized Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(UddoygiDesign.space16),
      border: OutlineInputBorder(
        borderRadius: UddoygiDesign.borderM,
        borderSide: BorderSide(color: palette[500]!.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: UddoygiDesign.borderM,
        borderSide: BorderSide(color: palette[500]!.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: UddoygiDesign.borderM,
        borderSide: BorderSide(color: palette[700]!, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: UddoygiDesign.borderM,
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    ),
  );

  return baseTheme;
}
