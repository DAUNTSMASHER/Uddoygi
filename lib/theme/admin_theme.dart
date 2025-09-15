// lib/features/admin/presentation/theme/admin_theme.dart
/*import 'package:flutter/material.dart';

class AdminColors {
  // Darker purple tones
  static const Color brandPurple = Color(0xFF2A0A4B); // darker primary
  static const Color purpleMid   = Color(0xFF5C2EA0); // deep accent

  // Near-white surface with subtle lavender cast
  static const Color surface     = Color(0xFFF7F4FF);

  // 10% alpha border tint from brandPurple
  static const Color cardBorder  = Color(0x1A2A0A4B);

  // Soft shadow
  static const Color shadowLite  = Color(0x14000000);
}

/// Gradient for the header block (darker purple variant)
const LinearGradient adminHeaderGradient = LinearGradient(
  colors: [AdminColors.brandPurple, AdminColors.purpleMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final BoxDecoration adminTileDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: const BorderSide(color: AdminColors.cardBorder).toBorder(),
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AdminColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AdminColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AdminColors.brandPurple, width: 1.4),
    ),
  );
}

ThemeData buildAdminTheme() {
  final base = ThemeData(useMaterial3: true);
  final cs = ColorScheme.fromSeed(seedColor: AdminColors.brandPurple).copyWith(
    primary: AdminColors.brandPurple,
    secondary: AdminColors.purpleMid,
    surface: AdminColors.surface,
    background: AdminColors.surface,
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
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),

    iconTheme: const IconThemeData(color: AdminColors.brandPurple),

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: AdminColors.shadowLite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminColors.cardBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      hintStyle: const TextStyle(color: AdminColors.brandPurple),
      prefixIconColor: AdminColors.brandPurple,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.brandPurple, width: 1.4),
      ),
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
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.brandPurple,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: AdminColors.brandPurple.withOpacity(.08),
      disabledColor: const Color(0xFFEDE7F6),
      labelStyle: const TextStyle(color: AdminColors.brandPurple, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: AdminColors.brandPurple),
      shape: StadiumBorder(side: BorderSide(color: AdminColors.cardBorder)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),

    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        shadowColor: WidgetStatePropertyAll(AdminColors.shadowLite),
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
          borderSide: const BorderSide(color: AdminColors.brandPurple, width: 1.2),
        ),
      ),
    ),

    dropdownButtonTheme: const DropdownButtonThemeData(
      dropdownColor: Colors.white,
      alignment: Alignment.centerLeft,
    ),

    dividerTheme: const DividerThemeData(
      color: AdminColors.cardBorder,
      thickness: 1,
      space: 0,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AdminColors.brandPurple,
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

extension on BorderSide {
  BoxBorder toBorder() => Border.fromBorderSide(this);
}
*/