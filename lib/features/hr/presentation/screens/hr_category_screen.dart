// lib/features/hr/presentation/screens/hr_category_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);

// ── Models ────────────────────────────────────────────────────────────────
class HrCategoryItem {
  final String title;
  final IconData icon;
  final dynamic route; // String named route or Widget screen
  const HrCategoryItem(this.title, this.icon, this.route);
}

// ─────────────────────────────────────────────────────────────────────────────
class HrCategoryScreen extends StatelessWidget {
  final String categoryLabel;
  final List<HrCategoryItem> items;
  final Color themeColor;

  const HrCategoryScreen({
    super.key,
    required this.categoryLabel,
    required this.items,
    this.themeColor = _brandGreen,
  });

  static void navigate(BuildContext context, String label, List<HrCategoryItem> items, {Color themeColor = _brandGreen}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HrCategoryScreen(categoryLabel: label, items: items, themeColor: themeColor)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(categoryLabel, style: AppFonts.banglaHeading(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('মডিউল সমূহ (AVAILABLE MODULES)', style: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600])),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.1),
                itemCount: items.length,
                itemBuilder: (_, i) => _ModuleTile(item: items[i], themeColor: themeColor).animate().fadeIn(delay: (i * 50).ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
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
  final Color themeColor;
  const _ModuleTile({required this.item, required this.themeColor});

  @override
  Widget build(BuildContext context) => UCard(
    onTap: () {
      if (item.route is String && (item.route as String).isNotEmpty) {
        Navigator.pushNamed(context, item.route as String);
      } else if (item.route is Widget) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => item.route as Widget));
      } else if (item.route is Function) {
        (item.route as Function)();
      }
    },
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(item.icon, color: themeColor),
        ),
        const SizedBox(height: 12),
        Text(item.title, textAlign: TextAlign.center, style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    ),
  );
}
