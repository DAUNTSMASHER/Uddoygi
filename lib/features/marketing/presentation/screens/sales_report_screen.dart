import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Top-level metrics model (cannot be inside the State class)
class _Metrics {
  final double totalSales;
  final double totalShipping;
  final double netSales;
  final int totalPieces;
  const _Metrics(this.totalSales, this.totalShipping, this.netSales, this.totalPieces);
}

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  // —— UI scale ——
  static const double _fontSmall = 12;
  static const double _fontRegular = 14;
  static const double _fontLarge = 16;

  // —— Theme accents ——
  static const _primary = Colors.indigo;
  static const _surface = Color(0xFFF5F7FB);
  static const _card = Colors.white;
  static const _okGreen = Color(0xFF21C7A8);

  String? _selectedMonth;
  double salesTarget = 100000;

  bool isSubmitted = false;
  bool _submitting = false;

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

    final value = snap.data()?['monthlyTarget'];
    if (value != null && value is num) {
      setState(() => salesTarget = value.toDouble());
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

  Future<void> _submitReport({
    required double totalSales,
    required double totalShipping,
    required double netSales,
    required int totalPieces,
    required List<QueryDocumentSnapshot> sourceDocs,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit monthly report?'),
        content: Text(
          "Month: $_selectedMonth\n"
              "Net: ৳${netSales.toStringAsFixed(0)}\n"
              "Target: ৳${salesTarget.toStringAsFixed(0)}",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final year = now.year;
      final docId = "${_agentEmail}_$_selectedMonth\_$year\_sales";
      final achievedPercent =
      ((netSales / salesTarget) * 100).clamp(0, 999).toStringAsFixed(2);

      final List<Map<String, dynamic>> reportRows = [];
      for (var doc in sourceDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final customerName = data['customerName'] ?? '';
        final dollarRate = (data['dollarRate'] as num?)?.toDouble() ?? 0.0;
        final items = (data['items'] as List<dynamic>? ?? []);
        for (var item in items) {
          reportRows.add({
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
          });
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

      setState(() => isSubmitted = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Sales report submitted successfully!')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  _Metrics _computeMetrics(List<QueryDocumentSnapshot> docs) {
    double totalSales = 0;
    double totalShipping = 0;
    double netSales = 0;
    int totalPieces = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['grandTotal'] as num?)?.toDouble() ?? 0;
      final shipping = (data['shippingCost'] as num?)?.toDouble() ?? 0;
      final net = amount - shipping;

      final items = (data['items'] as List?) ?? [];
      for (var item in items) {
        totalPieces += (item['qty'] as num?)?.toInt() ?? 0;
      }

      totalSales += amount;
      totalShipping += shipping;
      netSales += net;
    }
    return _Metrics(totalSales, totalShipping, netSales, totalPieces);
  }

  // —— UI helpers ——
  Widget _monthPicker() {
    return DropdownButtonFormField<String>(
      value: _selectedMonth,
      items: months
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (val) => setState(() => _selectedMonth = val),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.calendar_month),
        labelText: 'Select month',
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    Color color = _primary,
    Widget? footer,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: _fontSmall,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 6),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      color: _primary,
                      fontWeight: FontWeight.w900,
                    )),
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid(_Metrics m) {
    final achieved = salesTarget == 0 ? 0.0 : (m.netSales / salesTarget * 100).clamp(0, 100);
    final isWide = MediaQuery.of(context).size.width >= 720;
    final cols = isWide ? 4 : 2;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isWide ? 3.0 : 2.2,
      ),
      children: [
        _kpiCard(
          label: 'Target',
          value: '৳${salesTarget.toStringAsFixed(0)}',
          icon: Icons.flag_rounded,
        ),
        _kpiCard(
          label: 'Achieved',
          value: '৳${m.netSales.toStringAsFixed(0)}',
          icon: Icons.payments_rounded,
          color: _okGreen,
        ),
        _kpiCard(
          label: 'Pieces',
          value: m.totalPieces.toString(),
          icon: Icons.widgets_rounded,
          color: const Color(0xFF20B2AA),
        ),
        _kpiCard(
          label: 'Progress',
          value: '${achieved.toStringAsFixed(0)}%',
          icon: Icons.trending_up_rounded,
          color: _primary,
          footer: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: achieved / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: _primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend() {
    return Row(
      children: [
        _legendDot(color: _okGreen, text: 'Paid'),
        const SizedBox(width: 12),
        _legendDot(color: Colors.orange, text: 'Unpaid'),
      ],
    );
  }

  Widget _legendDot({required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ——— Table ———
  Widget _buildTable(List<QueryDocumentSnapshot> docs) {
    final rows = <DataRow>[];
    int i = 0;

    double totalSales = 0;
    double totalShipping = 0;
    double netSales = 0;
    int totalPieces = 0;

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
        final productName = (item['model'] ?? '').toString();
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        totalPieces += qty;

        rows.add(
          DataRow(
            color: WidgetStatePropertyAll(i.isEven ? Colors.grey.shade50 : Colors.white),
            cells: [
              DataCell(Text(invoiceNo, style: const TextStyle(fontSize: 12))),
              DataCell(Text(DateFormat('dd-MM-yyyy').format(date ?? DateTime.now()))),
              DataCell(Text(buyer, style: const TextStyle(fontSize: 12))),
              DataCell(Text(productName)),
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
                  items: const ['Done', 'Pending', 'Failed']
                      .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) _updateStatus(docRef, val);
                  },
                ),
              ),
            ],
          ),
        );
        i++;
      }

      totalSales += amount;
      totalShipping += shipping;
      netSales += net;
    }

    rows.add(
      DataRow(
        color: WidgetStatePropertyAll(Colors.indigo.shade50),
        cells: [
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          const DataCell(Text('')),
          DataCell(Text(totalPieces.toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
          DataCell(Text('৳${totalSales.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          DataCell(Text('৳${totalShipping.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          DataCell(Text('৳${netSales.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          const DataCell(Text('')),
          const DataCell(Text('')),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(Colors.indigo.shade50),
          dataRowMinHeight: 36,
          dataRowMaxHeight: 48,
          columnSpacing: 14,
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
      ),
    );
  }

  // ——— Scaffold ———
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: _primary,
      ),
      bottomNavigationBar: (_selectedMonth == null)
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.check_circle),
            onPressed: (_submitting || isSubmitted)
                ? null
                : () async {
              final qs = await FirebaseFirestore.instance
                  .collection('invoices')
                  .where('agentEmail', isEqualTo: _agentEmail)
                  .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(getMonthStart()))
                  .where('timestamp', isLessThan: Timestamp.fromDate(getMonthEnd()))
                  .get();

              if (qs.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No invoices to submit for this month.')),
                );
                return;
              }

              final m = _computeMetrics(qs.docs);
              await _submitReport(
                totalSales: m.totalSales,
                totalShipping: m.totalShipping,
                netSales: m.netSales,
                totalPieces: m.totalPieces,
                sourceDocs: qs.docs,
              );
            },
            label: Text(isSubmitted ? 'Submitted' : 'Submit report'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: Colors.indigo.shade200,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _monthPicker(),
            const SizedBox(height: 12),
            if (_selectedMonth == null)
              Expanded(
                child: Center(
                  child: Text(
                    'Select a month to view your report.',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('invoices')
                      .where('agentEmail', isEqualTo: _agentEmail)
                      .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(getMonthStart()))
                      .where('timestamp', isLessThan: Timestamp.fromDate(getMonthEnd()))
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12.withOpacity(.06)),
                          ),
                          child: Text('No invoices found for $_selectedMonth.',
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    final m = _computeMetrics(docs);

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summaryGrid(m),
                          const SizedBox(height: 12),
                          _legend(),
                          const SizedBox(height: 12),
                          _buildTable(docs),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12.withOpacity(.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("👤 Agent: $_agentEmail",
                                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text("📦 Sales: ৳${m.totalSales.toStringAsFixed(0)}"),
                                Text("🚚 Shipping: ৳${m.totalShipping.toStringAsFixed(0)}"),
                                Text("💰 Net: ৳${m.netSales.toStringAsFixed(0)}"),
                                Text("🎯 Target: ৳${salesTarget.toStringAsFixed(0)}"),
                                Text("📈 Achieved: ${(m.netSales / salesTarget * 100).clamp(0, 999).toStringAsFixed(2)}%"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80),
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
