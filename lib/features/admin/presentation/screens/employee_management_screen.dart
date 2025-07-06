import 'package:flutter/material.dart';
import 'package:uddoygi/features/employee_management/add_employee_page.dart';
import 'package:uddoygi/features/employee_management/all_employees_page.dart';
import 'package:uddoygi/features/employee_management/hr_recommendations_page.dart';
import 'package:uddoygi/features/employee_management/transitions_page.dart';

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  static const Color _darkBlue = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashboardCard(
        title: 'Add Employee',
        icon: Icons.person_add,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEmployeePage()),
        ),
      ),
      _DashboardCard(
        title: 'All Employees',
        icon: Icons.group,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AllEmployeesPage()),
        ),
      ),
      _DashboardCard(
        title: 'Recommendations',
        icon: Icons.thumb_up,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HRRecommendationsPage()),
        ),
      ),
      _DashboardCard(
        title: 'Promotions',
        icon: Icons.swap_vert,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransitionsPage()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        backgroundColor: _darkBlue,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: cards,
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  static const Color _darkBlue = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _darkBlue, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: _darkBlue),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkBlue,
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
