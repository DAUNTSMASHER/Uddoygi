// lib/features/marketing/presentation/screens/sales_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';
import 'order_progress_screen.dart';
import 'work_order_screen.dart'; // ← import your work order screen

const Color _darkBlue = Color(0xFF0D47A1);

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  static const double _fontSmall   = 12;
  static const double _fontRegular = 14;
  static const double _fontLarge   = 16;

  double salesTarget   = 100000;
  int    orderCount    = 0;
  double totalSales    = 0;
  String? userEmail;
  bool   targetReached = false;
  DateTime selectedMonth = DateTime.now();
  bool showSummary = true;
  bool showPie     = false;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      userEmail = session['email'];
      await _calculateUserSales();
    }
  }

  Future<void> _calculateUserSales() async {
    if (userEmail == null) return;
    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final end   = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double total = 0;
    for (var doc in snap.docs) {
      total += (doc.data()['grandTotal'] as num? ?? 0).toDouble();
    }

    if (mounted) {
      setState(() {
        totalSales    = total;
        orderCount    = snap.docs.length;
        targetReached = totalSales >= salesTarget;
      });
    }
  }

  Future<void> _selectMonth(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: selectedMonth,
      firstDate: DateTime(2025, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (c, w) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _darkBlue),
        ),
        child: w!,
      ),
    );
    if (picked != null && picked != selectedMonth) {
      setState(() => selectedMonth = picked);
      await _calculateUserSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double achievement =
    (totalSales / salesTarget * 100).clamp(0.0, 100.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sales Dashboard', style: TextStyle(fontSize: _fontLarge)),
        backgroundColor: _darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectMonth(context),
          )
        ],
      ),
      body: userEmail == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMM().format(selectedMonth),
                  style: const TextStyle(
                      fontSize: _fontRegular,
                      fontWeight: FontWeight.bold,
                      color: _darkBlue),
                ),
                TextButton.icon(
                  onPressed: () => _selectMonth(context),
                  icon: const Icon(Icons.filter_alt, color: _darkBlue),
                  label: const Text('Filter', style: TextStyle(color: _darkBlue)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target banner
            if (targetReached)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _darkBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.emoji_events, color: _darkBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "🎉 You've hit your monthly sales target!",
                        style: TextStyle(
                            fontSize: _fontSmall,
                            color: _darkBlue,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Summary section
            _sectionHeader('Summary', showSummary, () {
              setState(() => showSummary = !showSummary);
            }),
            if (showSummary)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2,
                  children: [
                    _buildStatCard('Target', '৳${salesTarget.toStringAsFixed(0)}'),
                    _buildStatCard('Sales', '৳${totalSales.toStringAsFixed(0)}'),
                    _buildStatCard('Orders', '$orderCount'),
                    _buildStatCard('Achieved', '${achievement.toStringAsFixed(1)}%'),
                  ],
                ),
              ),

            // Pie chart section
            _sectionHeader('Achievement Chart', showPie, () {
              setState(() => showPie = !showPie);
            }),
            if (showPie)
              SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    sections: [
                      PieChartSectionData(
                        value: achievement,
                        color: _darkBlue,
                        title: '${achievement.toStringAsFixed(1)}%',
                        radius: 60,
                        titleStyle: const TextStyle(
                            fontSize: _fontRegular,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: 100 - achievement,
                        color: Colors.grey.shade300,
                        title: '',
                        radius: 50,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            const Divider(thickness: 1),
            const SizedBox(height: 16),

            // Actions header
            Text('Actions',
                style: const TextStyle(
                    fontSize: _fontLarge,
                    color: _darkBlue,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 3-column grid of actions
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildActionTile(Icons.add_circle, 'New Invoice', _darkBlue, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewInvoicesScreen()),
                  );
                }),
                _buildActionTile(Icons.list_alt, 'All Invoices', _darkBlue, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllInvoicesScreen()),
                  );
                }),
                _buildActionTile(Icons.work, 'Work Orders', _darkBlue, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkOrderScreen()),
                  );
                }),
                _buildActionTile(Icons.bar_chart, 'Report', _darkBlue, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SalesReportScreen()),
                  );
                }),
                _buildActionTile(Icons.timeline, 'Progress', _darkBlue, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrderProgressScreen()),
                  );
                }),
                const SizedBox(), // fill out grid
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: _fontRegular,
                  fontWeight: FontWeight.bold,
                  color: _darkBlue)),
          Icon(expanded ? Icons.expand_less : Icons.expand_more,
              color: _darkBlue),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: _fontSmall, color: _darkBlue)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: _fontLarge,
                  fontWeight: FontWeight.bold,
                  color: _darkBlue)),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontSize: _fontRegular, color: color)),
          ],
        ),
      ),
    );
  }
}
