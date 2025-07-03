import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  String? userEmail;
  String? userName;

  final List<_DashboardItem> dashboardItems = const [
    // Common
    _DashboardItem('Notices', Icons.notifications_active, Colors.indigo, '/hr/notices'),
    _DashboardItem('Messages', Icons.message, Colors.blueAccent, '/common/messages'),
    _DashboardItem('Welfare', Icons.volunteer_activism, Colors.deepPurple, '/common/welfare'),
    _DashboardItem('Complaints', Icons.report_problem, Colors.deepOrange, '/common/complaints'),
    _DashboardItem('Recruitment', Icons.person_add, Colors.blue, '/hr/recruitment'),
    _DashboardItem('Salary Management', Icons.money, Colors.green, '/hr/salary_management'),
    _DashboardItem('Incentives', Icons.card_giftcard, Colors.orange, '/hr/incentives'),
    _DashboardItem('Loan Approval', Icons.approval, Colors.purple, '/hr/loan_approval'),
    _DashboardItem('Balance Update', Icons.account_balance_wallet, Colors.teal, '/hr/balance_update'),
    _DashboardItem('Procurement', Icons.shopping_cart, Colors.red, '/hr/procurement'),
    _DashboardItem('Tax', Icons.receipt_long, Colors.brown, '/hr/tax'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userEmail = (session != null && session['email'] != null) ? session['email'] : '';
      userName = (session != null && session['name'] != null)
          ? session['name']
          : (session != null && session['email'] != null ? session['email'] : '');
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              backgroundColor: Colors.indigo[100],
              child: const Icon(Icons.person, color: Colors.indigo),
            ),
          ),
        ],
      ),
      drawer: const HRDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userName != null && userName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Welcome, $userName',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.indigo),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: dashboardItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
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
  const _DashboardTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(item.icon, size: 40, color: item.color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
