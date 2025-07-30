import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  String? _selectedMonth;
  double totalSales = 0;
  double totalShipping = 0;
  double netSales = 0;
  int totalPieces = 0;
  double salesTarget = 100000;
  bool isSubmitted = false;

  String get _agentEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  List<String> get months =>
      List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1)));

  @override
  void initState() {
    super.initState();
    _fetchTarget();
  }

  Future<void> _fetchTarget() async {
    final snap = await FirebaseFirestore.instance
        .collection('targets')
        .doc(_agentEmail)
        .get();

    if (snap.exists) {
      final value = snap.data()?['monthlyTarget'];
      if (value != null && value is num) {
        setState(() => salesTarget = value.toDouble());
      }
    }
  }

  DateTime getMonthStart() {
    final index = months.indexOf(_selectedMonth!) + 1;
    return DateTime(DateTime.now().year, index, 1);
  }

  DateTime getMonthEnd() {
    final start = getMonthStart();
    return DateTime(start.year, start.month + 1);
  }

  void _updateStatus(DocumentReference ref, String newStatus) {
    if (!isSubmitted) {
      ref.update({'paymentStatus': newStatus});
    }
  }

  Future<void> _submitReport() async {
    final now = DateTime.now();
    final year = now.year;
    final docId = "${_agentEmail}_$_selectedMonth\_$year\_sales";

    final achievedPercent =
    ((netSales / salesTarget) * 100).clamp(0, 999).toStringAsFixed(2);

    final invoiceSnapshot = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: _agentEmail)
        .where('timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(getMonthStart()))
        .where('timestamp', isLessThan: Timestamp.fromDate(getMonthEnd()))
        .get();

    List<Map<String, dynamic>> reportRows = [];

    for (var doc in invoiceSnapshot.docs) {
      final data = doc.data();
      final customerName = data['customerName'] ?? '';
      final dollarRate = (data['dollarRate'] as num?)?.toDouble() ?? 0.0;
      final items = (data['items'] as List<dynamic>? ?? []);

      for (var item in items) {
        final row = {
          'invoiceId': doc.id,
          'buyer': customerName,
          'productName': item['model'] ?? '',
          'colour': item['colour'] ?? '',
          'quantity': (item['qty'] as num?)?.toInt() ?? 0,
          'sellingPrice': (item['price'] as num?)?.toDouble() ?? 0.0,
          'purchaseCost': null,
          'dollarRate': dollarRate,
          'profit': null,
          'netProfit': null,
          'incentive': null,
          'otherDeduction': 0.0,
          'fifteenPercent': null,
        };
        reportRows.add(row);
      }
    }

    final data = {
      'agentEmail': _agentEmail,
      'month': _selectedMonth,
      'year': year,
      'totalSales': totalSales,
      'totalShipping': totalShipping,
      'netSales': netSales,
      'totalPieces': totalPieces,
      'salesTarget': salesTarget,
      'achievedPercent': achievedPercent,
      'rows': reportRows,
      'purchaseCost': null,
      'netProfit': null,
      'payment': null,
      'incentive': null,
      'totalIncentive': null,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('marketing_incentives')
        .doc(docId)
        .set(data);

    setState(() {
      isSubmitted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Sales report submitted successfully!')),
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot> docs) {
    totalSales = 0;
    totalShipping = 0;
    netSales = 0;
    totalPieces = 0;

    List<DataRow> rows = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['timestamp'] as Timestamp?)?.toDate();
      final buyer = data['customerName'] ?? '';
      final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0;
      final shipping = (data['shippingCost'] as num?)?.toDouble() ?? 0;
      final net = amount - shipping;
      final method = data['paymentMethod'] ?? '';
      final status = data['paymentStatus'] ?? 'Pending';
      final invoiceNo = doc.id;
      final docRef = doc.reference;

      final items = (data['items'] as List?) ?? [];
      for (var item in items) {
        final productName = item['model'] ?? '';
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        totalPieces += qty;

        rows.add(
          DataRow(cells: [
            DataCell(Text(invoiceNo, style: const TextStyle(fontSize: 12))),
            DataCell(Text(DateFormat('dd-MM-yyyy').format(date ?? DateTime.now()))),
            DataCell(Text(buyer, style: const TextStyle(fontSize: 12))),
            DataCell(Text(productName.toString())),
            DataCell(Text(qty.toString())),
            DataCell(Text('৳${amount.toStringAsFixed(0)}')),
            DataCell(Text('৳${shipping.toStringAsFixed(0)}')),
            DataCell(Text('৳${net.toStringAsFixed(0)}')),
            DataCell(Text(method)),
            DataCell(
              isSubmitted
                  ? Text(status)
                  : DropdownButton<String>(
                value: status,
                underline: const SizedBox(),
                items: ['Done', 'Pending', 'Failed']
                    .map((val) =>
                    DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _updateStatus(docRef, val);
                },
              ),
            ),
          ]),
        );
      }

      totalSales += amount;
      totalShipping += shipping;
      netSales += net;
    }

    rows.add(
      DataRow(cells: [
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
        const DataCell(Text('')),
        DataCell(Text(totalPieces.toString())),
        DataCell(Text('৳${totalSales.toStringAsFixed(0)}')),
        DataCell(Text('৳${totalShipping.toStringAsFixed(0)}')),
        DataCell(Text('৳${netSales.toStringAsFixed(0)}')),
        const DataCell(Text('')),
        const DataCell(Text('')),
      ]),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
        dataRowMinHeight: 32,
        dataRowMaxHeight: 42,
        columnSpacing: 12,
        columns: const [
          DataColumn(label: Text('Invoice')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Buyer')),
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Pieces')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Shipping')),
          DataColumn(label: Text('Net')),
          DataColumn(label: Text('Method')),
          DataColumn(label: Text('Status')),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildSummary() {
    final percent =
    ((netSales / salesTarget) * 100).clamp(0, 999).toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text("👤 Agent: $_agentEmail"),
        Text("📦 Sales: ৳${totalSales.toStringAsFixed(0)}"),
        Text("🚚 Shipping: ৳${totalShipping.toStringAsFixed(0)}"),
        Text("💰 Net: ৳${netSales.toStringAsFixed(0)}"),
        Text("🎯 Target: ৳${salesTarget.toStringAsFixed(0)}"),
        Text("📈 Achieved: $percent%"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: Colors.indigo,
        actions: [
          if (!isSubmitted && _selectedMonth != null)
            TextButton(
              onPressed: _submitReport,
              child: const Text("Submit", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedMonth,
              items: months
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedMonth = val),
              decoration: const InputDecoration(
                labelText: 'Select Month',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedMonth != null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('invoices')
                      .where('agentEmail', isEqualTo: _agentEmail)
                      .where('timestamp',
                      isGreaterThanOrEqualTo:
                      Timestamp.fromDate(getMonthStart()))
                      .where('timestamp',
                      isLessThan: Timestamp.fromDate(getMonthEnd()))
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No invoices found."));
                    }

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildTable(snapshot.data!.docs),
                          const SizedBox(height: 12),
                          _buildSummary(),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
