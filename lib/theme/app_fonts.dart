import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/language_service.dart';

/// ── Centralized Typography Service (3 Bangla & 2 English Fonts) ──────────────
/// Provides standardized TextStyles across the application.
///
/// Post-Login Business & ERP Content (Bangla):
///   1. [banglaBody]    - BanglaPrimary (General reading, notices, employee names)
///   2. [banglaHeading] - BanglaHeading (Screen titles, banners, section headers)
///   3. [banglaData]    - BanglaData    - Clean tabular numbers, currency (৳), invoices
///
/// System Controls, Pre-Login & Technical Tags (English):
///   4. [englishSystem] - EnglishSystem (Pre-login, UI navigation, settings, labels)
///   5. [englishTech]   - EnglishTech   - Monospace IDs, work order codes, logs
///
/// Dynamic locale-aware methods:
///   [body]     - picks banglaBody or englishSystem based on current locale
///   [heading]  - picks banglaHeading or englishSystem based on current locale
///   [data]     - picks banglaData or englishSystem based on current locale
class AppFonts {
  AppFonts._();

  static bool _isBangla() => LanguageService.instance.isBangla;

  // ── Dynamic locale-aware methods ────────────────────────────────────────
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return _isBangla()
        ? banglaBody(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing)
        : englishSystem(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing);
  }

  static TextStyle heading({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return _isBangla()
        ? banglaHeading(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing)
        : englishSystem(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing);
  }

  static TextStyle data({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing = 0.5,
  }) {
    return _isBangla()
        ? banglaData(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing)
        : englishSystem(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing);
  }

  /// Digits: Bangla (০-৯) when Bangla locale, English (0-9) when English locale
  static String localizedDigits(String input) {
    return _isBangla() ? toBanglaDigits(input) : input;
  }

  // ── 🇧🇩 Bangla Fonts (Post-Login ERP Content) ──────────────────────────────

  /// Main reading font for post-login ERP content in Bangla.
  /// Falls back to GoogleFonts.hindSiliguri if custom .ttf is not yet loaded.
  static TextStyle banglaBody({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'BanglaPrimary',
      fontFamilyFallback: [GoogleFonts.hindSiliguri().fontFamily ?? 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Prominent heading font for titles and banners in Bangla (using Bold weight).
  /// Falls back to GoogleFonts.hindSiliguri or bold sans-serif.
  static TextStyle banglaHeading({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'BanglaPrimary',
      fontFamilyFallback: [GoogleFonts.hindSiliguri().fontFamily ?? 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Tabular font optimized for financial figures, currency (৳), quantities, and dates.
  static TextStyle banglaData({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    Color? color,
    double? height,
    double? letterSpacing = 0.5,
  }) {
    return TextStyle(
      fontFamily: 'BanglaPrimary',
      fontFamilyFallback: [GoogleFonts.hindSiliguri().fontFamily ?? 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ── 🇬🇧 English Fonts (System UI, Pre-Login, IDs & Controls) ───────────────

  /// Modern sans-serif font for pre-login screens, system controls, settings, and navigation.
  /// Falls back to GoogleFonts.outfit.
  static TextStyle englishSystem({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'EnglishSystem',
      fontFamilyFallback: [GoogleFonts.outfit().fontFamily ?? 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Technical font for Work Order IDs (WO-1029), error codes, database keys, and timestamps.
  static TextStyle englishTech({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing = 1.0,
  }) {
    return TextStyle(
      fontFamily: 'EnglishSystem',
      fontFamilyFallback: [GoogleFonts.outfit().fontFamily ?? 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Converts English digits (0-9) to Bangla digits (০-৯)
  static String toBanglaDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], bangla[i]);
    }
    return result;
  }
}

extension BanglaNumberExtension on String {
  String get toBanglaDigits => AppFonts.toBanglaDigits(this);
}
