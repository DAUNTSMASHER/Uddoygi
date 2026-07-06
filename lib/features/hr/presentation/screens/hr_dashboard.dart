import 'dart:async';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_web_shell.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'hr_category_screen.dart';
import 'employee_hub_screen.dart';
import 'package:uddoygi/widgets/global_department_switcher.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _primaryGreen = Color(0xFF0A4128);
const _accentGreen = Color(0xFF0F643F);
const _backgroundColor = Color(0xFFF4F7F6);
const _secondaryColor = Color(0xFFEAF1ED);
const _surfaceColor = Color(0xFFFFFFFF);

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
  int _currentIndex = 0;

  final List<_DashboardItem> _allItems = const [
    _DashboardItem('কর্মী তালিকা (Employees)', Icons.person_outline_rounded, '/hr/employee_directory'),
    _DashboardItem('নিয়োগ (Recruitment)', Icons.how_to_reg_rounded, '/hr/recruitment'),
    _DashboardItem('শিফট ব্যবস্থাপনা (Shifts)', Icons.schedule_rounded, '/hr/shift_tracker'),
    _DashboardItem('উপস্থিতি (Attendance)', Icons.event_available_rounded, '/hr/attendance'),
    _DashboardItem('ছুটি ব্যবস্থাপনা (Leave)', Icons.beach_access_rounded, '/hr/leave_management'),
    _DashboardItem('বেতন তৈরি (Payroll)', Icons.attach_money_rounded, '/hr/payroll_processing'),
    _DashboardItem('পে-স্লিপ (Payslips)', Icons.receipt_long_rounded, '/hr/payslip'),
    _DashboardItem('বেতন ব্যবস্থাপনা (Salary)', Icons.money_rounded, '/hr/salary_management'),
    _DashboardItem('স্লিপ অনুমোদন (Approvals)', Icons.receipt_long_rounded, '/hr/payment_slip_approvals'),
    _DashboardItem('অনুমোদন (Authorization)', Icons.verified_user_rounded, '/hr/authorization'),
    _DashboardItem('ঋণ অনুমোদন (Loans)', Icons.account_balance_rounded, '/hr/loan_approval'),
    _DashboardItem('ক্রেডিট (Credits)', Icons.trending_up_rounded, '/hr/credits'),
    _DashboardItem('খরচ (Expenses)', Icons.payments_rounded, '/hr/expenses'),
    _DashboardItem('ব্যালেন্স আপডেট (Balance)', Icons.account_balance_wallet_rounded, '/hr/balance_update'),
    _DashboardItem('বাজেট (Budget)', Icons.pie_chart_rounded, '/hr/budget'),
    _DashboardItem('ব্যাংক হিসাব (Accounts)', Icons.account_balance_wallet_outlined, '/payments/bank-accounts'),
    _DashboardItem('কর ও ট্যাক্স (Tax)', Icons.calculate_rounded, '/hr/tax'),
    _DashboardItem('মুনাফা (ROI)', Icons.trending_up_rounded, '/hr/roi'),
    _DashboardItem('ইনসেনটিভ (Incentives)', Icons.percent_rounded, '/hr/incentives'),
    _DashboardItem('সুবিধা ও ক্ষতিপূরণ (Benefits)', Icons.card_giftcard_rounded, '/hr/benefits_compensation'),
    _DashboardItem('বাজেট পূর্বাভাস (Forecast)', Icons.bar_chart_rounded, '/hr/budget_forecast'),
    _DashboardItem('ক্রয় ব্যবস্থাপনা (Procurement)', Icons.shopping_cart_rounded, '/hr/procurement'),
    _DashboardItem('ইউটিলিটি (Utilities)', Icons.bolt_rounded, '/admin/factory/utilities'),
    _DashboardItem('সরবরাহকারী (Suppliers)', Icons.local_shipping_rounded, '/common/suppliers'),
    _DashboardItem('কল্যাণ তহবিল (Welfare)', Icons.favorite_rounded, '/hr/welfare'),
    _DashboardItem('নোটিশ বোর্ড (Notices)', Icons.notifications_rounded, '/marketing/notices'),
    _DashboardItem('মেসেজ (Messages)', Icons.message_rounded, '/common/messages'),
    _DashboardItem('অভিযোগ (Complaints)', Icons.support_agent_rounded, '/common/complaints'),
  ];

  static const _sections = [
    _Section('জনবল (People)', [0, 1, 2]),
    _Section('সময় ও উপস্থিতি (Time)', [3, 4]),
    _Section('বেতন ও পে-স্লিপ (Payroll)', [5, 6, 7, 8, 9]),
    _Section('অর্থ ও হিসাব (Finance)', [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]),
    _Section('এইচআর অপস (HR Ops)', [23]),
    _Section('যোগাযোগ (Comms)', [24, 25, 26]),
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
    if (label.contains('People') || label.contains('জনবল')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeHubScreen()));
      return;
    }
    final categoryItems = indices.map((i) => HrCategoryItem(_allItems[i].title, _allItems[i].icon, _allItems[i].route)).toList();
    HrCategoryScreen.navigate(context, label, categoryItems);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (isDesktop) {
      return HrWebShell(title: 'এইচআর ড্যাশবোর্ড (HR Dashboard)', child: _buildScrollBody());
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      drawer: const HRDrawer(),
      body: Stack(
        children: [
          _buildMobileBody(),
          _buildFloatingBottomBar(),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        _Header(name: name ?? 'HR Admin'),
        const GlobalDepartmentSwitcher(current: 'HR'),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _CompanyOverview(cid: _cid),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'ব্যবস্থাপনা মডিউল (Management Modules)',
                    style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                ),
                const SizedBox(height: 12),
                _ModuleGrid(sections: _sections, onCategoryTap: _openCategory),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollBody() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const GlobalDepartmentSwitcher(current: 'HR'),
        const SizedBox(height: 16),
        _CompanyOverview(cid: _cid),
        const SizedBox(height: 24),
        _ModuleGrid(sections: _sections, onCategoryTap: _openCategory),
      ],
    );
  }

  Widget _buildFloatingBottomBar() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomBarIcon(icon: Icons.home_rounded, isActive: _currentIndex == 0, onTap: () => setState(() => _currentIndex = 0)),
            _BottomBarIcon(icon: Icons.calendar_today_rounded, isActive: _currentIndex == 1, onTap: () => setState(() => _currentIndex = 1)),
            _BottomBarIcon(icon: Icons.notifications_none_rounded, isActive: _currentIndex == 2, onTap: () => setState(() => _currentIndex = 2), hasBadge: true),
            _BottomBarIcon(icon: Icons.person_outline_rounded, isActive: _currentIndex == 3, onTap: () => setState(() => _currentIndex = 3)),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }
}

