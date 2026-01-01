// lib/features/admin/presentation/screens/admin_hr_payroll.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminHrPayrollPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminHrPayrollPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Workforce Overview',
    'Attendance Summary',
    'Payroll Summary',
    'Incentives & Bonuses',
    'Overtime Report',
    'Leave Overview',
    'Performance Metrics',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'HR & PAYROLL',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
