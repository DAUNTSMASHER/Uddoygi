// lib/features/admin/presentation/screens/admin_security.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminSecurityPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminSecurityPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Access Control',
    'Activity Logs',
    'Login History',
    'Device Sessions',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'SECURITY',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
