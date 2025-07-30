// lib/features/hr/presentation/screens/incentive_hr_screen.dart

import 'package:flutter/material.dart';
import 'package:uddoygi/features/incentive_calculation/hr_incentive_calculator_screen.dart';
import 'package:uddoygi/features/incentive_calculation/incentive_history_screen.dart';


class IncentivehrScreen extends StatelessWidget {
  const IncentivehrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade800,
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        backgroundColor: const Color(0xFF003087),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _HrIncentiveTile(
              label: 'Incentive Calculator',
              icon: Icons.calculate,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HRIncentiveCalculatorScreen()),
              ),
            ),

            _HrIncentiveTile(
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

class _HrIncentiveTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HrIncentiveTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: Colors.indigo.shade900),
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