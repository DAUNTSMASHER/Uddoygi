import 'package:flutter/material.dart';
import 'package:uddoygi/features/admin/presentation/screens/admin_dashboard.dart';
// Import other admin screens as needed...

final Map<String, WidgetBuilder> appRoutes = {
  '/admin/dashboard': (context) => const AdminDashboard(),
  '/admin/employees': (context) => const PlaceholderScreen(title: 'Employees'),
  '/admin/reports': (context) => const PlaceholderScreen(title: 'Reports'),
  '/admin/welfare': (context) => const PlaceholderScreen(title: 'Welfare Scheme'),
  '/admin/complaints': (context) => const PlaceholderScreen(title: 'Complaints'),
  '/admin/salary': (context) => const PlaceholderScreen(title: 'Salary'),
  '/admin/notices': (context) => const PlaceholderScreen(title: 'Notices'),
  // add other routes similarly
};

// Temporary placeholder screen for pages not yet implemented
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Coming soon: $title')),
    );
  }
}
