import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/admin_allbuyer.dart';

class AdminDashboardSummary extends StatefulWidget {
  const AdminDashboardSummary({super.key});

  @override
  State<AdminDashboardSummary> createState() => _AdminDashboardSummaryState();
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;

  const _ReportTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardSummaryState extends State<AdminDashboardSummary> {
  bool isLoading = true;
  double totalSales = 0;
  int totalBuyers = 0;
  double budget = 0;
  double totalExpenses = 0;
  String filterType = 'month';
  Map<String, double> agentSales = {};

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  Future<void> fetchReportData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();

      final startDate = filterType == 'month'
          ? DateTime(now.year, now.month, 1)
          : DateTime(now.year, 1, 1);
      final endDate = filterType == 'month'
          ? DateTime(now.year, now.month + 1, 0)
          : DateTime(now.year, 12, 31);

      final invoicesSnap = await firestore
          .collection('invoices')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final buyersSnap = await firestore.collection('customers').get();
      final budgetSnap = await firestore.collection('budget').limit(1).get();
      final expensesSnap = await firestore.collection('expenses').get();

      double sales = 0;
      Map<String, double> salesByAgent = {};

      for (var doc in invoicesSnap.docs) {
        final agentEmail = doc.data()['agentEmail'] ?? 'Unknown';
        final val = doc.data()['grandTotal'];
        double sale = (val is num) ? val.toDouble() : 0;
        sales += sale;
        salesByAgent[agentEmail] = (salesByAgent[agentEmail] ?? 0) + sale;
      }

      double expense = 0;
      for (var doc in expensesSnap.docs) {
        final val = doc.data()['amount'];
        if (val is num) expense += val.toDouble();
      }

      setState(() {
        totalSales = sales;
        totalBuyers = buyersSnap.docs.length;
        budget = budgetSnap.docs.isNotEmpty
            ? ((budgetSnap.docs.first.data()['amount'] ?? 0) as num).toDouble()
            : 0;
        totalExpenses = expense;
        agentSales = salesByAgent;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void navigateToAllBuyersPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminAllBuyersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double percent = budget > 0 ? (totalSales / budget) * 100 : 0;
    final double safePercent = percent.clamp(0, 100);

    // Find top agent by sales
    String topAgentEmail = '';
    double topAgentSales = 0;
    if (agentSales.isNotEmpty) {
      final sorted = agentSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topAgentEmail = sorted.first.key;
      topAgentSales = sorted.first.value;
    }

    final tiles = [
      _ReportTile(
        title: 'Total Sales',
        value: '৳${totalSales.toStringAsFixed(0)}',
        icon: Icons.shopping_cart,
        iconColor: Colors.white,
        gradientColors: [Colors.indigo, Colors.blueAccent],
      ),
      GestureDetector(
        onTap: navigateToAllBuyersPage,
        child: _ReportTile(
          title: 'Total Buyers',
          value: '$totalBuyers',
          icon: Icons.person_outline,
          iconColor: Colors.white,
          gradientColors: [Colors.deepPurple, Colors.purpleAccent],
        ),
      ),
      _ReportTile(
        title: 'Budget',
        value: '৳${budget.toStringAsFixed(0)}',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: Colors.white,
        gradientColors: [Colors.orange, Colors.deepOrange],
      ),
      _ReportTile(
        title: 'Expenses',
        value: '৳${totalExpenses.toStringAsFixed(0)}',
        icon: Icons.receipt_long,
        iconColor: Colors.white,
        gradientColors: [Colors.redAccent, Colors.red],
      ),
      // Pie Chart
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.green, Colors.teal]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Sales vs Budget Achievement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  startDegreeOffset: 180,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    PieChartSectionData(
                      value: safePercent,
                      color: Colors.indigo,
                      title: '${safePercent.toStringAsFixed(1)}%',
                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 50,
                      showTitle: true,
                      titlePositionPercentageOffset: 0.6,
                    ),
                    PieChartSectionData(
                      value: 100 - safePercent,
                      color: Colors.grey.shade300,
                      title: '',
                      radius: 40,
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
              ),
            ),
          ],
        ),
      ),
      // Top Sales Agent
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.cyan, Colors.teal]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performing Agent (Highest Sales)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            topAgentEmail.isEmpty
                ? const Text(
              'No sales data available',
              style: TextStyle(fontSize: 14, color: Colors.white),
            )
                : Text(
              '$topAgentEmail\n৳${topAgentSales.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<String>(
                value: filterType,
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'year', child: Text('This Year')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => filterType = value);
                    fetchReportData();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 340,
            child: CarouselSlider(
              items: tiles.map((tile) => Builder(
                builder: (context) => SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: tile,
                ),
              )).toList(),
              options: CarouselOptions(
                height: 300,
                autoPlay: true,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                autoPlayInterval: const Duration(seconds: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
