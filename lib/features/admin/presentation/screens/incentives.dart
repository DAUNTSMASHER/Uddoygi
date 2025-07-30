// lib/features/admin/presentation/screens/incentive_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:uddoygi/features/incentive_calculation/admin_overview_dashboard_screen.dart';
import 'package:uddoygi/features/incentive_calculation/hr_incentive_calculator_screen.dart';
import 'package:uddoygi/features/incentive_calculation/incentive_history_screen.dart';
const Color _darkBlue = Color(0xFF0D47A1);
class IncentiveScreen extends StatelessWidget {
  const IncentiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(('Incentive Report') , style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // ⬅️ changed from 3 to 2
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1, // Optional: improve spacing
          children: [
            _IncentiveTile(
              label: 'Overview',
              icon: Icons.dashboard,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminOverviewDashboardScreen()),
              ),
            ),
            _IncentiveTile(
              label: 'Incentive Calculator',
              icon: Icons.calculate,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HRIncentiveCalculatorScreen()),
              ),
            ),

            _IncentiveTile(
              label: 'Incentive History',
              icon: Icons.history,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IncentiveHistoryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncentiveTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _IncentiveTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.blue.shade900),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
