import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_web_shell.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/widgets/u_ai_assistant.dart';
import 'budget.dart' show BudgetPage;
import 'hr_category_screen.dart';

// ── Models ───────────────────────────────────────────────────────────────────
class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}

class _Section {
  final String label;
  final List<int> indices;
  const _Section(this.label, this.indices);
}

// ── Constants ─────────────────────────────────────────────────────────────
const _heroGreen = Color(0xFF052E16);
const _brandGreen = Color(0xFF047857);

// ─────────────────────────────────────────────────────────────────────────────
class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});
  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  String _cid = '';
  String? name;
  String? photoUrl;

  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Employees', Icons.people_rounded, '/hr/employee_directory'),
    _DashboardItem('Recruitment', Icons.how_to_reg_rounded, '/hr/recruitment'),
    _DashboardItem('Shifts', Icons.schedule_rounded, '/hr/shift_tracker'),
    _DashboardItem('Attendance', Icons.event_available_rounded, '/hr/attendance'),
    _DashboardItem('Leave', Icons.beach_access_rounded, '/hr/leave_management'),
    _DashboardItem('Payroll', Icons.attach_money_rounded, '/hr/payroll_processing'),
    _DashboardItem('Payslips', Icons.receipt_long_rounded, '/hr/payslip'),
    _DashboardItem('Salary', Icons.money_rounded, '/hr/salary_management'),
    _DashboardItem('Slip Approvals', Icons.receipt_long_rounded, '/hr/payment_slip_approvals'),
    _DashboardItem('Authorization', Icons.verified_user_rounded, '/hr/authorization'),
    _DashboardItem('Loans', Icons.account_balance_rounded, '/hr/loan_approval'),
    _DashboardItem('Credits', Icons.trending_up_rounded, '/hr/credits'),
    _DashboardItem('Expenses', Icons.payments_rounded, '/hr/expenses'),
    _DashboardItem('Balance', Icons.account_balance_wallet_rounded, '/hr/balance_update'),
    _DashboardItem('Budget', Icons.pie_chart_rounded, '/hr/budget'),
    _DashboardItem('Accounts', Icons.account_balance_wallet_outlined, '/payments/bank-accounts'),
    _DashboardItem('Tax', Icons.calculate_rounded, '/hr/tax'),
    _DashboardItem('ROI', Icons.trending_up_rounded, '/hr/roi'),
    _DashboardItem('Incentives', Icons.percent_rounded, '/hr/incentives'),
    _DashboardItem('Benefits', Icons.card_giftcard_rounded, '/hr/benefits_compensation'),
    _DashboardItem('Budget Forecast', Icons.bar_chart_rounded, '/hr/budget_forecast'),
    _DashboardItem('Procurement', Icons.shopping_cart_rounded, '/hr/procurement'),
    _DashboardItem('Suppliers', Icons.local_shipping_rounded, '/common/suppliers'),
    _DashboardItem('Welfare', Icons.favorite_rounded, '/hr/welfare'),
    _DashboardItem('Notices', Icons.notifications_rounded, '/marketing/notices'),
    _DashboardItem('Messages', Icons.message_rounded, '/common/messages'),
    _DashboardItem('Complaints', Icons.support_agent_rounded, '/common/complaints'),
  ];

  static const _sections = [
    _Section('People', [0, 1, 2]),
    _Section('Time', [3, 4]),
    _Section('Payroll', [5, 6, 7, 8, 9]),
    _Section('Finance', [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]),
    _Section('HR Ops', [22]),
    _Section('Comms', [23, 24, 25]),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
    final session = await LocalStorageService.getSession();
    if (mounted) {
      setState(() {
        name = session?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'HR Admin';
        photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
      });
    }
  }

  void _openCategory(String label, List<int> indices) {
    final categoryItems = indices.map((i) => HrCategoryItem(_allItems[i].title, _allItems[i].icon, _allItems[i].route)).toList();
    HrCategoryScreen.navigate(context, label, categoryItems);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (isDesktop) {
      return HrWebShell(
        title: 'Dashboard',
        child: _buildScrollBody(),
      );
    }

    return Scaffold(
      backgroundColor: _heroGreen,
      drawer: const HRDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _HeroHeader(name: name ?? 'HR Admin', photoUrl: photoUrl),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: UddoygiDesign.surface,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                ),
                child: _buildScrollBody(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const UAiAssistant()),
        backgroundColor: _brandGreen,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }

  Widget _buildScrollBody() {
    return ListView(
      padding: const EdgeInsets.all(UddoygiDesign.space20),
      children: [
        _OverviewCard(cid: _cid).animate().fadeIn().slideY(begin: 0.1, end: 0),
        const SizedBox(height: UddoygiDesign.space24),
        Text('Management Modules', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
        const SizedBox(height: 16),
        _CategoryGrid(sections: _sections, onCategoryTap: _openCategory),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _HeroHeader({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => Scaffold.of(ctx).openDrawer())),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null ? Text(name[0], style: const TextStyle(color: Colors.white)) : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String cid;
  const _OverviewCard({required this.cid});

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPANY OVERVIEW', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.2)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _StatItem(label: 'Employees', stream: DB.colSync(cid, C.users).snapshots().map((s) => '${s.docs.length}'), icon: Icons.people_rounded),
              _StatItem(label: 'Pending Leave', stream: DB.colSync(cid, C.leaveRequests).where('status', isEqualTo: 'pending').snapshots().map((s) => '${s.docs.length}'), icon: Icons.event_note_rounded),
              _StatItem(label: 'Complaints', stream: DB.colSync(cid, C.complaints).where('status', isEqualTo: 'pending').snapshots().map((s) => '${s.docs.length}'), icon: Icons.report_problem_rounded),
              _StatItem(label: 'Net Payroll', stream: Stream.value('৳ 4.2L'), icon: Icons.payments_rounded), // Mock for now
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final Stream<String> stream;
  final IconData icon;
  const _StatItem({required this.label, required this.stream, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder<String>(stream: stream, builder: (_, snap) => Text(snap.data ?? '—', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)))),
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_Section> sections;
  final void Function(String, List<int>) onCategoryTap;
  const _CategoryGrid({required this.sections, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: sections.map((sec) => _CategoryTile(label: sec.label, icon: _getIcon(sec.label), onTap: () => onCategoryTap(sec.label, sec.indices))).toList(),
    );
  }

  IconData _getIcon(String label) {
    switch (label) {
      case 'People': return Icons.people_outline_rounded;
      case 'Time': return Icons.schedule_rounded;
      case 'Payroll': return Icons.payments_outlined;
      case 'Finance': return Icons.account_balance_wallet_outlined;
      case 'HR Ops': return Icons.favorite_border_rounded;
      case 'Comms': return Icons.message_outlined;
      default: return Icons.folder_outlined;
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: _brandGreen, size: 22)),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }
}
