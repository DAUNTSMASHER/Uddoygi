// lib/features/factory/presentation/screens/daily_production_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'production_dashboard.dart';

const Color _darkBlue = Color(0xFFD51616);

class DailyProductionScreen extends StatefulWidget {
  const DailyProductionScreen({Key? key}) : super(key: key);

  @override
  _DailyProductionScreenState createState() => _DailyProductionScreenState();
}

class _DailyProductionScreenState extends State<DailyProductionScreen> {
  String _cid = '';
  final _userEmail = FirebaseAuth.instance.currentUser?.email;

  // model dropdown
  List<String> _models = [];
  bool _loadingModels = true;

  // filters
  static const List<String> _filters = ['দিন', 'সপ্তাহ', 'মাস', 'বছর'];
  String _selectedFilter = _filters.first;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    final snap = await DB.colSync(_cid, C.products).orderBy('model_name').get();
    setState(() {
      _models = snap.docs.map((d) => (d.data()['model_name'] as String?) ?? d.id).toList();
      _loadingModels = false;
    });
  }

  DateTime _computeStart() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'সপ্তাহ':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case 'মাস':
        return DateTime(now.year, now.month, 1);
      case 'বছর':
        return DateTime(now.year, 1, 1);
      case 'দিন':
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _computeEnd(DateTime start) {
    switch (_selectedFilter) {
      case 'সপ্তাহ':
        return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case 'মাস':
        return DateTime(start.year, start.month + 1, 0, 23, 59, 59);
      case 'বছর':
        return DateTime(start.year, 12, 31, 23, 59, 59);
      case 'দিন':
      default:
        return start.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamByRange() {
    final start = _computeStart();
    final end = _computeEnd(start);
    return DB.colSync(_cid, C.dailyProduction)
        .where('managerEmail', isEqualTo: _userEmail)
        .where('productionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('productionDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('productionDate', descending: true)
        .snapshots();
  }

  Stream<int> _sumQuantityInRange(DateTime start, DateTime end) =>
      DB.colSync(_cid, C.dailyProduction)
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
        title: Text(existing == null ? 'উৎপাদন যোগ করুন' : 'উৎপাদন সম্পাদনা'),
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
                  decoration: _inputDecoration('পণ্যের মডেল'),
                  items: _models
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => model = v,
                  validator: (v) => v == null ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                // Base
                TextFormField(
                  initialValue: base,
                  decoration: _inputDecoration('বেস'),
                  onChanged: (v) => base = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: size,
                  decoration: _inputDecoration('সাইজ'),
                  onChanged: (v) => size = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: colour,
                  decoration: _inputDecoration('রঙ'),
                  onChanged: (v) => colour = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: curl,
                  decoration: _inputDecoration('কার্ল'),
                  onChanged: (v) => curl = v.trim(),
                  validator: (v) => v == null || v.isEmpty ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyCtrl,
                  decoration: _inputDecoration('পরিমাণ'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: whomCtrl,
                  decoration: _inputDecoration('কার জন্য / কী'),
                  validator: (v) => v == null || v.isEmpty ? 'আবশ্যক' : null,
                ),
                const SizedBox(height: 12),
                // Date
                Row(
                  children: [
                    Expanded(
                      child: Text('তারিখ: ${DateFormat.yMd().format(date)}'),
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
                      child: const Text('পরিবর্তন'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('বাতিল')),
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
                await DB.colSync(_cid, C.dailyProduction).add(entry);
              } else {
                await existing.reference.update(entry);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(existing == null ? 'যোগ করুন' : 'সংরক্ষণ'),
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
                      fontSize: 16,
                      color: Colors.white,
                    )),
                const SizedBox(height: 8),
                Text('$qty',
                    style: const TextStyle(
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
      return const Scaffold(body: Center(child: Text('অনুগ্রহ করে সাইন ইন করুন')));
    }

    // pre‑compute for dashboard
    final today     = DateTime.now();
    final dayStart  = DateTime(today.year, today.month, today.day);
    final dayEnd    = dayStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    final monthStart= DateTime(today.year, today.month, 1);
    final monthEnd  = DateTime(today.year, today.month + 1, 0, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('উৎপাদন', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'পূর্ণ ড্যাশবোর্ড',
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
                _buildDashboardCard('আজ', _sumQuantityInRange(dayStart, dayEnd)),
                _buildDashboardCard('এই মাস', _sumQuantityInRange(monthStart, monthEnd)),
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
                    return Text('মোট পরিমাণ: $qty');
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
                  return const Center(child: Text('কোনো এন্ট্রি নেই'));
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
                            Text('বেস: $base    সাইজ: $size'),
                            Text('রঙ: $colour    কার্ল: $curl'),
                            Text('জন্য: $whom'),
                            Text('তারিখ: $date'),
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
