import 'package:flutter/material.dart';

class HRDashboard extends StatelessWidget {
  const HRDashboard({super.key});

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Recruitment', Icons.person_add, Colors.blue, '/hr/recruitment'),
    _DashboardItem('Salary Management', Icons.money, Colors.green, '/hr/salary_management'),
    _DashboardItem('Incentives', Icons.card_giftcard, Colors.orange, '/hr/incentives'),
    _DashboardItem('Loan Approval', Icons.approval, Colors.purple, '/hr/loan_approval'),
    _DashboardItem('Balance Update', Icons.account_balance_wallet, Colors.teal, '/hr/balance_update'),
    _DashboardItem('Procurement', Icons.shopping_cart, Colors.red, '/hr/procurement'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Dashboard'),
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
