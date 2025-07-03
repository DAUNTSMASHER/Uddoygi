import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';
import 'order_progress_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  double salesTarget = 100000;
  int orderCount = 0;
  double totalSales = 0;
  String? userEmail;
  bool targetReached = false;
  DateTime selectedMonth = DateTime.now();
  bool showSummary = true;
  bool showPie = false;

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
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final snapshot = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    double total = 0;
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('grandTotal')) {
        total += (data['grandTotal'] as num).toDouble();
      }
      count++;
    }

    if (mounted) {
      setState(() {
        totalSales = total;
        orderCount = count;
        targetReached = totalSales >= salesTarget;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2025, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          primaryColor: Colors.indigo,
          colorScheme: const ColorScheme.light(primary: Colors.indigo),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != selectedMonth) {
      setState(() {
        selectedMonth = picked;
      });
      await _calculateUserSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = (totalSales / salesTarget * 100).clamp(0, 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Dashboard'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectMonth(context),
            tooltip: 'Filter by Month',
          )
        ],
      ),
      body: userEmail == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month info and filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Month: ${DateFormat.yMMMM().format(selectedMonth)}",
                  style: const TextStyle(fontSize: 16, color: Colors.indigo, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _selectMonth(context),
                  icon: const Icon(Icons.filter_alt, color: Colors.blueAccent),
                  label: const Text('Change', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            ),

            // Target reached banner
            if (targetReached)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16, top: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.emoji_events, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(child: Text("🎉 Congratulations! You've hit your monthly sales target!")),
                  ],
                ),
              ),

            // Minimize/Expand summary stats
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => showSummary = !showSummary),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Summary",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.indigo),
                  ),
                  Icon(
                    showSummary ? Icons.expand_less : Icons.expand_more,
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard('🎯 Sales Target', '৳${salesTarget.toStringAsFixed(0)}'),
                    _buildStatCard('💰 Total Sales', '৳${totalSales.toStringAsFixed(0)}'),
                    _buildStatCard('📦 Total Orders', '$orderCount'),
                    _buildStatCard('📈 Achievement', '${achievement.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: showSummary ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),

            // Pie chart minimize/expand
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => showPie = !showPie),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Sales Achievement",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.indigo),
                  ),
                  Icon(
                    showPie ? Icons.expand_less : Icons.expand_more,
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: achievement.toDouble(),
                          color: Colors.indigo,
                          title: '${achievement.toStringAsFixed(1)}%',
                          titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: (100 - achievement).toDouble(),
                          color: Colors.grey.shade300,
                          title: '',
                          radius: 50,
                        ),
                      ],
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: showPie ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),

            const Divider(),

            const Text('Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 12),

            // Actions as grid
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              children: [
                _buildActionTile(
                  context,
                  icon: Icons.add_circle,
                  color: Colors.green,
                  text: '🆕 New Invoice',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen())),
                ),
                _buildActionTile(
                  context,
                  icon: Icons.list_alt,
                  color: Colors.blue,
                  text: '📄 All Invoices',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen())),
                ),
                _buildActionTile(
                  context,
                  icon: Icons.bar_chart,
                  color: Colors.orange,
                  text: '📊 Sales Report',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen())),
                ),
                _buildActionTile(
                  context,
                  icon: Icons.timeline,
                  color: Colors.deepPurple,
                  text: '📦 Order Progress',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderProgressScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.indigo)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, {required IconData icon, required Color color, required String text, required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
