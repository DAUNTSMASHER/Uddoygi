/*// lib/features/hr/presentation/theme/hr_theme.dart
import 'package:flutter/material.dart';

class HRColors {
  // Primary & accent (green family)
  static const Color brandGreen = Color(0xFF065F46); // deep green
  static const Color greenMid   = Color(0xFF10B981); // emerald accent
  // Near-white surface with a soft green cast
  static const Color surface    = Color(0xFFF1F8F4);
  // ~10% alpha border tint of brandGreen (0x1A = 10% opacity)
  static const Color cardBorder = Color(0x1A065F46);
  // Subtle shadow
  static const Color shadowLite = Color(0x14000000);
}

/// Gradient for HR “Overview” headers (green version)
const LinearGradient hrHeaderGradient = LinearGradient(
  colors: [HRColors.brandGreen, HRColors.greenMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Card/tile decoration identical to other modules (green border/shadow)
final BoxDecoration hrTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: const BorderSide(color: HRColors.cardBorder).toBorder(),
  boxShadow: const [BoxShadow(color: HRColors.shadowLite, blurRadius: 8, offset: Offset(0, 3))],
);

/// Search/Input decoration (green)
InputDecoration hrSearchDecoration({
  String hintText = 'Search…',
  Widget? prefixIcon = const Icon(Icons.search, color: HRColors.brandGreen),
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    hintStyle: const TextStyle(color: HRColors.brandGreen),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HRColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HRColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HRColors.brandGreen, width: 1.4),
    ),
  );
}

/// Full ThemeData for the HR module (green/greenish)
ThemeData buildHRTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: HRColors.brandGreen).copyWith(
    primary: HRColors.brandGreen,
    secondary: HRColors.greenMid,
    surface: HRColors.surface,
    background: HRColors.surface,
    onPrimary: Colors.white,
    onSurface: Colors.black87,
  );

  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: HRColors.surface,

    appBarTheme: const AppBarTheme(
      backgroundColor: HRColors.brandGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: HRColors.brandGreen),

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: HRColors.shadowLite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HRColors.cardBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: HRColors.brandGreen),
      prefixIconColor: HRColors.brandGreen,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HRColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HRColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: HRColors.brandGreen, width: 1.4),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HRColors.brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        elevation: 0,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HRColors.brandGreen,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: HRColors.brandGreen.withOpacity(.08),
      disabledColor: const Color(0xFFE8F5E9), // light green disabled
      labelStyle: const TextStyle(color: HRColors.brandGreen, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: HRColors.brandGreen),
      shape: StadiumBorder(side: BorderSide(color: HRColors.cardBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        shadowColor: WidgetStatePropertyAll(HRColors.shadowLite),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.white70),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Colors.white70),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: HRColors.brandGreen, width: 1.2),
        ),
      ),
    ),

    dropdownButtonTheme: const DropdownButtonThemeData(
      dropdownColor: Colors.white,
      alignment: Alignment.centerLeft,
    ),

    dividerTheme: const DividerThemeData(
      color: HRColors.cardBorder,
      thickness: 1,
      space: 0,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: HRColors.brandGreen,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Colors.white,
      contentTextStyle: TextStyle(color: Colors.black87),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/* tiny helper to turn BorderSide into a BoxDecoration border */
extension on BorderSide {
  BoxBorder toBorder() => Border.fromBorderSide(this);
}
*/