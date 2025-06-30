import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminReportsWithGraphsScreen extends StatefulWidget {
  const AdminReportsWithGraphsScreen({super.key});

  @override
  State<AdminReportsWithGraphsScreen> createState() => _AdminReportsWithGraphsScreenState();
}

class _AdminReportsWithGraphsScreenState extends State<AdminReportsWithGraphsScreen> {
  List<SalesPerformance> salesData = [];
  List<WorkPerformance> workPerformanceData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final salesSnapshot = await FirebaseFirestore.instance.collection('sales_reports').get();
      final workSnapshot = await FirebaseFirestore.instance.collection('worker_performance').get();

      final sales = salesSnapshot.docs.map((doc) {
        final data = doc.data();
        return SalesPerformance(
          month: data['month'] ?? '',
          sales: data['sales'] ?? 0,
        );
      }).toList();

      final work = workSnapshot.docs.map((doc) {
        final data = doc.data();
        return WorkPerformance(
          worker: data['name'] ?? '',
          score: data['score'] ?? 0,
        );
      }).toList();

      setState(() {
        salesData = sales;
        workPerformanceData = work;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Sales Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: salesData.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(x: idx, barRods: [
                      BarChartRodData(toY: data.sales.toDouble(), color: Colors.blue)
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          return Text(
                            idx < salesData.length ? salesData[idx].month : '',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Worker Performance (Pie Chart)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: workPerformanceData.map((e) {
                    final index = workPerformanceData.indexOf(e);
                    final colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple];
                    return PieChartSectionData(
                      value: e.score.toDouble(),
                      title: e.worker,
                      color: colors[index % colors.length],
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SalesPerformance {
  final String month;
  final int sales;
  SalesPerformance({required this.month, required this.sales});
}

class WorkPerformance {
  final String worker;
  final int score;
  WorkPerformance({required this.worker, required this.score});
}