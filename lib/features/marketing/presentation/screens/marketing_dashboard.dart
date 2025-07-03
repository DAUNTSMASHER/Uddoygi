import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/marketing_drawer.dart';

class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({super.key});

  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  String? uid;
  String? email;
  String? role;

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Notices', Icons.notifications_active, Colors.pink, '/marketing/notices'),
    _DashboardItem('Clients', Icons.people_alt, Colors.blue, '/marketing/clients'),
    _DashboardItem('Sales', Icons.point_of_sale, Colors.green, '/marketing/sales'),
    _DashboardItem('Welfare', Icons.volunteer_activism, Colors.indigo, '/common/welfare'),
    _DashboardItem('Complaints', Icons.warning_amber, Colors.deepOrange, '/common/complaints'),
    _DashboardItem('Messages', Icons.message, Colors.cyan, '/common/messages'),
    _DashboardItem('Task Assignment', Icons.task, Colors.orange, '/marketing/task_assignment'),
    _DashboardItem('Campaign', Icons.campaign, Colors.purple, '/marketing/campaign'),
    _DashboardItem('Orders', Icons.assignment_turned_in, Colors.teal, '/marketing/orders'),
    _DashboardItem('Loan Requests', Icons.request_page, Colors.red, '/marketing/loan_request'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null) {
      setState(() {
        uid = session['uid'];
        email = session['email'];
        role = session['role'];
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Welcome Marketing', style: TextStyle(fontSize: 18)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const MarketingDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Welcome, $email',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
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
