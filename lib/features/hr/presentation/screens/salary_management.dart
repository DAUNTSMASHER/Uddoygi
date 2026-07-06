import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _brandGreen = Color(0xFF065F46);
final _money      = UddoygiDesign.moneyFormat;

// ─────────────────────────────────────────────────────────────────────────────
class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});
  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  String _cid = '';
  String? _selectedEmployee;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text('Salary Registry', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: _brandGreen), onPressed: () {}),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSalaryForm(),
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Set Salary', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _SalaryFilters(
            onEmployeeChanged: (v) => setState(() => _selectedEmployee = v.isEmpty ? null : v),
            onMonthTap: _pickMonth,
            selectedMonth: _selectedMonth,
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.salaries).snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final empMatch = _selectedEmployee == null || data['employeeName'].toString().toLowerCase().contains(_selectedEmployee!.toLowerCase());
                  return empMatch;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(UddoygiDesign.space20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _SalaryCard(doc: filtered[i]).animate().fadeIn(delay: (i * 50).ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _pickMonth() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  void _showSalaryForm() {}
}

class _SalaryFilters extends StatelessWidget {
  final ValueChanged<String> onEmployeeChanged;
  final VoidCallback onMonthTap;
  final DateTime? selectedMonth;
  const _SalaryFilters({required this.onEmployeeChanged, required this.onMonthTap, this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onEmployeeChanged,
              decoration: InputDecoration(
                hintText: 'Search employee...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onMonthTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.calendar_today_rounded, color: _brandGreen, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _SalaryCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final net = (d['base'] ?? 0) + (d['bonus'] ?? 0) - (d['deduction'] ?? 0);

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(d['employeeName']?[0] ?? '?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _brandGreen)))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['employeeName'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text(d['month'] ?? 'Current Period', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳ ${_money.format(net)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _brandGreen)),
                  Text('NET SALARY', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[300])),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat(label: 'Base', value: _money.format(d['base'] ?? 0)),
              _MiniStat(label: 'Bonus', value: _money.format(d['bonus'] ?? 0), color: Colors.green),
              _MiniStat(label: 'Deduction', value: _money.format(d['deduction'] ?? 0), color: Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[500])),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF0F172A))),
    ],
  );
}
