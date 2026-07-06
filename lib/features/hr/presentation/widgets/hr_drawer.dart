import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hr_layout_constants.dart';

class HRDrawer extends StatefulWidget {
  const HRDrawer({super.key});
  @override
  State<HRDrawer> createState() => _HRDrawerState();
}

class _HRDrawerState extends State<HRDrawer> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  void _go(String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(uid: uid, email: email, cid: _cid),
          const SizedBox(height: 12),
          _Section('প্রধান (Main)'),
          _Tile(icon: Icons.dashboard_rounded, label: 'ড্যাশবোর্ড (Dashboard)', onTap: () => _go('/hr/dashboard')),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _Section('কর্মী ব্যবস্থাপনা (People)'),
          _Tile(icon: Icons.people_rounded, label: 'কর্মী তালিকা (Employees)', onTap: () => _go('/hr/employee_directory')),
          _Tile(icon: Icons.how_to_reg_rounded, label: 'নিয়োগ (Recruitment)', onTap: () => _go('/hr/recruitment')),
          _Tile(icon: Icons.schedule_rounded, label: 'শিফট ট্র্যাকার (Shifts)', onTap: () => _go('/hr/shift_tracker')),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _Section('বেতন ও পে-রোল (Payroll)'),
          _Tile(icon: Icons.attach_money_rounded, label: 'বেতন প্রসেসিং (Processing)', onTap: () => _go('/hr/payroll_processing')),
          _Tile(icon: Icons.receipt_long_rounded, label: 'পে-স্লিপ (Payslips)', onTap: () => _go('/hr/payslip')),
          _Tile(icon: Icons.verified_user_rounded, label: 'অনুমোদন (Authorization)', onTap: () => _go('/hr/authorization')),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          _Section('অর্থ ও হিসাব (Finance)'),
          _Tile(icon: Icons.account_balance_rounded, label: 'ঋণ অনুমোদন (Loans)', onTap: () => _go('/hr/loan_approval')),
          _Tile(icon: Icons.pie_chart_rounded, label: 'বাজেট (Budget)', onTap: () => _go('/hr/budget')),
          _Tile(icon: Icons.calculate_rounded, label: 'ট্যাক্স ও কর (Tax)', onTap: () => _go('/hr/tax')),
          _Tile(icon: Icons.trending_up_rounded, label: 'আর ও আই (ROI)', onTap: () => _go('/hr/roi')),
          const SizedBox(height: 40),
          _LogoutTile(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String uid, email, cid;
  const _Header({required this.uid, required this.email, required this.cid});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
    decoration: const BoxDecoration(gradient: kHrHeaderGradient),
    child: Row(
      children: [
        CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Text(email.isNotEmpty ? email[0].toUpperCase() : 'H', style: AppFonts.englishSystem(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('এইচআর অ্যাডমিন (HR)', style: AppFonts.banglaHeading(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(email, style: AppFonts.englishTech(color: Colors.white60, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)])),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 8), child: Text(label, style: AppFonts.banglaHeading(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400])));
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: const Color(0xFF0F172A), size: 20),
    title: Text(label, style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
    dense: true,
    visualDensity: VisualDensity.compact,
    horizontalTitleGap: 12,
  );
}

class _LogoutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => LocalStorageService.performLogout().then((_) => Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false)),
    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
    title: Text('লগআউট (Logout)', style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.redAccent)),
    dense: true,
  );
}
