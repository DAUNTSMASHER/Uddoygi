/*// lib/features/marketing/presentation/theme/marketing_theme.dart
import 'package:flutter/material.dart';

class MarketingColors {
  static const Color brandBlue  = Color(0xFF0D47A1); // dark
  static const Color blueMid    = Color(0xFF1D5DF1); // accent
  static const Color surface    = Color(0xFFF6F8FF); // near-white
  static const Color cardBorder = Color(0x1A0D47A1); // 10% blue
  static const Color shadowLite = Color(0x14000000); // subtle shadow
}

/// Gradient used by your "Overview" header block
const LinearGradient marketingHeaderGradient = LinearGradient(
  colors: [MarketingColors.brandBlue, MarketingColors.blueMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// A card border + shadow that mirrors your dashboard tiles
final BoxDecoration marketingTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: const BorderSide(color: MarketingColors.cardBorder).toBorder(),
  boxShadow: const [BoxShadow(color: MarketingColors.shadowLite, blurRadius: 8, offset: Offset(0, 3))],
);

/// Helper to create the Search/TextField look used on the dashboard
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: MarketingColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: MarketingColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: MarketingColors.brandBlue, width: 1.4),
    ),
  );
}

/// Build the ThemeData for the Marketing module (blue & white only)
ThemeData buildMarketingTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: MarketingColors.brandBlue).copyWith(
    primary: MarketingColors.brandBlue,
    secondary: MarketingColors.blueMid,
    surface: MarketingColors.surface,
    background: MarketingColors.surface,
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
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: MarketingColors.brandBlue),

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: MarketingColors.shadowLite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MarketingColors.cardBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: MarketingColors.brandBlue),
      prefixIconColor: MarketingColors.brandBlue,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MarketingColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MarketingColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MarketingColors.brandBlue, width: 1.4),
      ),
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
      style: TextButton.styleFrom(
        foregroundColor: MarketingColors.brandBlue,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: MarketingColors.brandBlue.withOpacity(.08),
      disabledColor: const Color(0xFFE9EEF9),
      labelStyle: const TextStyle(color: MarketingColors.brandBlue, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: MarketingColors.brandBlue),
      shape: StadiumBorder(side: BorderSide(color: MarketingColors.cardBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        shadowColor: WidgetStatePropertyAll(MarketingColors.shadowLite),
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
          borderSide: const BorderSide(color: MarketingColors.brandBlue, width: 1.2),
        ),
      ),
    ),

    dropdownButtonTheme: const DropdownButtonThemeData(
      dropdownColor: Colors.white,
      alignment: Alignment.centerLeft,
    ),

    dividerTheme: const DividerThemeData(
      color: MarketingColors.cardBorder,
      thickness: 1,
      space: 0,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MarketingColors.brandBlue,
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

/* -------- small helper to turn BorderSide into a BoxDecoration border -------- */
extension on BorderSide {
  BoxBorder toBorder() => Border.fromBorderSide(this);
}
*/