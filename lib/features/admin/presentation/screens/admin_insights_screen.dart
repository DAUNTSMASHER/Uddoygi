import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminInsightsScreen extends StatefulWidget {
  const AdminInsightsScreen({super.key});

  @override
  State<AdminInsightsScreen> createState() => _AdminInsightsScreenState();
}

class _AdminInsightsScreenState extends State<AdminInsightsScreen> {
  String _cid = '';
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadCid();
  }

  Future<void> _loadCid() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Business Insights', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DB.colSync(_cid, C.invoices).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          final stats = _calculateInsights(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(stats),
                const SizedBox(height: 24),
                _buildRevenueGauge(stats),
                const SizedBox(height: 24),
                _buildMarketGrowth(stats),
                const SizedBox(height: 24),
                _buildTopProducts(stats),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(_InsightStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard('Revenue (MoM)', '৳${stats.monthlyRevenue.toStringAsFixed(0)}', Icons.trending_up, stats.growth >= 0 ? Colors.green : Colors.red),
        _buildStatCard('Growth Rate', '${stats.growth.toStringAsFixed(1)}%', Icons.show_chart, Colors.blue),
        _buildStatCard('Conversion', '${stats.conversionRate.toStringAsFixed(1)}%', Icons.transform, Colors.orange),
        _buildStatCard('Active Deals', '${stats.activeDeals}', Icons.handshake, Colors.indigo),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
              Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildRevenueGauge(_InsightStats stats) {
    final percent = (stats.monthlyRevenue / stats.monthlyTarget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Revenue vs Target', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${(percent * 100).toStringAsFixed(0)}%', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 20,
                  backgroundColor: Colors.grey[100],
                  color: const Color(0xFF2563EB),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('৳${stats.monthlyRevenue.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('of ৳${stats.monthlyTarget.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketGrowth(_InsightStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Market Growth (MoM)', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: stats.growthSpots,
                    isCurved: true,
                    color: const Color(0xFF2563EB),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF2563EB).withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(_InsightStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top 5 Products', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
          child: Column(
            children: stats.topProducts.map((p) => ListTile(
              title: Text(p.name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: Text('৳${p.revenue.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
            )).toList(),
          ),
        ),
      ],
    );
  }

  _InsightStats _calculateInsights(List<QueryDocumentSnapshot> docs) {
    double currentMonthRevenue = 0;
    double lastMonthRevenue = 0;
    Map<String, double> productRev = {};

    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final revenue = (data['grandTotal'] as num?)?.toDouble() ?? 0;
      final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      if (ts.isAfter(firstOfThisMonth)) {
        currentMonthRevenue += revenue;
      } else if (ts.isAfter(firstOfLastMonth) && ts.isBefore(firstOfThisMonth)) {
        lastMonthRevenue += revenue;
      }

      final items = (data['items'] as List?) ?? [];
      for (var it in items) {
        final name = it['model'] ?? 'Unknown';
        final rev = (it['price'] as num?)?.toDouble() ?? 0;
        final qty = (it['qty'] as num?)?.toInt() ?? 0;
        productRev[name] = (productRev[name] ?? 0) + (rev * qty);
      }
    }

    final growth = lastMonthRevenue == 0 ? 100.0 : ((currentMonthRevenue - lastMonthRevenue) / lastMonthRevenue * 100);
    
    final sortedProducts = productRev.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedProducts.take(5).map((e) => _ProductRevenue(e.key, e.value)).toList();

    return _InsightStats(
      monthlyRevenue: currentMonthRevenue,
      monthlyTarget: 1000000, // Placeholder target
      growth: growth,
      conversionRate: 65.4, // Placeholder conversion
      activeDeals: docs.length,
      topProducts: top5,
      growthSpots: [const FlSpot(0, 1), const FlSpot(1, 2), const FlSpot(2, 1.5), const FlSpot(3, 3), const FlSpot(4, 2.5), const FlSpot(5, 4)],
    );
  }
}

class _InsightStats {
  final double monthlyRevenue;
  final double monthlyTarget;
  final double growth;
  final double conversionRate;
  final int activeDeals;
  final List<_ProductRevenue> topProducts;
  final List<FlSpot> growthSpots;

  _InsightStats({
    required this.monthlyRevenue,
    required this.monthlyTarget,
    required this.growth,
    required this.conversionRate,
    required this.activeDeals,
    required this.topProducts,
    required this.growthSpots,
  });
}

class _ProductRevenue {
  final String name;
  final double revenue;
  _ProductRevenue(this.name, this.revenue);
}
