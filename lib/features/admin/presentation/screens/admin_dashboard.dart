import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data for dashboard tiles
    final dashboardItems = [
      _DashboardItem('Employees', Icons.people, Colors.blue, '/admin/employees'),
      _DashboardItem('Reports', Icons.bar_chart, Colors.green, '/admin/reports'),
      _DashboardItem('Welfare Scheme', Icons.favorite, Colors.pink, '/admin/welfare'),
      _DashboardItem('Complaints', Icons.report_problem, Colors.red, '/admin/complaints'),
      _DashboardItem('Salary', Icons.attach_money, Colors.orange, '/admin/salary'),
      _DashboardItem('Notices', Icons.announcement, Colors.purple, '/admin/notices'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: dashboardItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,  // 2 items per row
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final item = dashboardItems[index];
            return _DashboardTile(item: item);
          },
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

  _DashboardItem(this.title, this.icon, this.color, this.route);
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItem item;

  const _DashboardTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Navigate to the route
        Navigator.pushNamed(context, item.route);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 48, color: item.color),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: item.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
