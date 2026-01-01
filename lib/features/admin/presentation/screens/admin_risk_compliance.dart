// lib/features/admin/presentation/screens/admin_risk_compliance.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminRiskCompliancePage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminRiskCompliancePage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Risk Dashboard',
    'Delayed Orders',
    'Payment Risks',
    'Contract Alerts',
    'Quality Issues',
    'Compliance Status',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'RISK & COMPLIANCE',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
