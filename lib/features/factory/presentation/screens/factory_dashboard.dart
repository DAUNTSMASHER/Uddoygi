// lib/features/factory/presentation/screens/factory_dashboard.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_drawer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/widgets/u_ai_assistant.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/widgets/u_inventory_analytics.dart';
import 'factory_category_screen.dart';
import 'package:uddoygi/widgets/global_department_switcher.dart';
import 'package:uddoygi/features/factory/presentation/factory/industrial_velocity_dashboard_screen.dart';
import 'package:uddoygi/features/factory/presentation/factory/purchase_order.dart' show PurchaseOrdersScreen;
import 'package:uddoygi/features/factory/presentation/factory/QC_report.dart' show QCReportScreen;
import 'package:uddoygi/features/factory/presentation/factory/daily_production.dart' show DailyProductionScreen;
import 'package:uddoygi/features/factory/presentation/factory/inventory_screen.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_attendance_screen.dart';
import 'package:uddoygi/features/factory/presentation/screens/factory_notice.dart';
import 'package:uddoygi/features/common/presentation/screens/messages_screen.dart';

// ── Constants (Factory Red/Maroon Theme) ────────────────────────────────────
const _primaryRed = Color(0xFF8B0000);
const _accentRed  = Color(0xFF5A0000);
const _backgroundColor = Color(0xFFF9F9F9);
const _secondaryColor = Color(0xFFFDE8E8);
const _surfaceColor   = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({super.key});
  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
  String _cid = '';
  String? name;
  String? photoUrl;
  int _currentIndex = 0;

  final List<_DashboardItem> _allItems = const [
    _DashboardItem('ওয়ার্ক অর্ডার (Work Orders)', Icons.assignment_rounded, IndustrialVelocityDashboardScreen()),
    _DashboardItem('পার্চেস অর্ডার (Purchase Orders)', Icons.shopping_cart_rounded, PurchaseOrdersScreen()),
    _DashboardItem('দৈনিক উৎপাদন (Daily Production)', Icons.precision_manufacturing_rounded, DailyProductionScreen()),
    _DashboardItem('ইনভেন্টরি ও মজুদ (Inventory)', Icons.inventory_2_rounded, InventoryScreen()),
    _DashboardItem('কিউসি রিপোর্ট (QC Reports)', Icons.verified_rounded, QCReportScreen()),
    _DashboardItem('উপস্থিতি (Attendance)', Icons.fingerprint_rounded, FactoryAttendanceScreen()),
    _DashboardItem('মেসেজ ও বার্তা (Messages)', Icons.chat_rounded, MessagesScreen()),
    _DashboardItem('নোটিশ বোর্ড (Notices)', Icons.campaign_rounded, FactoryNoticeScreen()),
  ];

  static const _sections = [
    _Section('অপারেশনস (Operations)', [0, 1]),
    _Section('প্রোডাকশন (Production)', [2, 3]),
    _Section('সিস্টেম কন্ট্রোল (Controls)', [4, 5, 6, 7]),
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
        name = session?['name'] ?? current?.displayName ?? current?.email ?? 'ফ্যাক্টরি অ্যাডমিন (Factory Admin)';
        photoUrl = current?.photoURL;
      });
    }
  }

  void _openCategory(String label, List<int> indices) {
    final categoryItems = indices.map((i) => FactoryCategoryItem(_allItems[i].title, _allItems[i].icon, _allItems[i].route)).toList();
    FactoryCategoryScreen.navigate(context, label, categoryItems);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        drawer: const FactoryDrawer(),
        appBar: AppBar(title: Text('ফ্যাক্টরি ড্যাশবোর্ড (Factory Dashboard)', style: AppFonts.banglaHeading(color: Colors.white, fontSize: 18)), backgroundColor: _primaryRed),
        body: _buildScrollBody(),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      drawer: const FactoryDrawer(),
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
        _Header(name: name ?? 'ফ্যাক্টরি অ্যাডমিন', onNotifTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage()))),
        const GlobalDepartmentSwitcher(current: 'Factory'),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _FactoryOverview(cid: _cid),
                const SizedBox(height: 12),
                const UInventoryAnalytics(themeColor: _primaryRed).animate().fadeIn(delay: 200.ms),
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
        const GlobalDepartmentSwitcher(current: 'Factory'),
        const SizedBox(height: 16),
        _FactoryOverview(cid: _cid),
        const SizedBox(height: 20),
        const UInventoryAnalytics(themeColor: _primaryRed).animate().fadeIn(delay: 200.ms),
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
            _BottomBarIcon(icon: Icons.assignment_rounded, isActive: _currentIndex == 1, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IndustrialVelocityDashboardScreen()))),
            _BottomBarIcon(icon: Icons.notifications_none_rounded, isActive: _currentIndex == 2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())), hasBadge: true),
            _BottomBarIcon(icon: Icons.person_outline_rounded, isActive: _currentIndex == 3, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FactoryAttendanceScreen()))),
          ],
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }
}

class _Header extends StatelessWidget {
  final String name;
  final VoidCallback onNotifTap;
  const _Header({required this.name, required this.onNotifTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
      decoration: const BoxDecoration(
        color: _primaryRed,
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

class _FactoryOverview extends StatelessWidget {
  final String cid;
  const _FactoryOverview({required this.cid});

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
              Text('ফ্যাক্টরি ওভারভিউ (Overview)', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              Text('সকল তথ্য', style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryRed)),
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
              _MetricItem(label: 'অর্ডার (Orders)', stream: DB.colSync(cid, C.workOrders).snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryRed),
              _MetricItem(label: 'ইন প্রোডাকশন (Active)', stream: DB.colSync(cid, C.workOrders).where('status', isEqualTo: 'In Production').snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryRed),
              _MetricItem(label: 'দৈনিক (Daily)', stream: Stream.value('৩৫০ পিস'), primaryColor: _primaryRed),
              _MetricItem(label: 'মজুদ (Stock)', stream: DB.colSync(cid, C.products).snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryRed),
              _MetricItem(label: 'কিউসি রেট (QC)', stream: Stream.value('৯৬.৪%'), primaryColor: _primaryRed),
              _MetricItem(label: 'অভিযোগ (Issues)', stream: DB.colSync(cid, C.complaints).where('status', isEqualTo: 'pending').snapshots().map((s) => '${s.docs.length}'), primaryColor: _primaryRed),
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
    if (label.contains('Operations') || label.contains('অপারেশনস')) return Icons.assignment_rounded;
    if (label.contains('Production') || label.contains('প্রোডাকশন')) return Icons.precision_manufacturing_rounded;
    return Icons.verified_rounded;
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
              child: Icon(icon, color: _primaryRed, size: 20),
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
          Icon(icon, color: isActive ? _primaryRed : const Color(0xFF9CA3AF), size: 28),
          if (hasBadge) Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
        ],
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final dynamic route;
  const _DashboardItem(this.title, this.icon, this.route);
}

class _Section {
  final String label;
  final List<int> indices;
  const _Section(this.label, this.indices);
}
