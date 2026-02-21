import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'admin_theme.dart';
export 'hr_theme.dart';
export 'marketing_theme.dart';
export 'factory_theme.dart';

/// Global app theme — Ubuntu font applied once here.
/// All department screens inherit this base; each module can override
/// specific colors via their own ThemeData (buildAdminTheme, etc.).
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.ubuntuTextTheme(),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6F3DFF),
      brightness: Brightness.light,
    ),
  );
}
