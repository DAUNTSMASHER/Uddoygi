import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/screens/products.dart'; // ✅ Updated
import '../widgets/marketing_drawer.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({Key? key}) : super(key: key);

  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  String? email;

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Notices', Icons.notifications_active, '/marketing/notices'),
    _DashboardItem('Clients', Icons.people_alt, '/marketing/clients'),
    _DashboardItem('Sales', Icons.point_of_sale, '/marketing/sales'),
    _DashboardItem('Welfare', Icons.volunteer_activism, '/common/welfare'),
    _DashboardItem('Complaints', Icons.warning_amber, '/common/complaints'),
    _DashboardItem('Messages', Icons.message, '/common/messages'),
    _DashboardItem('Tasks', Icons.task, '/marketing/task_assignment'),
    _DashboardItem('Campaigns', Icons.campaign, '/marketing/campaign'),
    _DashboardItem('Orders', Icons.shopping_bag, '/marketing/orders'),
    _DashboardItem('Loans', Icons.request_page, '/marketing/loan_request'),
    _DashboardItem('Products', Icons.inventory, ''), // route handled manually
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
        email = session['email'] as String?;
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

  void _onItemTap(_DashboardItem item) {
    if (item.title == 'Products') {
      if (email != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductsPage(userEmail: email!), // ✅ updated target
          ),
        );
      }
    } else {
      Navigator.pushNamed(context, item.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Marketing Dashboard',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const MarketingDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null) ...[
              Text(
                'Welcome, $email',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _darkBlue,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
                children: dashboardItems.map((item) {
                  return Card(
                    color: _darkBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _onItemTap(item),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, size: 24, color: Colors.white),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
