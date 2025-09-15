/*// lib/features/factory/presentation/theme/factory_theme.dart
import 'package:flutter/material.dart';

class FactoryColors {
  static const Color brandRed  = Color(0xFF7A0613); // deep crimson
  static const Color redMid    = Color(0xFFDC2626); // accent red
  static const Color surface   = Color(0xFFFEF6F6); // soft rose surface
  static const Color cardBorder= Color(0x1A7A0613); // ~10% of brandRed
  static const Color shadowLite= Color(0x14000000);
}

const LinearGradient factoryHeaderGradient = LinearGradient(
  colors: [FactoryColors.brandRed, FactoryColors.redMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final BoxDecoration factoryTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: const BorderSide(color: FactoryColors.cardBorder).toBorder(),
  boxShadow: const [BoxShadow(color: FactoryColors.shadowLite, blurRadius: 8, offset: Offset(0, 3))],
);

InputDecoration factorySearchDecoration({
  String hintText = 'Search…',
  Widget? prefixIcon = const Icon(Icons.search, color: FactoryColors.brandRed),
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    hintStyle: const TextStyle(color: FactoryColors.brandRed),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: FactoryColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: FactoryColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: FactoryColors.brandRed, width: 1.4),
    ),
  );
}

ThemeData buildFactoryTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: FactoryColors.brandRed).copyWith(
    primary: FactoryColors.brandRed,
    secondary: FactoryColors.redMid,
    surface: FactoryColors.surface,
    background: FactoryColors.surface,
    onPrimary: Colors.white,
    onSurface: Colors.black87,
  );

  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: FactoryColors.surface,

    appBarTheme: const AppBarTheme(
      backgroundColor: FactoryColors.brandRed,
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

    iconTheme: const IconThemeData(color: FactoryColors.brandRed),

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: FactoryColors.shadowLite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: FactoryColors.cardBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: FactoryColors.brandRed),
      prefixIconColor: FactoryColors.brandRed,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FactoryColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FactoryColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FactoryColors.brandRed, width: 1.4),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FactoryColors.brandRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        elevation: 0,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FactoryColors.brandRed,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: FactoryColors.brandRed.withOpacity(.08),
      disabledColor: const Color(0xFFFDECEC),
      labelStyle: const TextStyle(color: FactoryColors.brandRed, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: FactoryColors.brandRed),
      shape: StadiumBorder(side: BorderSide(color: FactoryColors.cardBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        shadowColor: WidgetStatePropertyAll(FactoryColors.shadowLite),
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
          borderSide: const BorderSide(color: FactoryColors.brandRed, width: 1.2),
        ),
      ),
    ),

    dropdownButtonTheme: const DropdownButtonThemeData(
      dropdownColor: Colors.white,
      alignment: Alignment.centerLeft,
    ),

    dividerTheme: const DividerThemeData(
      color: FactoryColors.cardBorder,
      thickness: 1,
      space: 0,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: FactoryColors.brandRed,
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

/* helper */
extension on BorderSide {
  BoxBorder toBorder() => Border.fromBorderSide(this);
}
*/