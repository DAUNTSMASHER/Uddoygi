// lib/features/admin/presentation/screens/admin_finance.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminFinancePage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminFinancePage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Revenue Summary',
    'Profit & Loss',
    'Cash Flow',
    'Accounts Receivable',
    'Accounts Payable',
    'Expense Overview',
    'Payment Status',
    'Financial Alerts',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'FINANCE',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
