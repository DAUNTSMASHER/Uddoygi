// lib/features/admin/presentation/screens/admin_customers_buyers.dart
import 'package:flutter/material.dart';
import 'admin_report_detail.dart';
import 'admin_module_hub.dart';
class AdminCustomersBuyersPage extends StatelessWidget {
  final String? orgId;
  final DateTimeRange range;
  const AdminCustomersBuyersPage({super.key, required this.orgId, required this.range});

  static const labels = [
    'Buyer Directory',
    'Buyer Ledger',
    'Outstanding Dues',
    'Order History',
    'Buyer Risk Profile',
    'Repeat Customers',
    'Feedback & Claims',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminModuleHub(
      title: 'CUSTOMERS & BUYERS',
      orgId: orgId,
      range: range,
      labels: labels,
    );
  }
}
