// lib/features/admin/presentation/screens/admin_analytics_kpis.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminAnalyticsKpisPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminAnalyticsKpisPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Key Metrics',
    'Growth Trends',
    'Margin Analysis',
    'Revenue by Country',
    'Profit by Product',
    'Cost vs Revenue',
    'Forecast & Projections',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'ANALYTICS & KPIs',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
