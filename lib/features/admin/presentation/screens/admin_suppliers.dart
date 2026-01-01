// lib/features/admin/presentation/screens/admin_suppliers.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminSuppliersPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminSuppliersPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Supplier Directory',
    'Supplier Ledger',
    'Payable Summary',
    'Purchase Orders',
    'Delivery Status',
    'Supplier Performance',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'SUPPLIERS',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
