// lib/features/marketing/presentation/screens/work_order_screen.dart

import 'package:flutter/material.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_wo.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/add_new_po.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/incoming_products.dart';
import 'package:uddoygi/features/marketing/presentation/work_order/qc_report.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class WorkOrderScreen extends StatelessWidget {
  const WorkOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Work Orders'),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildTile(
              context,
              icon: Icons.add_box,
              label: 'Add New Work Order',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddNewWorkOrderScreen(),
                ),
              ),
            ),
            _buildTile(
              context,
              icon: Icons.playlist_add,
              label: 'Add New Purchase Order',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddNewPurchaseOrderScreen(),
                ),
              ),
            ),
            _buildTile(
              context,
              icon: Icons.inbox,
              label: 'Incoming Products',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IncomingProductsScreen(),
                ),
              ),
            ),
            _buildTile(
              context,
              icon: Icons.check_circle,
              label: 'QC Report',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QCReportScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return Material(
      color: _darkBlue.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _darkBlue, size: 36),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _darkBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
