// lib/features/factory/presentation/factory/daily_production.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/widgets/u_inventory_analytics.dart';

class DailyProductionScreen extends StatefulWidget {
  const DailyProductionScreen({Key? key}) : super(key: key);

  @override
  State<DailyProductionScreen> createState() => _DailyProductionScreenState();
}

class _DailyProductionScreenState extends State<DailyProductionScreen> with SingleTickerProviderStateMixin {
  String _cid = '';
  bool _loading = true;
  late TabController _tabController;
  final Color _brandRed = const Color(0xFF991B1B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() { _cid = id ?? ''; _loading = false; });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F2),
      appBar: AppBar(
        title: Text('দৈনিক উৎপাদন ও স্টক', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: _brandRed,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: AppFonts.banglaHeading(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'উৎপাদন লগ'),
            Tab(text: 'পণ্য তালিকা'),
            Tab(text: 'রিসোর্স/কাঁচামাল'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openActionSheet,
        backgroundColor: _brandRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('নতুন এন্ট্রি', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogTab(),
          _buildProductsTab(),
          _buildResourcesTab(),
        ],
      ),
    );
  }

  void _openActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('আপনি কী করতে চান?', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _ActionButton(
              label: 'উৎপাদন রিপোর্ট করুন',
              icon: Icons.history_edu,
              color: Colors.red,
              onTap: () { Navigator.pop(context); _showProductionLogForm(); },
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'নতুন পণ্য যোগ করুন',
              icon: Icons.inventory_2,
              color: Colors.blue,
              onTap: () { Navigator.pop(context); _showAddProductForm(); },
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'নতুন রিসোর্স যোগ করুন',
              icon: Icons.category,
              color: Colors.orange,
              onTap: () { Navigator.pop(context); _showAddResourceForm(); },
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: LOG OUTPUT ──────────────────────────────────────────────────────

  Widget _buildLogTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const UInventoryAnalytics(themeColor: Color(0xFF991B1B)),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF991B1B)),
            const SizedBox(width: 8),
            Text('সাম্প্রতিক উৎপাদন লগ', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.dailyProduction).orderBy('timestamp', descending: true).limit(20).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return _buildEmptyState('কোন উৎপাদন রেকর্ড নেই');

            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final date = (d['productionDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: UCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _brandRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.check_circle, color: _brandRed),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['productModel'] ?? 'Unknown', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('${d['quantity']} ইউনিট • ${d['type'] ?? 'পণ্য'}', style: AppFonts.banglaBody(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(DateFormat.yMMMd().format(date), style: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(DateFormat.jm().format(date), style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideX(begin: 0.1, end: 0),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── TAB 2: PRODUCTS ─────────────────────────────────────────────────────────

  Widget _buildProductsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.products).orderBy('model_name').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final stock = (d['stock'] as num?) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['model_name'] ?? 'Untitled', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('${d['colour'] ?? '-'} • ${d['size'] ?? '-'}', style: AppFonts.banglaBody(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$stock', style: AppFonts.banglaData(fontWeight: FontWeight.w900, fontSize: 18, color: stock < 10 ? Colors.red : Colors.green)),
                        Text('স্টক', style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── TAB 3: RESOURCES ───────────────────────────────────────────────────────

  Widget _buildResourcesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.stocks).orderBy('name').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final qty = (d['qty'] as num?) ?? 0;
            final min = (d['minThreshold'] as num?) ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: UCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.category, color: Colors.orange),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['name'] ?? 'Untitled', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(d['category'] ?? 'Raw Material', style: AppFonts.banglaBody(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$qty ${d['unit'] ?? ''}', style: AppFonts.banglaData(fontWeight: FontWeight.w900, fontSize: 16, color: qty < min ? Colors.red : Colors.black87)),
                        Text('স্টক', style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── FORMS ──────────────────────────────────────────────────────────────────

  void _showProductionLogForm() {
    String type = 'Finished Good';
    String? selectedItem;
    final qtyCtl = TextEditingController();
    DateTime date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('উৎপাদন এন্ট্রি করুন', style: AppFonts.banglaHeading(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: _fieldDeco('ধরণ'),
                  items: const [
                    DropdownMenuItem(value: 'Finished Good', child: Text('তৈরি পণ্য')),
                    DropdownMenuItem(value: 'Raw Material', child: Text('বেস / কাঁচামাল')),
                  ],
                  onChanged: (v) {
                    setModalState(() { type = v!; selectedItem = null; });
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _cid.isEmpty ? const Stream.empty() : (type == 'Finished Good' 
                    ? DB.colSync(_cid, C.products).orderBy('model_name').snapshots()
                    : DB.colSync(_cid, C.stocks).orderBy('name').snapshots()),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedItem,
                      decoration: _fieldDeco('আইটেম নির্বাচন করুন'),
                      items: docs.map((d) {
                        final name = type == 'Finished Good' ? d.data()['model_name'] : d.data()['name'];
                        return DropdownMenuItem(value: d.id, child: Text(name ?? 'Unnamed'));
                      }).toList(),
                      onChanged: (v) => setModalState(() => selectedItem = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtl,
                  decoration: _fieldDeco('পরিমাণ'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('উৎপাদন তারিখ', style: AppFonts.banglaBody(fontSize: 14)),
                  subtitle: Text(DateFormat.yMMMd().format(date)),
                  trailing: const Icon(Icons.calendar_today, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2023), lastDate: DateTime.now());
                    if (picked != null) setModalState(() => date = picked);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _saveProductionLog(type, selectedItem, qtyCtl.text, date),
                    style: ElevatedButton.styleFrom(backgroundColor: _brandRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('সংরক্ষণ করুন', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProductionLog(String type, String? id, String qtyStr, DateTime date) async {
    if (id == null || qtyStr.isEmpty) return;
    final qty = int.tryParse(qtyStr) ?? 0;
    if (qty <= 0) return;

    final batch = DB.firestore.batch();
    final logRef = DB.colSync(_cid, C.dailyProduction).doc();
    
    String itemName = '';
    if (type == 'Finished Good') {
      final snap = await DB.colSync(_cid, C.products).doc(id).get();
      itemName = snap.data()?['model_name'] ?? id;
      batch.update(snap.reference, {'stock': FieldValue.increment(qty)});
    } else {
      final snap = await DB.colSync(_cid, C.stocks).doc(id).get();
      itemName = snap.data()?['name'] ?? id;
      batch.update(snap.reference, {'qty': FieldValue.increment(qty)});
    }

    batch.set(logRef, {
      'productModel': itemName,
      'itemId': id,
      'type': type,
      'quantity': qty,
      'productionDate': Timestamp.fromDate(date),
      'timestamp': FieldValue.serverTimestamp(),
      'managerEmail': FirebaseAuth.instance.currentUser?.email,
    });

    await batch.commit();
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ উৎপাদন রেকর্ড সংরক্ষণ করা হয়েছে')));
  }

  void _showAddProductForm() {
    final modelCtl = TextEditingController();
    final colorCtl = TextEditingController();
    final sizeCtl = TextEditingController();
    final priceCtl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('নতুন পণ্য যোগ করুন', style: AppFonts.banglaHeading(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: modelCtl, decoration: _fieldDeco('মডেল নাম')),
            const SizedBox(height: 12),
            TextField(controller: colorCtl, decoration: _fieldDeco('রঙ')),
            const SizedBox(height: 12),
            TextField(controller: sizeCtl, decoration: _fieldDeco('সাইজ')),
            const SizedBox(height: 12),
            TextField(controller: priceCtl, decoration: _fieldDeco('ইউনিট মূল্য (৳)'), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (modelCtl.text.isEmpty) return;
                  await DB.colSync(_cid, C.products).add({
                    'model_name': modelCtl.text.trim(),
                    'colour': colorCtl.text.trim(),
                    'size': sizeCtl.text.trim(),
                    'unit_price': double.tryParse(priceCtl.text) ?? 0,
                    'stock': 0,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _brandRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('পণ্য তৈরি করুন', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddResourceForm() {
    final nameCtl = TextEditingController();
    final unitCtl = TextEditingController();
    final minCtl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('নতুন রিসোর্স যোগ করুন', style: AppFonts.banglaHeading(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: nameCtl, decoration: _fieldDeco('রিসোর্সের নাম (উদা: বেস, হেয়ার)')),
            const SizedBox(height: 12),
            TextField(controller: unitCtl, decoration: _fieldDeco('ইউনিট (উদা: গ্রাম, পিস)')),
            const SizedBox(height: 12),
            TextField(controller: minCtl, decoration: _fieldDeco('মিনিমাম থ্রেশহোল্ড'), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtl.text.isEmpty) return;
                  await DB.colSync(_cid, C.stocks).add({
                    'name': nameCtl.text.trim(),
                    'unit': unitCtl.text.trim(),
                    'minThreshold': int.tryParse(minCtl.text) ?? 10,
                    'qty': 0,
                    'category': 'Raw Material',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _brandRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('রিসোর্স তৈরি করুন', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
    labelText: hint,
    labelStyle: AppFonts.banglaBody(fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _buildEmptyState(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(msg, style: AppFonts.banglaBody(color: Colors.grey.shade500)),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label, style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
