import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';

class BudgetForecastScreen extends StatefulWidget {
  const BudgetForecastScreen({super.key});

  @override
  State<BudgetForecastScreen> createState() => _BudgetForecastScreenState();
}

class _BudgetForecastScreenState extends State<BudgetForecastScreen> {
  int selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Budget Forecast', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportForecastPdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Year Filter Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Year:', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButton<int>(
                  value: selectedYear,
                  items: List.generate(5, (i) => DateTime.now().year - i)
                      .map((year) => DropdownMenuItem(value: year, child: Text('$year')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedYear = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Forecast List with Summary and Chart
            Expanded(child: _buildForecastList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Forecast'),
        onPressed: _showAddForecastForm,
      ),
    );
  }

  Widget _buildForecastList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('budget')
          .where('year', isEqualTo: selectedYear)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Error loading data');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        double totalForecast = 0;
        double totalUsed = 0;

        final items = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num).toDouble();
          final used = (data['used'] as num?)?.toDouble() ?? 0;

          totalForecast += amount;
          totalUsed += used;

          return {
            'id': doc.id,
            'category': data['category'],
            'amount': amount,
            'used': used,
          };
        }).toList();

        return Column(
          children: [
            _summaryCard('Forecasted', totalForecast),
            _summaryCard('Used', totalUsed),
            const SizedBox(height: 10),
            SizedBox(height: 200, child: _buildBarChart(items)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(item['category']),
                      subtitle: Text('Forecast: ৳${item['amount']}'),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Used: ৳${item['used']}', style: const TextStyle(color: Colors.indigo)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                onPressed: () => _showEditForm(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => FirebaseFirestore.instance
                                    .collection('budget')
                                    .doc(item['id'])
                                    .delete(),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, double value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$title: ৳ ${value.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> items) {
    return BarChart(
      BarChartData(
        barGroups: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: item['amount'], width: 8, color: Colors.indigo),
            BarChartRodData(toY: item['used'], width: 8, color: Colors.blueAccent),
          ]);
        }).toList(),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  void _showAddForecastForm() {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Forecast Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Forecast Amount'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: () async {
                  final category = categoryController.text.trim();
                  final amount = double.tryParse(amountController.text.trim()) ?? 0;
                  if (category.isEmpty || amount <= 0) return;

                  await FirebaseFirestore.instance.collection('budget').add({
                    'category': category,
                    'amount': amount,
                    'used': 0,
                    'year': selectedYear,
                    'date': DateTime.now(),
                  });

                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditForm(Map item) {
    final amountController = TextEditingController(text: item['amount'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Forecast Amount'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text.trim()) ?? 0;
              await FirebaseFirestore.instance.collection('budget').doc(item['id']).update({
                'amount': newAmount,
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportForecastPdf() async {
    final query = await FirebaseFirestore.instance
        .collection('budget')
        .where('year', isEqualTo: selectedYear)
        .get();

    final pdf = pw.Document();
    final logs = query.docs;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Budget Forecast Report - $selectedYear',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Category', 'Forecast', 'Used'],
            data: logs.map((doc) {
              final data = doc.data();
              return [
                data['category'] ?? '',
                '৳ ${data['amount']}',
                '৳ ${data['used'] ?? 0}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            border: pw.TableBorder.all(color: PdfColors.grey),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
