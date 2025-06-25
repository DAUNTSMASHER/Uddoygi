import 'package:flutter/material.dart';

class MarketingDashboard extends StatelessWidget {
  const MarketingDashboard({super.key});

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Clients', Icons.people_alt, Colors.blue, '/marketing/clients'),
    _DashboardItem('Sales', Icons.point_of_sale, Colors.green, '/marketing/sales'),
    _DashboardItem('Task Assignment', Icons.task, Colors.orange, '/marketing/task_assignment'),
    _DashboardItem('Campaign', Icons.campaign, Colors.purple, '/marketing/campaign'),
    _DashboardItem('Orders', Icons.assignment_turned_in, Colors.teal, '/marketing/orders'),
    _DashboardItem('Loan Requests', Icons.request_page, Colors.red, '/marketing/loan_request'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing Dashboard'),
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
