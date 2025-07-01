import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/admin_dashboard_summary.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool showSummary = true;
  bool isLoading = false;

  final List<_DashboardItem> dashboardItems = [
    _DashboardItem('Notices', Icons.announcement, Colors.purple, '/admin/notices'),
    _DashboardItem('Employees', Icons.people, Colors.blue, '/admin/employees'),
    _DashboardItem('Reports', Icons.bar_chart, Colors.green, '/admin/reports'),
    _DashboardItem('Welfare Scheme', Icons.favorite, Colors.pink, '/admin/welfare'),
    _DashboardItem('Complaints', Icons.report_problem, Colors.red, '/admin/complaints'),
    _DashboardItem('Salary', Icons.attach_money, Colors.orange, '/admin/salary'),
    _DashboardItem('Messages', Icons.message, Colors.teal, '/admin/messages'),
    _DashboardItem('R&D', Icons.science, Colors.deepPurple, '/admin/research'),
  ];

  Future<void> _refreshSummary() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // simulate refresh
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Welcome Admin', style: TextStyle(fontSize: 18)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshSummary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(showSummary ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => showSummary = !showSummary),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Summary Section
              if (showSummary)
                isLoading
                    ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator()))
                    : const SizedBox(height: 220, child: AdminDashboardSummary()),

              const SizedBox(height: 10),

              // Dashboard Items
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashboardItems.length,
                itemBuilder: (context, index) {
                  final item = dashboardItems[index];
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, item.route),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(item.icon, size: 40, color: item.color),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: item.color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to explore',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.color.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
  final Color color;
  final String route;

  const _DashboardItem(this.title, this.icon, this.color, this.route);
}
