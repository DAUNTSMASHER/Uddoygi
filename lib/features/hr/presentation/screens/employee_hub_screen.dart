import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/widgets/u_ai_assistant.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _primaryGreen = Color(0xFF0A4128);
const _backgroundColor = Color(0xFFF4F7F6);
const _surfaceColor = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
class EmployeeHubScreen extends StatelessWidget {
  const EmployeeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          _buildBody(context),
          _buildFloatingBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        const _SubHeader(),
        Expanded(
          child: Container(
            color: _surfaceColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 32),
                  Text(
                    'Core Actions',
                    style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                  ),
                  const SizedBox(height: 16),
                  const _ActionsGrid(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBottomBar(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomBarIcon(icon: Icons.home_rounded, isActive: false, onTap: () => Navigator.pop(context)),
            _BottomBarIcon(icon: Icons.people_rounded, isActive: true, onTap: () {}),
            _BottomBarIcon(icon: Icons.notifications_none_rounded, isActive: false, onTap: () {}, hasBadge: true),
            _BottomBarIcon(icon: Icons.person_outline_rounded, isActive: false, onTap: () {}),
            _BottomBarIcon(
              icon: Icons.auto_awesome,
              isActive: false,
              onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const UAiAssistant()),
              isSpecial: true,
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827), size: 24), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          Text(
            'Employee Hub',
            style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.1,
              child: const Icon(Icons.hub_rounded, size: 160, color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WORKFORCE MANAGEMENT',
                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.7), letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: Text(
                  'Manage your high-performing team.',
                  style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  'TOTAL: 142 ACTIVE',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}

class _ActionsGrid extends StatelessWidget {
  const _ActionsGrid();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _ActionTile(
          label: 'All Employees',
          subLabel: 'View directory',
          icon: Icons.people_rounded,
          bgColor: const Color(0xFFEAF4EF),
          iconColor: _primaryGreen,
          onTap: () => Navigator.pushNamed(context, '/hr/employee_directory'),
        ),
        _ActionTile(
          label: 'Add New',
          subLabel: 'Onboard talent',
          icon: Icons.person_add_rounded,
          bgColor: const Color(0xFFEAF4EF),
          iconColor: _primaryGreen,
          onTap: () => Navigator.pushNamed(context, '/admin/employees/add'),
        ),
        _ActionTile(
          label: 'Recommend',
          subLabel: 'Promotion/Hike',
          icon: Icons.thumb_up_rounded,
          bgColor: const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFF97316),
          onTap: () => Navigator.pushNamed(context, '/admin/employees/recommendation'),
        ),
        _ActionTile(
          label: 'Transitions',
          subLabel: 'Role changes',
          icon: Icons.swap_horiz_rounded,
          bgColor: const Color(0xFFFAF5FF),
          iconColor: const Color(0xFFA855F7),
          onTap: () => Navigator.pushNamed(context, '/admin/employees/promotions'),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String subLabel;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subLabel,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE5E7EB).withOpacity(0.6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(label, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
            const SizedBox(height: 4),
            Text(subLabel, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF6B7280))),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }
}

class _BottomBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool hasBadge;
  final bool isSpecial;
  const _BottomBarIcon({required this.icon, required this.isActive, required this.onTap, this.hasBadge = false, this.isSpecial = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isSpecial ? _primaryGreen : (isActive ? _primaryGreen : const Color(0xFF9CA3AF)), size: 28),
          if (hasBadge) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
        ],
      ),
    );
  }
}
