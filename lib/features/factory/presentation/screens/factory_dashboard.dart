import 'package:flutter/material.dart';

class FactoryDashboard extends StatelessWidget {
  const FactoryDashboard({super.key});

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Work Orders', Icons.work, Colors.blue, '/factory/work_orders'),
    _DashboardItem('Resource Requests', Icons.request_page, Colors.green, '/factory/resource_requests'),
    _DashboardItem('Progress Update', Icons.update, Colors.orange, '/factory/progress_update'),
    _DashboardItem('Attendance', Icons.event_available, Colors.purple, '/factory/attendance'),
    _DashboardItem('Loan Requests', Icons.request_page, Colors.teal, '/factory/loan_requests'),
    _DashboardItem('Salary & Overtime', Icons.money_off, Colors.red, '/factory/salary_overtime'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: dashboardItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
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

  const _DashboardItem(this.title, this.icon, this.color, this.route);
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItem item;
  const _DashboardTile({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.15),
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
