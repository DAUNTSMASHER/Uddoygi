// lib/features/admin/presentation/screens/admin_manufacturing.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';

class AdminManufacturingPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminManufacturingPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Production Overview',
    'Work Orders',
    'Production Status',
    'Cost Breakdown',
    'Quality Control',
    'Wastage Report',
    'Rework Log',
    'Capacity Utilization',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'MANUFACTURING',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
