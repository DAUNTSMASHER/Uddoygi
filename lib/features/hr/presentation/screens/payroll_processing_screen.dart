import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
final _money      = UddoygiDesign.moneyFormat;

// ─────────────────────────────────────────────────────────────────────────────
class PayrollProcessingScreen extends StatefulWidget {
  const PayrollProcessingScreen({super.key});
  @override
  State<PayrollProcessingScreen> createState() => _PayrollProcessingScreenState();
}

class _PayrollProcessingScreenState extends State<PayrollProcessingScreen> {
  String _cid = '';
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  String filterDepartment = '';
  String filterEmployeeId = '';

  final _empIdController = TextEditingController();
  final _salaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _empIdController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Payroll Processing', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month_rounded), onPressed: _pickMonth),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGenerateSheet,
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Generate', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DB.colSync(_cid, C.payrolls).where('period', isEqualTo: selectedMonth).snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          final filtered = docs.where((doc) {
            final d = doc.data();
            final q = filterEmployeeId.toLowerCase();
            return q.isEmpty || (d['employeeName'] ?? '').toString().toLowerCase().contains(q) || (d['employeeId'] ?? '').toString().toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              _FilterPanel(
                month: selectedMonth,
                dept: filterDepartment,
                onMonthTap: _pickMonth,
                onDeptChanged: (v) => setState(() => filterDepartment = v),
                onSearchChanged: (v) => setState(() => filterEmployeeId = v),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(UddoygiDesign.space20),
                  children: [
                    _SummaryStrip(docs: filtered),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty) const _EmptyState() else ...filtered.map((d) => _PayrollCard(data: d.data()).animate().fadeIn().slideY(begin: 0.1, end: 0)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 1));
    if (picked != null) setState(() => selectedMonth = DateFormat('MMMM yyyy').format(picked));
  }

  void _openGenerateSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => _GenerateForm(cid: _cid, onGenerated: () => Navigator.pop(context)));
  }
}

class _FilterPanel extends StatelessWidget {
  final String month, dept;
  final VoidCallback onMonthTap;
  final ValueChanged<String> onDeptChanged, onSearchChanged;
  const _FilterPanel({required this.month, required this.dept, required this.onMonthTap, required this.onDeptChanged, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      color: const Color(0xFF065F46),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onMonthTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 10),
                        Text(month, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: onSearchChanged,
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search Employee Name or ID',
              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _SummaryStrip({required this.docs});

  @override
  Widget build(BuildContext context) {
    double totalGross = 0; double totalNet = 0;
    for (final d in docs) {
      final m = d.data();
      totalGross += (m['grossSalary'] ?? 0).toDouble();
      totalNet += (m['netSalary'] ?? 0).toDouble();
    }

    return Row(
      children: [
        _StatBox(label: 'Total Net', value: _money.format(totalNet), color: const Color(0xFF065F46)),
        const SizedBox(width: 12),
        _StatBox(label: 'Gross Amount', value: _money.format(totalGross), color: const Color(0xFF16A34A)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
        ],
      ),
    ),
  );
}

class _PayrollCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PayrollCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final net = (data['netSalary'] ?? 0).toDouble();
    final gross = (data['grossSalary'] ?? 0).toDouble();
    final loan = (data['loanDeduction'] ?? 0).toDouble();

    return UCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF065F46).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(data['employeeName']?[0] ?? '?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF065F46))))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['employeeName'] ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    Text('${data['employeeId']} • ${data['department']?.toUpperCase()}', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('৳ ${_money.format(net)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF065F46))),
                  Text('NET PAYABLE', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[300])),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat(label: 'Gross', value: _money.format(gross)),
              _MiniStat(label: 'Loan Deduction', value: _money.format(loan), color: Colors.redAccent),
              _MiniStat(label: 'Other', value: '৳ 0'),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.payments_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('No payroll records found', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _GenerateForm extends StatefulWidget {
  final String cid;
  final VoidCallback onGenerated;
  const _GenerateForm({required this.cid, required this.onGenerated});
  @override
  State<_GenerateForm> createState() => _GenerateFormState();
}

class _GenerateFormState extends State<_GenerateForm> {
  final _idCtl = TextEditingController();
  final _salaryCtl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Generate Monthly Payroll', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(controller: _idCtl, decoration: InputDecoration(labelText: 'Employee ID', prefixIcon: const Icon(Icons.badge_outlined), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          TextField(controller: _salaryCtl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Gross Salary (BDT)', prefixIcon: const Icon(Icons.attach_money_rounded), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text('GENERATE PAYROLL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_idCtl.text.isEmpty || _salaryCtl.text.isEmpty) return;
    setState(() => _loading = true);
    // Real logic involves fetching user, loans, etc. simplified for brevity
    await DB.colSync(widget.cid, C.payrolls).add({
      'employeeId': _idCtl.text.trim(), 'period': DateFormat('MMMM yyyy').format(DateTime.now()), 'grossSalary': double.parse(_salaryCtl.text), 'netSalary': double.parse(_salaryCtl.text), 'generatedAt': FieldValue.serverTimestamp(),
    });
    widget.onGenerated();
  }
}
