// lib/features/rnd/rnd_theme.dart
// Shared colour tokens for the R&D department module
import 'package:flutter/material.dart';

/// Primary: Deep Violet — visionary, wisdom
const Color rndBrand    = Color(0xFF5B21B6);
/// Royal Purple — gradient dark end
const Color rndBrandDk  = Color(0xFF3B0764);
/// Violet mid — gradient light end
const Color rndMid      = Color(0xFF7C3AED);
/// Light lavender-white — page background
const Color rndSurface  = Color(0xFFF8F7FF);
/// Soft purple tint — card/chip backgrounds
const Color rndCardTint = Color(0xFFEDE9FE);
/// Electric Blue — CTAs, progress bars, highlights
const Color rndAccent   = Color(0xFF2563EB);
/// Vivid Magenta — badges, urgent, overdue
const Color rndMagenta  = Color(0xFFC026D3);

/// AppBar gradient decoration
const BoxDecoration rndAppBarGradient = BoxDecoration(
  gradient: LinearGradient(
    colors: [rndBrandDk, rndMid],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
);

/// Standard card decoration
BoxDecoration rndCard({bool highlight = false}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
      color: highlight ? rndBrand.withOpacity(0.3) : rndCardTint),
  boxShadow: const [
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))
  ],
);

/// Priority colour helper
Color rndPriorityColor(String priority) {
  switch (priority) {
    case 'Urgent': return rndMagenta;
    case 'High':   return const Color(0xFFEA580C);
    case 'Low':    return Colors.grey;
    default:       return rndAccent;
  }
}

/// Status colour helper
Color rndStatusColor(String status) {
  switch (status) {
    case 'Approved':
    case 'Completed':         return const Color(0xFF16A34A);
    case 'Rejected':
    case 'Cancelled':         return const Color(0xFFDC2626);
    case 'Submitted':
    case 'In Progress':       return rndAccent;
    case 'Testing':           return rndBrand;
    case 'On Hold':
    case 'Revision Required': return const Color(0xFFEA580C);
    case 'Draft':             return Colors.grey;
    default:                  return Colors.grey;
  }
}
