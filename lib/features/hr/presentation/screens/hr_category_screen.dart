import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ── Models ────────────────────────────────────────────────────────────────
class HrCategoryItem {
  final String title;
  final IconData icon;
  final String route;
  const HrCategoryItem(this.title, this.icon, this.route);
}

// ─────────────────────────────────────────────────────────────────────────────
class HrCategoryScreen extends StatelessWidget {
  final String categoryLabel;
  final List<HrCategoryItem> items;

  const HrCategoryScreen({super.key, required this.categoryLabel, required this.items});

  static void navigate(BuildContext context, String label, List<HrCategoryItem> items) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HrCategoryScreen(categoryLabel: label, items: items)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(categoryLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('AVAILABLE MODULES', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1.5)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.1),
                itemCount: items.length,
                itemBuilder: (_, i) => _ModuleTile(item: items[i]).animate().fadeIn(delay: (i * 50).ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final HrCategoryItem item;
  const _ModuleTile({required this.item});

  @override
  Widget build(BuildContext context) => UCard(
    onTap: () => Navigator.pushNamed(context, item.route),
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(item.icon, color: _brandGreen)),
        const SizedBox(height: 12),
        Text(item.title, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
      ],
    ),
  );
}
