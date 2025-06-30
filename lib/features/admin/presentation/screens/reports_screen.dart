// File: lib/features/admin/presentation/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Monthly Profit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 300, child: ProfitLineChart()),
          const Divider(height: 40),
          const Text('Sales by Marketing Agents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 300, child: SalesBarChart()),
        ],
      ),
    );
  }
}

class ProfitLineChart extends StatelessWidget {
  const ProfitLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) {
            const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
            return Text(labels[value.toInt()]);
          })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        gridData: FlGridData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 5),
              const FlSpot(1, 6.5),
              const FlSpot(2, 5.5),
              const FlSpot(3, 7),
              const FlSpot(4, 6),
              const FlSpot(5, 8),
            ],
            isCurved: true,
            color: Colors.green,
            barWidth: 4,
            belowBarData: BarAreaData(show: false),
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class SalesBarChart extends StatelessWidget {
  const SalesBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, _) {
            const agents = ['A', 'B', 'C', 'D', 'E'];
            return Text(agents[value.toInt()]);
          })),
        ),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 10, color: Colors.blue)]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 12, color: Colors.orange)]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 9, color: Colors.purple)]),
          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 11, color: Colors.teal)]),
          BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 14, color: Colors.red)]),
        ],
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
