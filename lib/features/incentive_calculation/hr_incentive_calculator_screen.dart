import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
const Color _darkBlue = Color(0xFF0D47A1);
class HRIncentiveCalculatorScreen extends StatefulWidget {
  const HRIncentiveCalculatorScreen({super.key});

  @override
  State<HRIncentiveCalculatorScreen> createState() =>
      _HRIncentiveCalculatorScreenState();
}

class _HRIncentiveCalculatorScreenState extends State<HRIncentiveCalculatorScreen> {
  String? _selectedReportId;
  List<DocumentSnapshot> _salesReports = [];
  List<_IncentiveRow> _rows = [];
  final TextEditingController incentiveRateController = TextEditingController(text: '0.15');

  @override
  void initState() {
    super.initState();
    _loadSalesReports();
  }

  Future<void> _loadSalesReports() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('marketing_incentives')
        .get();

    setState(() {
      _salesReports = snapshot.docs
          .where((doc) => doc.id.contains('_sales'))
          .toList();
    });
  }

  void _onReportSelected(String? docId) async {
    if (docId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('marketing_incentives')
        .doc(docId)
        .get();

    final rowsList = (snapshot.data()?['rows'] as List<dynamic>? ?? []).map((row) {
      return _IncentiveRow(
        product: row['productName'] ?? '',
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (row['sellingPrice'] as num?)?.toDouble() ?? 0,
        productCost: (row['purchaseCost'] as num?)?.toDouble() ?? 0,
        fixedCost: (row['fixedCost'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    setState(() {
      _selectedReportId = docId;
      _rows = rowsList;
    });
  }

  Future<void> _submit() async {
    if (_selectedReportId == null) return;

    double incentiveRate = double.tryParse(incentiveRateController.text.trim()) ?? 0.15;
    double totalIncentive = 0;

    final updatedRows = _rows.map((row) {
      final totalPrice = row.quantity * row.unitPrice;
      final prodCost = row.quantity * row.productCost;
      final profit = totalPrice - prodCost;
      final netProfit = profit * ((100 - row.fixedCost) / 100);
      final incentive = netProfit * incentiveRate;
      totalIncentive += incentive;

      return {
        'productName': row.product,
        'quantity': row.quantity,
        'sellingPrice': row.unitPrice,
        'purchaseCost': row.productCost,
        'fixedCost': row.fixedCost,
        'netProfit': netProfit,
        'incentive': incentive,
      };
    }).toList();

    await FirebaseFirestore.instance
        .collection('marketing_incentives')
        .doc(_selectedReportId!)
        .update({
      'rows': updatedRows,
      'totalIncentive': totalIncentive,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Report submitted and incentive calculated")),
    );

    _loadSalesReports();
    _onReportSelected(_selectedReportId);
  }

  @override
  Widget build(BuildContext context) {
    double incentiveRate = double.tryParse(incentiveRateController.text.trim()) ?? 0.15;

    double totalSales = 0;
    double totalIncentive = 0;

    for (var row in _rows) {
      final totalPrice = row.quantity * row.unitPrice;
      final productionCost = row.quantity * row.productCost;
      final profit = totalPrice - productionCost;
      final netProfit = profit * ((100 - row.fixedCost) / 100);
      final incentive = netProfit * incentiveRate;
      totalSales += totalPrice;
      totalIncentive += incentive;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(('Incentive Calculator') , style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: incentiveRateController,
                  decoration: const InputDecoration(labelText: 'Incentive Rate (e.g. 0.15)'),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Select Sales Report',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontSize: 12)),
              value: _selectedReportId,
              items: _salesReports.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final incentive = data['totalIncentive'];
                final labelColor = incentive == null ? Colors.black : Colors.green;
                final label = incentive == null
                    ? "${doc.id} (Pending)"
                    : "${doc.id} (৳${incentive.toStringAsFixed(0)})";

                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
                );
              }).toList(),
              onChanged: _onReportSelected,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text("No data found"))
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowColor: MaterialStateProperty.all(Colors.blue),
                    dataTextStyle: const TextStyle(fontSize: 10),
                    headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Unit Price')),
                      DataColumn(label: Text('Total Price')),
                      DataColumn(label: Text('Unit Cost')),
                      DataColumn(label: Text('Prod. Cost')),
                      DataColumn(label: Text('Profit')),
                      DataColumn(label: Text('Fixed Cost %')),
                      DataColumn(label: Text('Net Profit')),
                      DataColumn(label: Text('Incentive')),
                    ],
                    rows: _rows.map((row) {
                      final totalPrice = row.quantity * row.unitPrice;
                      final prodCost = row.quantity * row.productCost;
                      final profit = totalPrice - prodCost;
                      final netProfit = profit * ((100 - row.fixedCost) / 100);
                      final incentive = netProfit * incentiveRate;

                      return DataRow(cells: [
                        DataCell(Text(row.product)),
                        DataCell(TextFormField(
                          initialValue: row.quantity.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() =>
                          row.quantity = int.tryParse(val) ?? 0),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          style: const TextStyle(fontSize: 10),
                        )),
                        DataCell(TextFormField(
                          initialValue: row.unitPrice.toStringAsFixed(2),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() =>
                          row.unitPrice = double.tryParse(val) ?? 0),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          style: const TextStyle(fontSize: 10),
                        )),
                        DataCell(Text(totalPrice.toStringAsFixed(2))),
                        DataCell(TextFormField(
                          initialValue: row.productCost.toStringAsFixed(2),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() =>
                          row.productCost = double.tryParse(val) ?? 0),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          style: const TextStyle(fontSize: 10),
                        )),
                        DataCell(Text(prodCost.toStringAsFixed(2))),
                        DataCell(Text(profit.toStringAsFixed(2))),
                        DataCell(TextFormField(
                          initialValue: row.fixedCost.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => setState(() =>
                          row.fixedCost = double.tryParse(val) ?? 0),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          style: const TextStyle(fontSize: 10),
                        )),
                        DataCell(Text(netProfit.toStringAsFixed(2))),
                        DataCell(Text(incentive.toStringAsFixed(2))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🔢 Total Sales: ৳${totalSales.toStringAsFixed(2)}'),
                Text('💸 Total Incentive: ৳${totalIncentive.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}

class _IncentiveRow {
  final String product;
  int quantity;
  double unitPrice;
  double productCost;
  double fixedCost;

  _IncentiveRow({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.productCost,
    required this.fixedCost,
  });
}
