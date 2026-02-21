import 'package:flutter/material.dart';

/// Central color palette for the entire app.
/// All feature files should import from here instead of defining local consts.
class AppColors {
  AppColors._();

  // ── Brand / Primary ──────────────────────────────────────────────────────
  static const Color brand = Color(0xFF6F3DFF);
  static const Color brandDark = Color(0xFF4A1FA8);
  static const Color brandMid = Color(0xFF8B5CF6);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color pending = Color(0xFFF59E0B);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF8F7FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2D9F3);
  static const Color muted = Color(0xFF9CA3AF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  // ── Department Accents ────────────────────────────────────────────────────
  static const Color adminPrimary    = Color(0xFF2A0A4B); // deep purple
  static const Color hrPrimary       = Color(0xFF065F46); // deep green
  static const Color marketingPrimary= Color(0xFF0D47A1); // deep blue
  static const Color factoryPrimary  = Color(0xFF40062D); // deep red

  // ── R&D (Royal Purple + Electric Blue) ───────────────────────────────────
  static const Color rndBrand = Color(0xFF6C3FC5);
  static const Color rndBrandDark = Color(0xFF4A1FA8);
  static const Color rndMid = Color(0xFF8B5CF6);
  static const Color rndSurface = Color(0xFFF5F3FF);
  static const Color rndCardTint = Color(0xFFEDE9FE);
  static const Color rndAccent = Color(0xFF3B82F6);
  static const Color rndMagenta = Color(0xFFD946EF);

  // ── Welfare palette ───────────────────────────────────────────────────────
  static const Color welfareP1 = Color(0xFF6C3FC5);
  static const Color welfareP2 = Color(0xFF8B5CF6);
  static const Color welfareP3 = Color(0xFFEDE9FE);
  static const Color welfareBg = Color(0xFFF5F3FF);
  static const Color welfareCard = Color(0xFFFFFFFF);
  static const Color welfareText = Color(0xFF1E1B4B);
  static const Color welfareText2 = Color(0xFF6B7280);
  static const Color welfareBorder = Color(0xFFDDD6FE);
  static const Color welfareGreen = Color(0xFF16A34A);
  static const Color welfareAmber = Color(0xFFD97706);
  static const Color welfareRed = Color(0xFFDC2626);
  static const Color welfareCyan = Color(0xFF0891B2);
}
