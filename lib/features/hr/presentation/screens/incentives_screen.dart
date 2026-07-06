import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/features/incentive_calculation/hr_incentive_calculator_screen.dart';
import 'package:uddoygi/features/incentive_calculation/incentive_history_screen.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class IncentivehrScreen extends StatelessWidget {
  const IncentivehrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Incentive Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _IncentiveTile(
            label: 'Calculator',
            subtitle: 'Estimate rewards',
            icon: Icons.calculate_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRIncentiveCalculatorScreen())),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          _IncentiveTile(
            label: 'History',
            subtitle: 'Past payouts',
            icon: Icons.history_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncentiveHistoryScreen())),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

class _IncentiveTile extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _IncentiveTile({required this.label, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => UCard(
    onTap: onTap,
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: _brandGreen)),
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
        Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w700)),
      ],
    ),
  );
}