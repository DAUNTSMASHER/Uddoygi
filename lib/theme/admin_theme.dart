import 'package:flutter/material.dart';

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

final BoxDecoration adminTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.fromBorderSide(const BorderSide(color: AdminColors.cardBorder)),
  boxShadow: const [BoxShadow(color: AdminColors.shadowLite, blurRadius: 8, offset: Offset(0, 3))],
);

InputDecoration adminSearchDecoration({
  String hintText = 'Search…',
  Widget? prefixIcon = const Icon(Icons.search, color: AdminColors.brandPurple),
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    hintStyle: const TextStyle(color: AdminColors.brandPurple),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.cardBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.cardBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.brandPurple, width: 1.4)),
  );
}

ThemeData buildAdminTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: AdminColors.brandPurple).copyWith(
    primary: AdminColors.brandPurple,
    secondary: AdminColors.purpleMid,
    surface: AdminColors.surface,
    onPrimary: Colors.white,
    onSurface: Colors.black87,
  );
  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: AdminColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.brandPurple,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
    ),
    iconTheme: const IconThemeData(color: AdminColors.brandPurple),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: AdminColors.shadowLite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AdminColors.cardBorder)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: AdminColors.brandPurple),
      prefixIconColor: AdminColors.brandPurple,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminColors.brandPurple, width: 1.4)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.brandPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AdminColors.brandPurple, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    dividerTheme: const DividerThemeData(color: AdminColors.cardBorder, thickness: 1, space: 0),
    snackBarTheme: const SnackBarThemeData(backgroundColor: Colors.white, contentTextStyle: TextStyle(color: Colors.black87), behavior: SnackBarBehavior.floating),
  );
}