class _Header extends StatelessWidget {
  final String name;
  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
      decoration: const BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Expanded(
            child: Column(
            children: [
              Text('স্বাগতম (Welcome back)', style: AppFonts.banglaBody(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
              Text(name, style: AppFonts.banglaHeading(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(name.isNotEmpty ? name[0] : 'H', style: AppFonts.banglaHeading(color: _primaryGreen, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }
}

class _CompanyOverview extends StatelessWidget {
  final String cid;
  const _CompanyOverview({required this.cid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('কোম্পানি সারসংক্ষেপ (Overview)', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              Text('সকল তথ্য', style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: _accentGreen)),
            ],
          ),
          const SizedBox(height: 2),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            childAspectRatio: 1.4,
            children: [
              _MetricItem(label: 'কর্মী (Staff)', stream: DB.colSync(cid, C.users).snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryGreen),
              _MetricItem(label: 'ছুটি (Leaves)', stream: DB.colSync(cid, C.leaveRequests).where('status', isEqualTo: 'pending').snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryGreen),
              _MetricItem(label: 'অভিযোগ (Issues)', stream: DB.colSync(cid, C.complaints).where('status', isEqualTo: 'pending').snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryGreen),
              _MetricItem(label: 'পে-রোল (Payroll)', stream: Stream.value('৪.২ লক্ষ'), primaryColor: _primaryGreen),
              _MetricItem(label: 'নিয়োগ (Hiring)', stream: Stream.value('৩ জন'), primaryColor: _primaryGreen),
              _MetricItem(label: 'রিটেনশন (Retain)', stream: Stream.value('৯৮%'), primaryColor: _primaryGreen),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final Stream<String> stream;
  final Color primaryColor;
  const _MetricItem({required this.label, required this.stream, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<String>(
          stream: stream,
          builder: (_, snap) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              (snap.data ?? '—').toBanglaDigits,
              style: AppFonts.banglaData(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: primaryColor,
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppFonts.banglaBody(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  final List<_Section> sections;
  final void Function(String, List<int>) onCategoryTap;
  const _ModuleGrid({required this.sections, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2),
      itemBuilder: (context, i) {
        final sec = sections[i];
        return _ModuleTile(label: sec.label, icon: _getIcon(sec.label), onTap: () => onCategoryTap(sec.label, sec.indices));
      },
    );
  }

  IconData _getIcon(String label) {
    if (label.contains('People') || label.contains('জনবল')) return Icons.person_outline_rounded;
    if (label.contains('Time') || label.contains('সময়')) return Icons.access_time_rounded;
    if (label.contains('Payroll') || label.contains('বেতন')) return Icons.account_balance_wallet_outlined;
    if (label.contains('Finance') || label.contains('অর্থ')) return Icons.pie_chart_outline_rounded;
    if (label.contains('HR Ops')) return Icons.favorite_border_rounded;
    if (label.contains('Comms') || label.contains('যোগাযোগ')) return Icons.chat_bubble_outline_rounded;
    return Icons.category_rounded;
  }
}

class _ModuleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ModuleTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: _primaryGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppFonts.banglaBody(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _BottomBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool hasBadge;
  const _BottomBarIcon({required this.icon, required this.isActive, required this.onTap, this.hasBadge = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isActive ? _primaryGreen : const Color(0xFF9CA3AF), size: 28),
          if (hasBadge) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
        ],
      ),
    );
  }
}

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

