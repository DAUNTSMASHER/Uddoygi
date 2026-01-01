import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReportDetailPage extends StatefulWidget {
  final String? orgId;
  final DateTimeRange range;
  final String headTitle;
  final String label;

  const AdminReportDetailPage({
    super.key,
    required this.orgId,
    required this.range,
    required this.headTitle,
    required this.label,
  });

  @override
  State<AdminReportDetailPage> createState() => _AdminReportDetailPageState();
}

class _AdminReportDetailPageState extends State<AdminReportDetailPage> {
  static const _p1 = Color(0xFF2E1065);
  static const _p2 = Color(0xFF5B21B6);
  static const _p3 = Color(0xFF7C3AED);
  static const _bg = Color(0xFFF7F7FB);
  static const _border = Color(0xFFE7E9F3);
  static const _text = Color(0xFF0F172A);
  static const _text2 = Color(0xFF64748B);

  final _fmt = NumberFormat.decimalPattern('en_BD');

  CollectionReference<Map<String, dynamic>> _col(String name) {
    final db = FirebaseFirestore.instance;
    if (widget.orgId == null || widget.orgId!.trim().isEmpty) return db.collection(name);
    return db.collection('orgs').doc(widget.orgId).collection(name);
  }

  // NOTE: Generic example stream (you can map each label to its collection later).
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    // Default to invoices as a safe base (you can switch per label later)
    return _col('invoices').orderBy('createdAt', descending: true).limit(80).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        title: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w900)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_p1, _p2, _p3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          // simple numeric + chart demo
          var values = <double>[];
          for (int i = 0; i < math.min(docs.length, 12); i++) {
            final m = docs[i].data();
            final v = (m['grandTotal'] ?? m['total'] ?? m['amount'] ?? 0);
            values.add(v is num ? v.toDouble() : 0.0);
          }
          values = values.reversed.toList();


          final maxY = values.isEmpty ? 10.0 : values.reduce(math.max) * 1.15;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.headTitle, style: const TextStyle(fontWeight: FontWeight.w900, color: _text)),
                    const SizedBox(height: 2),
                    Text(
                      'Report: ${widget.label}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _text2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Showing latest data (connect exact logic per label later).',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: _text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Chart
              Container(
                height: 220,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: values.isEmpty
                    ? const Center(child: Text('No chart data', style: TextStyle(color: _text2)))
                    : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (values.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
                        ],
                        isCurved: true,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        color: _p2,
                        belowBarData: BarAreaData(show: true, color: _p2.withOpacity(.08)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Table / List
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Entries', style: TextStyle(fontWeight: FontWeight.w900, color: _text)),
                    const SizedBox(height: 10),
                    if (docs.isEmpty)
                      const Text('No records found.', style: TextStyle(color: _text2, fontWeight: FontWeight.w700))
                    else
                      ...docs.take(12).map((d) {
                        final m = d.data();
                        final title = (m['customerName'] ?? m['buyerName'] ?? m['name'] ?? 'Record').toString();
                        final amount = (m['grandTotal'] ?? m['total'] ?? m['amount'] ?? 0);
                        final a = amount is num ? amount.toDouble() : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: _text),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '৳ ${_fmt.format(a.round())}',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: _text),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
