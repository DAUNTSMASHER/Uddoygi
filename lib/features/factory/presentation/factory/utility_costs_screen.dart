// lib/features/factory/presentation/factory/utility_costs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _brandRed = Color(0xFFB91C1C);

class UtilityCostsScreen extends StatefulWidget {
  const UtilityCostsScreen({super.key});

  @override
  State<UtilityCostsScreen> createState() => _UtilityCostsScreenState();
}

class _UtilityCostsScreenState extends State<UtilityCostsScreen> {
  String _cid = '';
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  String _category = 'Electricity';
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'Electricity',
    'Water',
    'Gas',
    'Moyla (Waste)',
    'Maid / Cleaning',
    'Internet',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Future<void> _saveCost() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    await DB.colSync(_cid, 'factory_utilities').add({
      'category': _category,
      'amount': amount,
      'remarks': _remarksController.text,
      'date': Timestamp.fromDate(_selectedDate),
      'timestamp': FieldValue.serverTimestamp(),
      'createdBy': 'Factory Manager', // Can be dynamic
    });

    _amountController.clear();
    _remarksController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Utility cost logged successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Utility & Site Costs', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: _brandRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildEntryForm(),
          const Divider(height: 1),
          Expanded(child: _buildRecentLogs()),
        ],
      ),
    );
  }

  Widget _buildEntryForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppFonts.banglaBody(fontSize: 14)))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_rounded)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (৳)', prefixIcon: Icon(Icons.payments_rounded)),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _remarksController,
                    decoration: const InputDecoration(labelText: 'Remarks / Bill No', prefixIcon: Icon(Icons.notes_rounded)),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                    final pick = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (pick != null) setState(() => _selectedDate = pick);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _brandRed.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _brandRed.withOpacity(0.1))),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: _brandRed),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd MMM').format(_selectedDate), style: AppFonts.banglaHeading(fontWeight: FontWeight.w700, color: _brandRed)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveCost,
                style: ElevatedButton.styleFrom(backgroundColor: _brandRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('LOG EXPENSE', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLogs() {
    if (_cid.isEmpty) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, 'factory_utilities').orderBy('date', descending: true).limit(50).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;

        if (docs.isEmpty) return const Center(child: Text('No costs logged yet'));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final date = (d['date'] as Timestamp).toDate();
            
            return UCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _brandRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_getIcon(d['category']), color: _brandRed, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['category'] ?? 'Other', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(d['remarks']?.toString().isEmpty ?? true ? 'No remarks' : d['remarks'], style: AppFonts.banglaBody(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('৳${d['amount']}', style: AppFonts.banglaData(fontWeight: FontWeight.w900, fontSize: 16, color: _brandRed)),
                      Text(DateFormat('dd MMM yyyy').format(date), style: AppFonts.banglaBody(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
          },
        );
      },
    );
  }

  IconData _getIcon(String? cat) {
    switch (cat) {
      case 'Electricity': return Icons.bolt_rounded;
      case 'Water': return Icons.water_drop_rounded;
      case 'Gas': return Icons.local_fire_department_rounded;
      case 'Moyla (Waste)': return Icons.delete_sweep_rounded;
      case 'Maid / Cleaning': return Icons.cleaning_services_rounded;
      case 'Internet': return Icons.wifi_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }
}
