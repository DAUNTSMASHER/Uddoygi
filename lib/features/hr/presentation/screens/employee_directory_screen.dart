import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/features/employee_management/add_employee_page.dart';
import 'package:uddoygi/features/employee_management/all_employees_page.dart';
import 'package:uddoygi/features/employee_management/submit_recommendation_page.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ─────────────────────────────────────────────────────────────────────────────
class EmployeeDirectoryScreen extends StatelessWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Employee Hub', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UddoygiDesign.space20),
        children: [
          _HeroCard().animate().fadeIn().slideX(begin: -0.1, end: 0),
          const SizedBox(height: 24),
          Text('Core Actions', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _DirectoryTile(title: 'All Employees', subtitle: 'View directory', icon: Icons.group_rounded, color: _brandGreen, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllEmployeesPage()))),
              _DirectoryTile(title: 'Add New', subtitle: 'Onboard talent', icon: Icons.person_add_rounded, color: const Color(0xFF16A34A), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEmployeePage()))),
              _DirectoryTile(title: 'Recommend', subtitle: 'Promotion/Hike', icon: Icons.thumb_up_alt_rounded, color: const Color(0xFFF59E0B), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmitRecommendationPage()))),
              _DirectoryTile(title: 'Transitions', subtitle: 'Role changes', icon: Icons.swap_horiz_rounded, color: const Color(0xFF6366F1), onTap: () {}),
            ],
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brandGreen, Color(0xFF052E16)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _brandGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WORKFORCE MANAGEMENT', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text('Manage your high-performing team.', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('TOTAL: 142 ACTIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          const Icon(Icons.hub_rounded, color: Colors.white24, size: 80),
        ],
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DirectoryTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}
