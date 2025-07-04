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
    if (row['preset'] == '10% Sales') {
      row['bonus'] = row['base'] * 0.1;
    } else if (row['preset'] == 'Task-Based') {
      row['bonus'] = row['base'] * 300; // base = task count
    }
    row['total'] = row['base'] + row['bonus'] + row['other'];
  }

  Future<void> _saveToFirebase() async {
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final row in _rows) {
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

  Widget _editableTextField(int rowIndex, String field, String initialValue) {
    return SizedBox(
      width: 100,
      child: TextFormField(
        initialValue: initialValue,
        onChanged: (val) => _updateField(rowIndex, field, val),
        keyboardType: field == 'name' || field == 'designation'
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_topEarners.isEmpty) {
      return const Center(child: Text('No incentive data yet.'));
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: _topEarners.asMap().entries.map((entry) {
            final index = entry.key;
            final person = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (person['total'] as num).toDouble(),
                  width: 18,
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incentive Calculation'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveToFirebase),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Row'),
        onPressed: _addRow,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Top Earners (by Total)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildBarChart(),
            ),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
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
                    DataCell(_editableTextField(index, 'name', row['name'])),
                    DataCell(_editableTextField(index, 'designation', row['designation'])),
                    DataCell(_editableTextField(index, 'base', row['base'].toString())),
                    DataCell(_editableTextField(index, 'bonus', row['bonus'].toString())),
                    DataCell(_editableTextField(index, 'other', row['other'].toString())),
                    DataCell(
                      DropdownButton<String>(
                        value: row['preset'] ?? 'Manual',
                        items: ['Manual', '10% Sales', 'Task-Based']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            row['preset'] = val!;
                            _recalculateRow(index);
                          });
                        },
                      ),
                    ),
                    DataCell(Text(row['total'].toStringAsFixed(2))),
                    DataCell(IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRow(index),
                    )),
                  ]);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
