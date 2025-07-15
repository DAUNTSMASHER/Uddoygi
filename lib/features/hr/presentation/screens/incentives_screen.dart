import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// ------------------------------------------------------------
/// IncentiveScreen
/// ------------------------------------------------------------
///  * Blue‑white theme for visual consistency
///  * In‑place editing with live total + grand‑total recompute
///  * Three preset bonus rules (Manual / 10% Sales / Task‑Based)
///  * Top‑5 earners bar‑chart for quick insights
///  * Firebase write + read with createdAt stamp (yyyy‑MM‑dd)
/// ------------------------------------------------------------
class IncentiveScreen extends StatefulWidget {
  const IncentiveScreen({super.key});
  @override
  State<IncentiveScreen> createState() => _IncentiveScreenState();
}

class _IncentiveScreenState extends State<IncentiveScreen> {
  /// Local editing rows
  final List<Map<String, dynamic>> _rows = [];

  /// Cached leaderboard
  List<Map<String, dynamic>> _topEarners = [];

  @override
  void initState() {
    super.initState();
    _fetchTopEarners();
  }

  //------------------------------------------------------------------
  // Firebase helpers
  //------------------------------------------------------------------
  Future<void> _fetchTopEarners() async {
    final snap = await FirebaseFirestore.instance
        .collection('incentives')
        .orderBy('total', descending: true)
        .limit(5)
        .get();
    setState(() => _topEarners = snap.docs.map((d) => d.data()).toList());
  }

  Future<void> _saveAll() async {
    if (_rows.isEmpty) return;
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final batch = FirebaseFirestore.instance.batch();

    for (final row in _rows) {
      if (row['name'].toString().trim().isEmpty) continue; // skip blanks
      batch.set(FirebaseFirestore.instance.collection('incentives').doc(), {
        ...row,
        'createdAt': now,
      });
    }

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incentives saved to Firebase ✅')),
    );
    setState(() => _rows.clear());
    _fetchTopEarners();
  }

  //------------------------------------------------------------------
  // Row manipulation
  //------------------------------------------------------------------
  void _addRow() {
    setState(() {
      _rows.add({
        'name': '',
        'designation': '',
        'base': 0.0,
        'bonus': 0.0,
        'other': 0.0,
        'total': 0.0,
        'preset': 'Manual',
      });
    });
  }

  void _deleteRow(int i) => setState(() => _rows.removeAt(i));

  void _update(int idx, String key, String val) {
    final numVal = double.tryParse(val) ?? 0.0;
    setState(() {
      if (key == 'name' || key == 'designation') {
        _rows[idx][key] = val;
      } else {
        _rows[idx][key] = numVal;
        _recalc(idx);
      }
    });
  }

  void _recalc(int i) {
    final r = _rows[i];
    switch (r['preset']) {
      case '10% Sales':
        r['bonus'] = r['base'] * 0.10;
        break;
      case 'Task‑Based':
        r['bonus'] = r['base'] * 300; // base==taskCount
        break;
      default:
      // Manual → bonus already typed by user
        break;
    }
    r['total'] = r['base'] + r['bonus'] + r['other'];
  }

  //------------------------------------------------------------------
  // UI helpers
  //------------------------------------------------------------------
  Widget _field(int i, String k, String label, {bool isText = false}) {
    final init = _rows[i][k].toString();
    return SizedBox(
      width: 130,
      child: TextFormField(
        initialValue: init,
        onChanged: (v) => _update(i, k, v),
        keyboardType: isText
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  double get _grandTotal =>
      _rows.fold<double>(0, (s, r) => s + (r['total'] as double));

  //------------------------------------------------------------------
  // Chart widget
  //------------------------------------------------------------------
  Widget _leaderboard() {
    if (_topEarners.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No incentive data yet')),
      );
    }

    final max = _topEarners.map<double>((e) => (e['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return SizedBox(
        height: 220,
        child: BarChart(
            BarChartData(
                maxY: max * 1.2,
                barGroups: _topEarners.asMap().entries.map((e) {
                  final idx = e.key;
                  final data = e.value;
                  return BarChartGroupData(x: idx, barRods: [
                    BarChartRodData(toY: (data['total'] as num).toDouble(), width: 20, color: Colors.indigo, borderRadius: BorderRadius.circular(6)),
                  ]);