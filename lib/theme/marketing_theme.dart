import 'package:flutter/material.dart';

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

final BoxDecoration marketingTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.fromBorderSide(const BorderSide(color: MarketingColors.cardBorder)),
  boxShadow: const [BoxShadow(color: MarketingColors.shadowLite, blurRadius: 8, offset: Offset(0, 3))],
);

InputDecoration marketingSearchDecoration({
  String hintText = 'Search…',
  Widget? prefixIcon = const Icon(Icons.search, color: MarketingColors.brandBlue),
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    hintStyle: const TextStyle(color: MarketingColors.brandBlue),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MarketingColors.cardBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MarketingColors.cardBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MarketingColors.brandBlue, width: 1.4)),
  );
}

ThemeData buildMarketingTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: MarketingColors.brandBlue).copyWith(
    primary: MarketingColors.brandBlue,
    secondary: MarketingColors.blueMid,
    surface: MarketingColors.surface,
    onPrimary: Colors.white,
    onSurface: Colors.black87,
  );
  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: MarketingColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: MarketingColors.brandBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
    ),
    iconTheme: const IconThemeData(color: MarketingColors.brandBlue),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: MarketingColors.shadowLite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: MarketingColors.cardBorder)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: MarketingColors.brandBlue),
      prefixIconColor: MarketingColors.brandBlue,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MarketingColors.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MarketingColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: MarketingColors.brandBlue, width: 1.4)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MarketingColors.brandBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: MarketingColors.brandBlue, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    dividerTheme: const DividerThemeData(color: MarketingColors.cardBorder, thickness: 1, space: 0),
    snackBarTheme: const SnackBarThemeData(backgroundColor: Colors.white, contentTextStyle: TextStyle(color: Colors.black87), behavior: SnackBarBehavior.floating),
  );
}
