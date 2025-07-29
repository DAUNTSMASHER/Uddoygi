import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class IncentiveScreen extends StatefulWidget {
  const IncentiveScreen({super.key});

  @override
  State<IncentiveScreen> createState() => _IncentiveScreenState();
}

class _IncentiveScreenState extends State<IncentiveScreen> {
  final List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _topEarners = [];

  @override
  void initState() {
    super.initState();
    _fetchTopEarners();
  }

  Future<void> _fetchTopEarners() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('incentives')
        .orderBy('total', descending: true)
        .limit(5)
        .get();

    setState(() {
      _topEarners = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

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

  void _deleteRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
  }

  void _updateField(int index, String key, String value) {
    final parsedValue = double.tryParse(value) ?? 0.0;
    setState(() {
      if (key == 'name' || key == 'designation') {
        _rows[index][key] = value;
      } else {
        _rows[index][key] = parsedValue;
        _recalculateRow(index);
      }
    });
  }

  void _recalculateRow(int index) {
    final row = _rows[index];
    // Bonus calculation based on preset type
    if (row['preset'] == '10% Sales') {
      // Bonus = 10% of base salary (assuming base = sales amount here)
      row['bonus'] = row['base'] * 0.10;
    } else if (row['preset'] == 'Task-Based') {
      // Bonus = 300 per task (assuming base = task count)
      row['bonus'] = row['base'] * 300;
    }
    // Total is sum of base, bonus, and other incentives
    row['total'] = row['base'] + row['bonus'] + row['other'];
  }

  Future<void> _saveToFirebase() async {
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final row in _rows) {
      if (row['name'].toString().trim().isEmpty) continue; // Skip empty names
      await FirebaseFirestore.instance.collection('incentives').add({
        ...row,
        'createdAt': now,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incentives saved successfully!')),
    );

    setState(() {
      _rows.clear();
    });

    await _fetchTopEarners();
  }

  Widget _editableTextField(
      int rowIndex, String field, String initialValue, String label, String tooltip) {
    return SizedBox(
      width: 140,
      child: Tooltip(
        message: tooltip,
        child: TextFormField(
          initialValue: initialValue,
          onChanged: (val) => _updateField(rowIndex, field, val),
          keyboardType: field == 'name' || field == 'designation'
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_topEarners.isEmpty) {
      return const Center(
        child: Text(
          'No incentive data yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (_topEarners.map((e) => (e['total'] as num).toDouble()).reduce(
                (a, b) => a > b ? a : b,
          ) *
              1.2)
              .toDouble(),
          barGroups: _topEarners.asMap().entries.map((entry) {
            final index = entry.key;
            final person = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (person['total'] as num).toDouble(),
                  width: 20,
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                  );
                },
                interval: 500,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < _topEarners.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _topEarners[index]['name'].toString().split(' ').first,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.indigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true, horizontalInterval: 500),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  double get _grandTotal =>
      _rows.fold(0, (sum, row) => sum + (row['total'] ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Incentive Calculation'),
        backgroundColor: Colors.indigo.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save all incentives to Firebase',
            onPressed: _rows.isEmpty ? null : _saveToFirebase,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo.shade900,
        icon: const Icon(Icons.add),
        label: const Text('Add Row'),
        onPressed: _addRow,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                elevation: 4,
                shadowColor: Colors.indigo.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Top Earners (by Total Incentives)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBarChart(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shadowColor: Colors.indigo.shade200,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add/Edit Incentive Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                          MaterialStateProperty.all(Colors.indigo.shade100),
                          headingTextStyle: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          dataRowHeight: 60,
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Designation')),
                            DataColumn(label: Text('Base')),
                            DataColumn(label: Text('Bonus')),
                            DataColumn(label: Text('Other')),
                            DataColumn(label: Text('Preset')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: List.generate(_rows.length, (index) {
                            final row = _rows[index];
                            return DataRow(cells: [
                              DataCell(_editableTextField(
                                index,
                                'name',
                                row['name'],
                                'Name',
                                'Employee full name',
                              )),
                              DataCell(_editableTextField(
                                index,
                                'designation',
                                row['designation'],
                                'Designation',
                                'Job title or role',
                              )),
                              DataCell(_editableTextField(
                                index,
                                'base',
                                row['base'].toString(),
                                'Base',
                                'Base salary or sales amount or task count',
                              )),
                              DataCell(_editableTextField(
                                index,
                                'bonus',
                                row['bonus'].toString(),
                                'Bonus',
                                'Bonus amount (auto-calculated or manual)',
                              )),
                              DataCell(_editableTextField(
                                index,
                                'other',
                                row['other'].toString(),
                                'Other',
                                'Other incentives or allowances',
                              )),
                              DataCell(
                                DropdownButton<String>(
                                  value: row['preset'] ?? 'Manual',
                                  items: ['Manual', '10% Sales', 'Task-Based']
                                      .map(
                                        (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      row['preset'] = val!;
                                      _recalculateRow(index);
                                    });
                                  },
                                ),
                              ),
                              DataCell(
                                Text(
                                  row['total'].toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete this row',
                                  onPressed: () => _deleteRow(index),
                                ),
                              ),
                            ]);
                          }),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Grand Total: ${_grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
