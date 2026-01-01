// lib/features/admin/presentation/screens/admin_export_logistics.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminExportLogisticsPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminExportLogisticsPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Shipment Dashboard',
    'Export Orders',
    'Shipping Status',
    'Delivery Tracking',
    'Country-wise Export',
    'Courier Performance',
    'Delay Reports',
    'Export Documentation',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'EXPORT & LOGISTICS',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
