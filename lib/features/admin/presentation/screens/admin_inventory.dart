// lib/features/admin/presentation/screens/admin_inventory.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminInventoryPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminInventoryPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Stock Summary',
    'Raw Material Stock',
    'Work-in-Progress (WIP)',
    'Finished Goods',
    'Low Stock Alerts',
    'Inventory Aging',
    'Stock Movement',
    'Batch Tracking',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'INVENTORY',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
