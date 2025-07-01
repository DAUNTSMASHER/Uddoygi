import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart'; // ✅ Import
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
    _DashboardItem('Clients', Icons.people_alt, Colors.blue, '/marketing/clients'),
    _DashboardItem('Sales', Icons.point_of_sale, Colors.green, '/marketing/sales'),
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
    await LocalStorageService.clearSession(); // ✅ Clear session on logout
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const MarketingDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (email != null)
              Text(
                'Welcome, $email',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 16),

            // 🔍 Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  hintText: 'Search clients, orders...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🧩 Dashboard Grid
            Expanded(
              child: GridView.builder(
                itemCount: dashboardItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final item = dashboardItems[index];
                  return _DashboardTile(item: item);
                },
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
  final Color color;
  final String route;

  const _DashboardItem(this.title, this.icon, this.color, this.route);
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItem item;
  const _DashboardTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: item.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 42, color: item.color),
              const SizedBox(height: 10),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: item.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
