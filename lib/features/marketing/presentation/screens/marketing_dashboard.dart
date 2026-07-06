// lib/features/marketing/presentation/screens/marketing_dashboard.dart
import 'dart:async';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/marketing_drawer.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/marketing_web_shell.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/features/hr/presentation/screens/hr_category_screen.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/widgets/u_inventory_analytics.dart';
import 'package:uddoygi/widgets/global_department_switcher.dart';
import 'package:uddoygi/features/marketing/presentation/screens/products.dart';
import 'package:uddoygi/features/marketing/presentation/screens/renumeration_dashboard.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/campaign_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/all_invoices_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/new_invoices_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/task_assignment_screen.dart';
import 'package:uddoygi/features/marketing/presentation/screens/marketing_notice.dart';
import 'package:uddoygi/features/common/stock/stockhistory.dart';
import 'package:uddoygi/features/common/salary_screen.dart';
import 'package:uddoygi/features/factory/presentation/screens/loan_request_screen.dart';

// ── Constants (Marketing Blue Theme) ────────────────────────────────────────
const _primaryBlue = Color(0xFF0D47A1);
const _backgroundColor = Color(0xFFF6F8FF);
const _secondaryColor = Color(0xFFE3F2FD);
const _surfaceColor   = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({super.key});
  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _cid = '';
  String? name;
  String? email;
  String? photoUrl;
  int _currentIndex = 0;

  final List<_DashboardItem> _allItems = const [
    _DashboardItem('গ্রাহক তালিকা (Clients)',     Icons.people_alt_rounded,           '/marketing/clients'),
    _DashboardItem('অর্ডার ব্যবস্থাপনা (Orders)',      Icons.shopping_bag_rounded,         '/marketing/orders'),
    _DashboardItem('টাস্ক অ্যাসাইনমেন্ট (Tasks)',       Icons.task_alt_rounded,             '/marketing/task_assignment'),
    _DashboardItem('পণ্য ক্যাটালগ (Products)',    Icons.inventory_2_rounded,          '/marketing/products'),
    _DashboardItem('সেলস ও বিক্রি (Sales)',       Icons.point_of_sale_rounded,        '/marketing/sales'),
    _DashboardItem('বেতন ও ভাতা (Salary)',      Icons.account_balance_wallet_rounded, '/marketing/salary'),
    _DashboardItem('ঋণ আবেদন (Loans)',       Icons.account_balance_rounded,      '/marketing/loans'),
    _DashboardItem('রেমুনারেশন (Renumeration)',Icons.paid_rounded,                 '/marketing/renumeration'),
    _DashboardItem('মার্কেটিং ক্যাম্পেইন (Campaigns)',   Icons.campaign_rounded,             '/marketing/campaigns'),
    _DashboardItem('নোটিশ বোর্ড (Notices)',     Icons.notifications_active_rounded, '/marketing/notices'),
    _DashboardItem('মেসেজ ও বার্তা (Messages)',    Icons.chat_bubble_outline_rounded,  '/common/messages'),
    _DashboardItem('অভিযোগ বক্স (Complaints)',  Icons.report_problem_rounded,       '/common/complaints'),
    _DashboardItem('কল্যাণ তহবিল (Welfare)',     Icons.volunteer_activism_rounded,   '/common/welfare'),
    _DashboardItem('স্টক হিস্ট্রি (Stock)',       Icons.sync_alt_rounded,             '/marketing/stock'),
    _DashboardItem('আরএন্ডডি রিকোয়েস্ট (R&D Request)', Icons.science_rounded,              '/rnd/request'),
    _DashboardItem('উপস্থিতি (Attendance)',  Icons.event_available_rounded,      '/marketing/attendance'),
    _DashboardItem('ইনভয়েস তালিকা (All Invoices)', Icons.receipt_long_rounded,       '/marketing/sales/all'),
    _DashboardItem('নতুন ইনভয়েস (New Invoice)',  Icons.add_card_rounded,             '/marketing/sales/new'),
  ];

  static const _sections = [
    _Section('অপারেশনস (Operations)', [0, 1, 2, 3]),
    _Section('সেলস ও অর্থ (Finance & Growth)', [4, 5, 6, 7, 8, 16, 17]),
    _Section('সহযোগিতা (Support)', [9, 10, 11, 12]),
    _Section('অন্যান্য (Misc)', [13, 14, 15]),
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
    final current = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() {
        email    = session?['email'] as String? ?? current?.email;
        name     = session?['name'] ?? current?.displayName ?? current?.email ?? 'মার্কেটিং (Marketing)';
        photoUrl = current?.photoURL;
      });
    }
  }

  void _onTapItem(_DashboardItem item) {
    switch (item.route) {
      case '/marketing/salary':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen()));
        return;
      case '/marketing/products':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: email ?? '')));
        return;
      case '/marketing/renumeration':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RenumerationDashboard()));
        return;
      case '/marketing/campaigns':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsManagerMobile()));
        return;
      case '/marketing/stock':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockHistoryScreen()));
        return;
      case '/marketing/sales':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
        return;
      case '/marketing/sales/all':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen()));
        return;
      case '/marketing/sales/new':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen()));
        return;
      case '/marketing/loans':
        Navigator.push(context, MaterialPageRoute(builder: (_) => LoanRequestScreen()));
        return;
      default:
        Navigator.pushNamed(context, item.route);
    }
  }

  void _openCategory(String label, List<int> indices) {
    final categoryItems = indices.map((i) {
      final it = _allItems[i];
      return HrCategoryItem(it.title, it.icon, () => _onTapItem(it));
    }).toList();
    HrCategoryScreen.navigate(context, label, categoryItems, themeColor: _primaryBlue);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (isDesktop) {
      return MarketingWebShell(
        title: 'মার্কেটিং ড্যাশবোর্ড (Marketing Dashboard)',
        child: _buildScrollBody(),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      drawer: const MarketingDrawer(),
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
        _Header(
          name: name ?? 'মার্কেটিং (Marketing)', 
          onNotifTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const GlobalDepartmentSwitcher(current: 'Marketing'),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _MarketingOverview(cid: _cid),
                const SizedBox(height: 12),
                const UInventoryAnalytics(themeColor: _primaryBlue).animate().fadeIn(delay: 200.ms),
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
        const GlobalDepartmentSwitcher(current: 'Marketing'),
        const SizedBox(height: 16),
        _MarketingOverview(cid: _cid),
        const SizedBox(height: 20),
        const UInventoryAnalytics(themeColor: _primaryBlue).animate().fadeIn(delay: 200.ms),
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
            _BottomBarIcon(icon: Icons.assignment_rounded, isActive: _currentIndex == 1, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskAssignmentScreen()))),
            _BottomBarIcon(icon: Icons.receipt_long_rounded, isActive: _currentIndex == 2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
            _BottomBarIcon(icon: Icons.notifications_rounded, isActive: _currentIndex == 3, hasBadge: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketingNoticeScreen()))),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }
}

