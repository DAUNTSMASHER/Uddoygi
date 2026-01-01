// lib/features/admin/presentation/screens/admin_sales_marketing.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminSalesMarketingPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminSalesMarketingPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Sales Dashboard',
    'Order Pipeline',
    'Target vs Achievement',
    'Lead Management',
    'Conversion Report',
    'Customer Insights',
    'Product Performance',
    'Incentive Summary',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'SALES & MARKETING',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
