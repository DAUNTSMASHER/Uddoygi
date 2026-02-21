import 'package:flutter/material.dart';

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

final BoxDecoration hrTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.fromBorderSide(const BorderSide(color: HRColors.cardBorder)),
  boxShadow: const [BoxShadow(color: HRColors.shadowLite, blurRadius: 8, offset: Offset(0, 3))],
);

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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HRColors.cardBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HRColors.cardBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HRColors.brandGreen, width: 1.4)),
  );
}

ThemeData buildHRTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: HRColors.brandGreen).copyWith(
    primary: HRColors.brandGreen,
    secondary: HRColors.greenMid,
    surface: HRColors.surface,
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
      titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
    ),
    iconTheme: const IconThemeData(color: HRColors.brandGreen),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: HRColors.shadowLite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: HRColors.cardBorder)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: HRColors.brandGreen),
      prefixIconColor: HRColors.brandGreen,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HRColors.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HRColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: HRColors.brandGreen, width: 1.4)),
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
      style: TextButton.styleFrom(foregroundColor: HRColors.brandGreen, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    dividerTheme: const DividerThemeData(color: HRColors.cardBorder, thickness: 1, space: 0),
    snackBarTheme: const SnackBarThemeData(backgroundColor: Colors.white, contentTextStyle: TextStyle(color: Colors.black87), behavior: SnackBarBehavior.floating),
  );
}
