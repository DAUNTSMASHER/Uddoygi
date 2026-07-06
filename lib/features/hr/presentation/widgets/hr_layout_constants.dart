import 'package:flutter/material.dart';

// ── HR color palette (Standardized HR Green) ─────────────────────────────────
const Color kHrHeroGreen    = Color(0xFF052E16);
const Color kHrHeroGreenMid = Color(0xFF065F46);
const Color kHrBrandGreen   = Color(0xFF065F46); // Unified
const Color kHrGreenMid     = Color(0xFF059669);
const Color kHrGreenLight   = Color(0xFFD1FAE5);
const Color kHrGreenSoft    = Color(0xFFECFDF5);
const Color kHrIconBg       = Color(0xFFF0F5F3);
const Color kHrSurface      = Color(0xFFF8FAFC);
const Color kHrCardBg       = Color(0xFFFFFFFF);
const Color kHrCardBorder   = Color(0xFFF1F5F9);
const Color kHrTextPrimary  = Color(0xFF0F172A);
const Color kHrTextSecondary = Color(0xFF475569);
const Color kHrTextMuted    = Color(0xFF94A3B8);
const Color kHrTextOnGreen  = Color(0xFFFFFFFF);
const Color kHrSuccessDot   = Color(0xFF10B981);
const Color kHrShadowCard   = Color(0x0A0F172A);
const Color kHrDivider      = Color(0xFFF1F5F9);

// Gradient for top bar / drawer header
const LinearGradient kHrHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kHrHeroGreen, kHrHeroGreenMid],
);
