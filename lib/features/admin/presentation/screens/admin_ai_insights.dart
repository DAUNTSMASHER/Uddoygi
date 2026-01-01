// lib/features/admin/presentation/screens/admin_ai_insights.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminAiInsightsPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminAiInsightsPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Smart Alerts',
    'Anomaly Detection',
    'Sales Predictions',
    'Cost Optimization',
    'Demand Forecast',
    'Risk Warnings',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'AI INSIGHTS',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
