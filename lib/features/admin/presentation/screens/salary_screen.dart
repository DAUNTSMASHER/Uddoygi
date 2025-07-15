// lib/features/marketing/presentation/screens/admin_dashboard.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/admin_dashboard_summary.dart';

const Color _darkBlue   = Color(0xFF0D47A1);
const double _fontSmall = 12.0;
const double _fontMed   = 14.0;
const double _fontLarge = 16.0;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool showSummary = true;
  bool isLoading   = false;
  String? email, uid, role;

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Notices',     Icons.announcement,   '/admin/notices'),
    _DashboardItem('Employees',   Icons.people,         '/admin/employees'),
    _DashboardItem('Reports',     Icons.bar_chart,      '/admin/reports'),
    _DashboardItem('Welfare',     Icons.favorite,       '/common/welfare'),
    _DashboardItem('Complaints',  Icons.report_problem, '/common/complaints'),
    _DashboardItem('Salary',      Icons.attach_money,   '/admin/salary'),
    _DashboardItem('Messages',    Icons.message,        '/common/messages'),
    _DashboardItem('R&D',         Icons.science,        '/admin/research'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      setState(() {
        email = session['email'] as String?;
        uid   = session['uid'] as String?;
        role  = session['role'] as String?;
      });
    }
  }

  Future<void> _refreshSummary() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await LocalStorageService.clearSession();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: RefreshIndicator(
        color: _darkBlue,
        onRefresh: _refreshSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (email != null)
              Text(
                'Welcome, $email',
                style: const TextStyle(
                  fontSize: _fontMed,
                  fontWeight: FontWeight.w600,
                  color: _darkBlue,
                ),
              ),
            const SizedBox(height: 16),

            // Search box
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: _darkBlue),
                  hintText: 'Search...',
                  hintStyle: const TextStyle(fontSize: _fontSmall),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Summary section
            _sectionHeader('Summary', showSummary, () {
              setState(() => showSummary = !showSummary);
            }),
            AnimatedCrossFade(
              firstChild: isLoading
                  ? const Center(child: CircularProgressIndicator(color: _darkBlue))
                  : const AdminDashboardSummary(),
              secondChild: const SizedBox.shrink(),
              crossFadeState: showSummary
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Text('Quick Actions',
                style: const TextStyle(
                    fontSize: _fontLarge,
                    fontWeight: FontWeight.bold,
                    color: _darkBlue)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3,
              children: dashboardItems.map((item) {
                return _buildActionCard(item);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: _fontMed,
                    fontWeight: FontWeight.bold,
                    color: _darkBlue)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                color: _darkBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(_DashboardItem item) {
    return Material(
      color: _darkBlue.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(item.icon, color: _darkBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(
                        fontSize: _fontMed,
                        fontWeight: FontWeight.w600,
                        color: _darkBlue),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
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
