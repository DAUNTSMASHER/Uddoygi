import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/admin_dashboard_summary.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool showSummary = true;
  bool isLoading = false;
  String? email;
  String? uid;
  String? role;

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Notices', Icons.announcement, '/admin/notices'),
    _DashboardItem('Employees', Icons.people, '/admin/employees'),
    _DashboardItem('Reports', Icons.bar_chart, '/admin/reports'),
    _DashboardItem('Welfare', Icons.favorite, '/common/welfare'),
    _DashboardItem('Complaints', Icons.report_problem, '/common/complaints'),
    _DashboardItem('Salary', Icons.attach_money, '/admin/salary'),
    _DashboardItem('Messages', Icons.message, '/common/messages'),
    _DashboardItem('R&D', Icons.science, '/admin/research'),
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
        email = session['email'];
        uid = session['uid'];
        role = session['role'];
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
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkBlue,
                ),
              ),

            const SizedBox(height: 16),

            // Search box
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _darkBlue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: _darkBlue),
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Summary header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkBlue)),
                IconButton(
                  icon: Icon(
                    showSummary ? Icons.expand_less : Icons.expand_more,
                    color: _darkBlue,
                  ),
                  onPressed: () => setState(() => showSummary = !showSummary),
                ),
              ],
            ),

            if (showSummary)
              isLoading
                  ? const Center(child: CircularProgressIndicator(color: _darkBlue))
                  : const SizedBox(height: 400, child: AdminDashboardSummary()),

            const SizedBox(height: 32),

            const Text('Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkBlue)),

            const SizedBox(height: 16),

            // Grid of action cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3,
              children: dashboardItems.map((item) {
                return InkWell(
                  onTap: () => Navigator.pushNamed(context, item.route),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _darkBlue.withOpacity(0.05),
                      border: Border.all(color: _darkBlue.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(item.icon, color: _darkBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: _darkBlue),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
