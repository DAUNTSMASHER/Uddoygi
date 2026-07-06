import 'package:flutter/material.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminNetProfitabilityScreen extends StatefulWidget {
  const AdminNetProfitabilityScreen({super.key});

  @override
  State<AdminNetProfitabilityScreen> createState() => _AdminNetProfitabilityScreenState();
}

class _AdminNetProfitabilityScreenState extends State<AdminNetProfitabilityScreen> {
  double _totalRevenue = 0;
  double _laborCosts = 0;
  double _productionCosts = 0;
  double _marketingSpend = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (id == null) return;

    // Aggregate Data
    final results = await Future.wait([
      _firestore.collection('companies').doc(id).collection('invoices').get(),
      _firestore.collection('companies').doc(id).collection('salaries').get(),
      _firestore.collection('companies').doc(id).collection('expenses').get(),
    ]);

    double revenue = 0;
    for (var doc in results[0].docs) revenue += (doc.data()['grandTotal'] ?? 0).toDouble();

    double labor = 0;
    for (var doc in results[1].docs) labor += (doc.data()['totalSalary'] ?? 0).toDouble();

    double prod = 0;
    double marketing = 0;
    for (var doc in results[2].docs) {
      final data = doc.data();
      final cat = data['category'] ?? '';
      final amt = (data['amount'] ?? 0).toDouble();
      if (cat == 'Marketing' || cat == 'Ad Spend') marketing += amt;
      else if (cat == 'Procurement' || cat == 'Factory') prod += amt;
    }

    if (mounted) {
      setState(() {
        _totalRevenue = revenue;
        _laborCosts = labor;
        _productionCosts = prod;
        _marketingSpend = marketing;
        _isLoading = false;
      });
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final netProfit = _totalRevenue - (_laborCosts + _productionCosts + _marketingSpend);
    final profitMargin = _totalRevenue > 0 ? (netProfit / _totalRevenue) * 100 : 0.0;

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Net Profitability', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfitHero(netProfit, profitMargin),
            const SizedBox(height: UddoygiDesign.space32),
            Text('Profit & Loss Breakdown', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: UddoygiDesign.space16),
            _buildStatCard('Total Revenue', _totalRevenue, Colors.green, Icons.trending_up_rounded),
            _buildStatCard('Labor Costs', _laborCosts, Colors.orange, Icons.people_rounded),
            _buildStatCard('Production Costs', _productionCosts, Colors.blue, Icons.factory_rounded),
            _buildStatCard('Marketing Spend', _marketingSpend, Colors.purple, Icons.campaign_rounded),
            const SizedBox(height: UddoygiDesign.space32),
            _buildProfitAnalysisChart(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitHero(double netProfit, double margin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UddoygiDesign.space24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0040), Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusXL),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E0040).withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ESTIMATED NET PROFIT',
            style: AppFonts.banglaBody(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: UddoygiDesign.space12),
          Text(
            '৳${NumberFormat('#,##,###').format(netProfit)}',
            style: AppFonts.banglaBody(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: UddoygiDesign.space16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: UddoygiDesign.borderFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_graph_rounded, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${margin.toStringAsFixed(1)}% Margin',
            style: AppFonts.banglaData(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  Widget _buildStatCard(String label, double value, Color color, IconData icon) {
    return UCard(
      margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: UddoygiDesign.space16),
          Expanded(
            child: Text(
              label,
              style: AppFonts.banglaBody(
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '৳${NumberFormat('#,##,###').format(value)}',
            style: AppFonts.banglaBody(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: const Color(0xFF1E0040),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
  }

  Widget _buildProfitAnalysisChart() {
    return UCard(
      padding: const EdgeInsets.all(UddoygiDesign.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cost Allocation',
            style: AppFonts.banglaBody(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: const Color(0xFF1E0040),
            ),
          ),
          const SizedBox(height: UddoygiDesign.space24),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: _laborCosts,
                    color: Colors.orange,
                    title: 'Labor',
                    radius: 50,
                    titleStyle: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: _productionCosts,
                    color: Colors.blue,
                    title: 'Prod',
                    radius: 50,
                    titleStyle: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: _marketingSpend,
                    color: Colors.purple,
                    title: 'Mark',
                    radius: 50,
                    titleStyle: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: _totalRevenue - (_laborCosts + _productionCosts + _marketingSpend),
                    color: Colors.green,
                    title: 'Profit',
                    radius: 60,
                    titleStyle: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: UddoygiDesign.space24),
          _buildChartLegend(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.02, end: 0);
  }

  Widget _buildChartLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem('Labor', Colors.orange),
        _legendItem('Production', Colors.blue),
        _legendItem('Marketing', Colors.purple),
        _legendItem('Profit', Colors.green),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      ],
    );
  }
}
