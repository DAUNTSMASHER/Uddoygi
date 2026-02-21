// lib/features/factory/presentation/screens/qc_report_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'qc_report_details_screen.dart';

const Color _darkBlue = Color(0xFF40062D);

class QCReportScreen extends StatefulWidget {
  const QCReportScreen({Key? key}) : super(key: key);

  @override
  State<QCReportScreen> createState() => _QCReportScreenState();
}

class _QCReportScreenState extends State<QCReportScreen> {
  String _cid = '';
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _showAddQCDialog() async {
    final _formKey = GlobalKey<FormState>();
    String? modelName, base, colour, curl, density, remarks;
    int? quantity;
    DateTime qcDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QC এন্ট্রি যোগ করুন'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('মডেলের নাম', (v) => modelName = v, validator: _required),
                const SizedBox(height: 8),
                _buildTextField('বেস', (v) => base = v, validator: _required),
                const SizedBox(height: 8),
                _buildTextField('রঙ', (v) => colour = v, validator: _required),
                const SizedBox(height: 8),
                _buildTextField('কার্ল', (v) => curl = v, validator: _required),
                const SizedBox(height: 8),
                _buildTextField('ঘনত্ব', (v) => density = v, validator: _required),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'পরিমাণ', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => quantity = int.tryParse(v),
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'সংখ্যা লিখুন' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'মন্তব্য', border: OutlineInputBorder()),
                  maxLines: 3,
                  onChanged: (v) => remarks = v.trim(),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('QC তারিখ: ${DateFormat.yMd().format(qcDate)}'),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final pick = await showDatePicker(
                          context: ctx,
                          initialDate: qcDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now(),
                        );
                        if (pick != null) setState(() => qcDate = pick);
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
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              await DB.colSync(_cid, C.qcReports).add({
                'agentEmail': FirebaseAuth.instance.currentUser?.email,
                'productType': 'wig',
                'modelName': modelName,
                'base': base,
                'colour': colour,
                'curl': curl,
                'density': density,
                'quantity': quantity,
                'remarks': remarks,
                'qcDate': Timestamp.fromDate(qcDate),
                'timestamp': Timestamp.now(),
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QC এন্ট্রি যোগ হয়েছে')));
            },
            child: const Text('জমা দিন'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditQCDialog(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data()!;
    final _formKey = GlobalKey<FormState>();
    String modelName = data['modelName'], base = data['base'], colour = data['colour'],
        curl = data['curl'], density = data['density'], remarks = data['remarks'];
    int quantity = data['quantity'];
    DateTime qcDate = (data['qcDate'] as Timestamp).toDate();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QC এন্ট্রি সম্পাদনা'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildTextField('মডেলের নাম', (v) => modelName = v, initial: data['modelName'], validator: _required),
              const SizedBox(height: 8),
              _buildTextField('বেস', (v) => base = v, initial: data['base'], validator: _required),
              const SizedBox(height: 8),
              _buildTextField('রঙ', (v) => colour = v, initial: data['colour'], validator: _required),
              const SizedBox(height: 8),
              _buildTextField('কার্ল', (v) => curl = v, initial: data['curl'], validator: _required),
              const SizedBox(height: 8),
              _buildTextField('ঘনত্ব', (v) => density = v, initial: data['density'], validator: _required),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: quantity.toString(),
                decoration: const InputDecoration(labelText: 'পরিমাণ', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                onChanged: (v) => quantity = int.tryParse(v) ?? quantity,
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'সংখ্যা লিখুন' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: remarks,
                decoration: const InputDecoration(labelText: 'মন্তব্য', border: OutlineInputBorder()),
                maxLines: 3,
                onChanged: (v) => remarks = v.trim(),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('QC তারিখ: ${DateFormat.yMd().format(qcDate)}'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final pick = await showDatePicker(
                      context: ctx,
                      initialDate: qcDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (pick != null) setState(() => qcDate = pick);
                  },
                  child: const Text('পরিবর্তন'),
                ),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              await DB.colSync(_cid, C.qcReports).doc(doc.id).update({
                'modelName': modelName,
                'base': base,
                'colour': colour,
                'curl': curl,
                'density': density,
                'quantity': quantity,
                'remarks': remarks,
                'qcDate': Timestamp.fromDate(qcDate),
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QC এন্ট্রি আপডেট হয়েছে')));
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, ValueChanged<String> onChanged,
      {String? initial, String? Function(String?)? validator}) {
    return TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (v) => onChanged(v.trim()),
      validator: validator,
    );
  }

  String? _required(String? v) => (v == null || v.isEmpty) ? 'আবশ্যক' : null;
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }


  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) {
      return const Scaffold(body: Center(child: Text('অনুগ্রহ করে সাইন ইন করুন')));
    }

    final startOfDay = Timestamp.fromDate(
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
    );
    final endOfDay = Timestamp.fromDate(
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('QC রিপোর্ট', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          // Add / View all
          Row(children: [
            Expanded(child: _actionCard(icon: Icons.add, label: 'QC যোগ করুন', onTap: _showAddQCDialog)),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.list,
                label: 'সব QC দেখুন',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QCReportDetailsScreen(productionId: null)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          // Date selector + recent
          Row(children: [
            Text('তারিখ: ${DateFormat.yMMMMd().format(_selectedDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          ]),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DB.colSync(_cid, C.qcReports)
                  .where('agentEmail', isEqualTo: userEmail)
                  .where('qcDate', isGreaterThanOrEqualTo: startOfDay)
                  .where('qcDate', isLessThanOrEqualTo: endOfDay)
                  .orderBy('qcDate', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('এই তারিখে কোনো QC রিপোর্ট নেই।'));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final qcDate = (d['qcDate'] as Timestamp?)?.toDate();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(d['modelName'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('তারিখ: ${qcDate != null ? DateFormat.yMd().format(qcDate) : '—'}\nমন্তব্য: ${d['remarks'] ?? ''}'),
                        isThreeLine: true,
                        trailing: Wrap(spacing: 8, children: [
                          TextButton(child: const Text('সম্পাদনা'), onPressed: () => _showEditQCDialog(doc)),
                          TextButton(
                            child: const Text('বিস্তারিত'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => QCReportDetailsScreen(productionId: doc.id)),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      color: _darkBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 80,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 28, color: Colors.white),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ]),
          ),
        ),
      ),
    );
  }
}
