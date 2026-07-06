// lib/widgets/global_department_switcher.dart
import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/features/hr/presentation/screens/hr_dashboard.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/marketing_dashboard.dart';

class GlobalDepartmentSwitcher extends StatelessWidget {
  final String current;
  const GlobalDepartmentSwitcher({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _buildBtn(context, 'HR', current == 'HR', const Color(0xFF0A4128), () => _nav(context, const HRDashboard())),
          const SizedBox(width: 4),
          _buildBtn(context, 'Admin', current == 'Admin', const Color(0xFF311042), () => _nav(context, const AdminDashboard())),
          const SizedBox(width: 4),
          _buildBtn(context, 'Factory', current == 'Factory', const Color(0xFF8B0000), () => _nav(context, const FactoryDashboard())),
          const SizedBox(width: 4),
          _buildBtn(context, 'Marketing', current == 'Marketing', const Color(0xFF0D47A1), () => _nav(context, const MarketingDashboard())),
        ],
      ),
    );
  }

  void _nav(BuildContext context, Widget screen) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildBtn(BuildContext context, String label, bool isActive, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isActive
                ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppFonts.banglaBody(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}
