// lib/features/factory/presentation/screens/daily_production_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'production_dashboard.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class DailyProductionScreen extends StatefulWidget {
  const DailyProductionScreen({Key? key}) : super(key: key);

  @override
  _DailyProductionScreenState createState() => _DailyProductionScreenState();
}

class _DailyProductionScreenState extends State<DailyProductionScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _userEmail = FirebaseAuth.instance.currentUser?.email;

  // model dropdown
  List<String> _models = [];
  bool _loadingModels = true;

  // filters
  static const List<String> _filters = ['Day', 'Week', 'Month', 'Year'];
  String _selectedFilter = _filters.first;

  @override
  void initState() {
    super.initState();
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    final snap = await _firestore.collection('products').orderBy('model_name').get();
    setState(() {
      _models = snap.docs.map((d) => (d.data()['model_name'] as String?) ?? d.id).toList();
      _loadingModels = false;
    });
  }

  DateTime _computeStart() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case 'Month':
        return DateTime(now.year, now.month, 1);
      case 'Year':
        return DateTime(now.year, 1, 1);
      case 'Day':
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _computeEnd(DateTime start) {
    switch (_selectedFilter) {
      case 'Week':
        return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case 'Month':
        return DateTime(start.year, start.month + 1, 0, 23, 59, 59);
      case 'Year':
        return DateTime(start.year, 12, 31, 23, 59, 59);
      case 'Day':
      default:
        return start.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamByRange() {
    final start = _computeStart();
    final end = _computeEnd(start);
    return _firestore
        .collection('daily_production')
        .where('managerEmail', isEqualTo: _userEmail)
        .where('productionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('productionDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('productionDate', descending: true)
        .snapshots();
  }

  Stream<int> _sumQuantityInRange(DateTime start, DateTime end) =>
      _firestore
          .collection('daily_production')
          .where('managerEmail', isEqualTo: _userEmail)
          .where('productionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('productionDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .snapshots()
          .map((snap) => snap.docs.fold<int>(
        0,
            (sum, doc) => sum + (doc.data()['quantity'] as int? ?? 0),
      ));

  Stream<int> _dailyTotal() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    return _sumQuantityInRange(start, end);
  }

  Stream<int> _monthlyTotal() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _sumQuantityInRange(start, end);
  }

  Future<void> _showEntryDialog({DocumentSnapshot<Map<String, dynamic>>? existing}) async {
    String? model  = existing?.data()?['productModel'] as String?;
    String? base   = existing?.data()?['base']        as String?;
    String? size   = existing?.data()?['size']        as String?;
    String? colour = existing?.data()?['colour']      as String?;
    String? curl   = existing?.data()?['curl']        as String?;
    final qtyCtrl  = TextEditingController(text: existing?.data()?['quantity']?.toString() ?? '');
    final whomCtrl = TextEditingController(text: existing?.data()?['forWhom'] as String? ?? '');
    DateTime date  = existing != null
        ? (existing.data()!['productionDate'] as Timestamp).toDate()
        : DateTime.now();
    final formKey  = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(existing == null ? 'Add Production' : 'Edit Production'),
        content: _loadingModels
            ? SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        )
            : SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Model
                DropdownButtonFormField<String>(
                  value: model,
                  decoration: _inputDecoration('Product Model'),
                  items: _models
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => model = v,
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Base
                TextFormField(
                  initialValue: base,
                  decoration: _inputDecoration('Base'),
                  onChanged: (v) => base = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Size
                TextFormField(
                  initialValue: size,
                  decoration: _inputDecoration('Size'),
                  onChanged: (v) => size = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Colour
                TextFormField(
                  initialValue: colour,
                  decoration: _inputDecoration('Colour'),
                  onChanged: (v) => colour = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Curl
                TextFormField(
                  initialValue: curl,
                  decoration: _inputDecoration('Curl'),
                  onChanged: (v) => curl = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Quantity
                TextFormField(
                  controller: qtyCtrl,
                  decoration: _inputDecoration('Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // For Whom
                TextFormField(
                  controller: whomCtrl,
                  decoration: _inputDecoration('For Whom / What'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // Date
                Row(
                  children: [
                    Expanded(
                      child: Text('Date: ${DateFormat.yMd().format(date)}'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate() || model == null) return;
              final entry = {
                'productModel': model,
                'base'        : base,
                'size'        : size,
                'colour'      : colour,
                'curl'        : curl,
                'quantity'    : int.parse(qtyCtrl.text),
                'forWhom'     : whomCtrl.text,
                'productionDate': Timestamp.fromDate(date),
                'managerEmail': _userEmail,
                'timestamp'   : FieldValue.serverTimestamp(),
              };
              if (existing == null) {
                await _firestore.collection('daily_production').add(entry);
              } else {
                await existing.reference.update(entry);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
  );

  Widget _buildDashboardCard(String label, Stream<int> stream) {
    return Card(
      color: _darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<int>(
          stream: stream,
          builder: (ctx, snap) {
            final qty = snap.data ?? 0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 16,
                      color: Colors.white,
                    )),
                const SizedBox(height: 8),
                Text('$qty',
                    style: const TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userEmail == null) {
      return const Scaffold(body: Center(child: Text('Please sign in to continue')));
    }

    // pre‑compute for dashboard
    final today     = DateTime.now();
    final dayStart  = DateTime(today.year, today.month, today.day);
    final dayEnd    = dayStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    final monthStart= DateTime(today.year, today.month, 1);
    final monthEnd  = DateTime(today.year, today.month + 1, 0, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production'),
        backgroundColor: _darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Full Dashboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductionDashboard()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Dashboard Grid ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildDashboardCard('Today', _sumQuantityInRange(dayStart, dayEnd)),
                _buildDashboardCard('This Month', _sumQuantityInRange(monthStart, monthEnd)),
              ],
            ),
          ),

          // ─── Filter + summary ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: const Icon(Icons.filter_list, color: _darkBlue),
                title: DropdownButton<String>(
                  value: _selectedFilter,
                  underline: const SizedBox(),
                  items: _filters
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFilter = v!),
                ),
                subtitle: StreamBuilder<int>(
                  stream: _sumQuantityInRange(_computeStart(), _computeEnd(_computeStart())),
                  builder: (ctx, snap) {
                    final qty = snap.data ?? 0;
                    return Text('Total Qty: $qty');
                  },
                ),
              ),
            ),
          ),

          // ─── List of entries ─────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _streamByRange(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No entries'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc  = docs[i];
                    final data = doc.data();
                    final model  = data['productModel'] as String? ?? '—';
                    final base   = data['base']         as String? ?? '—';
                    final size   = data['size']         as String? ?? '—';
                    final colour = data['colour']       as String? ?? '—';
                    final curl   = data['curl']         as String? ?? '—';
                    final qty    = data['quantity']?.toString() ?? '—';
                    final whom   = data['forWhom']      as String? ?? '—';
                    final ts     = data['productionDate'] as Timestamp?;
                    final date   = ts != null ? DateFormat.yMMMd().format(ts.toDate()) : '—';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        title: Text('$model × $qty', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Base: $base    Size: $size'),
                            Text('Colour: $colour    Curl: $curl'),
                            Text('For: $whom'),
                            Text('On: $date'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: _darkBlue),
                          onPressed: () => _showEntryDialog(existing: doc),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _darkBlue,
        child: const Icon(Icons.add),
        onPressed: () => _showEntryDialog(),
      ),
    );
  }
}