class _Header extends StatelessWidget {
  final String name;
  final VoidCallback onNotifTap;
  final VoidCallback onMenuTap;
  const _Header({required this.name, required this.onNotifTap, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
      decoration: const BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
            onPressed: onMenuTap,
          ),
          Expanded(
            child: Column(
            children: [
              Text('স্বাগতম (Welcome back)', style: AppFonts.banglaBody(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
              Text(name, style: AppFonts.banglaHeading(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          GestureDetector(
            onTap: onNotifTap,
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
              child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }
}

class _MarketingOverview extends StatelessWidget {
  final String cid;
  const _MarketingOverview({required this.cid});

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
              Text('মার্কেটিং ওভারভিউ (Overview)', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              Text('সকল তথ্য', style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryBlue)),
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
              _MetricItem(label: 'গ্রাহক (Clients)', stream: DB.colSync(cid, C.customers).snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryBlue),
              _MetricItem(label: 'ইনভয়েস (Invoices)', stream: DB.colSync(cid, C.invoices).snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryBlue),
              _MetricItem(label: 'ক্যাম্পেইন (Ads)', stream: DB.colSync(cid, C.campaigns).snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryBlue),
              _MetricItem(label: 'মোট বিক্রি (Sales)', stream: Stream.value('৳৮.৪ লক্ষ'), primaryColor: _primaryBlue),
              _MetricItem(label: 'ইনসেনটিভ (Bonus)', stream: Stream.value('৳৪৫ হাজার'), primaryColor: _primaryBlue),
              _MetricItem(label: 'অভিযোগ (Issues)', stream: DB.colSync(cid, C.complaints).where('status', isEqualTo: 'pending').snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryBlue),
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
    if (label.contains('Operations') || label.contains('অপারেশনস')) return Icons.people_alt_rounded;
    if (label.contains('Finance') || label.contains('সেলস')) return Icons.point_of_sale_rounded;
    if (label.contains('Support') || label.contains('সহযোগিতা')) return Icons.support_agent_rounded;
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
              child: Icon(icon, color: _primaryBlue, size: 20),
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
          Icon(icon, color: isActive ? _primaryBlue : const Color(0xFF9CA3AF), size: 28),
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
