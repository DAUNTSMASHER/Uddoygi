// lib/features/factory/presentation/factory/widgets/factory_bottom_nav.dart

import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';

enum FactoryNavTab { overview, all, pending, running, track }

class FactoryBottomNav extends StatelessWidget {
  final FactoryNavTab currentTab;
  final ValueChanged<FactoryNavTab> onTabSelected;

  const FactoryBottomNav({
    Key? key,
    required this.currentTab,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFf7f9ff),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: const Color(0xFFe2bebc).withOpacity(0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 40,
          child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              context: context,
              tab: FactoryNavTab.overview,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Overview',
            ),
            _buildNavItem(
              context: context,
              tab: FactoryNavTab.all,
              icon: Icons.list_alt_outlined,
              activeIcon: Icons.list_alt,
              label: 'All',
            ),
            _buildNavItem(
              context: context,
              tab: FactoryNavTab.pending,
              icon: Icons.pending_actions_outlined,
              activeIcon: Icons.pending_actions,
              label: 'Pending',
            ),
            _buildNavItem(
              context: context,
              tab: FactoryNavTab.running,
              icon: Icons.play_circle_outline,
              activeIcon: Icons.play_circle,
              label: 'Running',
            ),
            _buildNavItem(
              context: context,
              tab: FactoryNavTab.track,
              icon: Icons.track_changes_outlined,
              activeIcon: Icons.track_changes,
              label: 'Track',
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required FactoryNavTab tab,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = currentTab == tab;

    return GestureDetector(
      onTap: () {
        if (!isActive) onTabSelected(tab);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8B0000) : Colors.transparent,
          borderRadius: BorderRadius.circular(isActive ? 20 : 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : const Color(0xFF5a403f),
              size: 16,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.banglaHeading(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF5a403f),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
