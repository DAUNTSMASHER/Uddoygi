// lib/features/admin/presentation/screens/admin_settings_admin.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminSettingsAdminPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminSettingsAdminPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Company Profile',
    'User Roles',
    'Approval Rules',
    'Notification Settings',
    'Tax & Currency',
    'System Logs',
    'Data Backup',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'SETTINGS & ADMIN',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
