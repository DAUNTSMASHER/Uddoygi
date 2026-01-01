// lib/features/admin/presentation/screens/admin_quick_actions.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';

class AdminQuickActionsPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminQuickActionsPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Create Order',
    'Add Invoice',
    'Record Payment',
    'Generate Report',
    'Export Data',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'QUICK ACTIONS',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
