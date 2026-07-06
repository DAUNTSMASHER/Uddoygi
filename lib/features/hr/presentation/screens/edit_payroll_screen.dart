// lib/features/hr/presentation/screens/edit_payroll_screen.dart
//
// Edit Payroll Screen — Screen 3 of 3
// Individual employee payroll editor with live recalculation
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _green    = Color(0xFF25BC5F);
const Color _greenDk  = Color(0xFF065F46);
const Color _greenLt  = Color(0xFFD1FAE5);
const Color _bg       = Color(0xFFF7F9FC);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);
const Color _danger   = Color(0xFFDC2626);

// ── Earning / Deduction entry model ──────────────────────────────────────────
class _Entry {
  String label;
  String subtitle;
  TextEditingController ctl;
  bool isDeduction;

  _Entry({
    required this.label,
    required this.subtitle,
    required double amount,
    this.isDeduction = false,
  }) : ctl = TextEditingController(
            text: amount > 0 ? amount.toStringAsFixed(0) : '');

  double get amount => double.tryParse(ctl.text.replaceAll(',', '')) ?? 0;

  void dispose() => ctl.dispose();
}

class EditPayrollScreen extends StatefulWidget {
  final String docId;
  final String cid;
  final String period;

  const EditPayrollScreen({
    super.key,
    required this.docId,
    required this.cid,
    required this.period,
  });

  @override
  State<EditPayrollScreen> createState() => _EditPayrollScreenState();
}

class _EditPayrollScreenState extends State<EditPayrollScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving  = false;

  final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

  // Earnings list
  final List<_Entry> _earnings = [];
  // Deductions list
  final List<_Entry> _deductions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final e in _earnings)   { e.dispose(); }
    for (final d in _deductions) { d.dispose(); }
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  Future<void> _loadData() async {
    try {
      final doc = await DB.colSync(widget.cid, C.payrolls)
          .doc(widget.docId)
          .get();
      if (!doc.exists || !mounted) return;

      final m = doc.data()!;
      setState(() {
        _data = m;
        _loading = false;
      });

      // Build earnings
      _earnings.clear();
      _earnings.add(_Entry(
        label: 'Base Salary',
        subtitle: 'Regular',
        amount: _num(m['grossSalary']),
      ));
      if (_num(m['bonus']) > 0) {
        _earnings.add(_Entry(
          label: 'Bonus',
          subtitle: 'Performance',
          amount: _num(m['bonus']),
        ));
      }

      // Build deductions
      _deductions.clear();
      if (_num(m['loanDeduction']) > 0) {
        _deductions.add(_Entry(
          label: 'Loan Deduction',
          subtitle: 'EMI',
          amount: _num(m['loanDeduction']),
          isDeduction: true,
        ));
      }
      // Extra deductions stored in 'extraDeductions' array
      final extras = (m['extraDeductions'] as List?)?.cast<Map>() ?? [];
      for (final ex in extras) {
        _deductions.add(_Entry(
          label: (ex['label'] ?? 'Deduction').toString(),
          subtitle: (ex['subtitle'] ?? '').toString(),
          amount: _num(ex['amount']),
          isDeduction: true,
        ));
      }

      // Listen to changes for live recalculation
      for (final e in [..._earnings, ..._deductions]) {
        e.ctl.addListener(() => setState(() {}));
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Live calculations ─────────────────────────────────────────────────────

  double get _totalGross =>
      _earnings.fold(0, (s, e) => s + e.amount);

  double get _totalDeductions =>
      _deductions.fold(0, (s, e) => s + e.amount);

  double get _netPay =>
      (_totalGross - _totalDeductions).clamp(0, double.infinity);

  // ── Add earning / deduction ───────────────────────────────────────────────

  void _addEarning() {
    _showAddEntrySheet(isDeduction: false);
  }

  void _addDeduction() {
    _showAddEntrySheet(isDeduction: true);
  }

  void _showAddEntrySheet({required bool isDeduction}) {
    final labelCtl    = TextEditingController();
    final subtitleCtl = TextEditingController();
    final amountCtl   = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isDeduction ? 'Add Deduction' : 'Add Earning',
                style: AppFonts.banglaHeading(
                    fontWeight: FontWeight.w700, fontSize: 16, color: _fg)),
            const SizedBox(height: 16),
            _SheetField(label: 'Label', hint: 'e.g. Overtime', ctl: labelCtl),
            const SizedBox(height: 10),
            _SheetField(
                label: 'Note (optional)',
                hint: 'e.g. Extra hours',
                ctl: subtitleCtl),
            const SizedBox(height: 10),
            _SheetField(
              label: 'Amount (৳)',
              hint: '0',
              ctl: amountCtl,
              numeric: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDeduction ? _danger : _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final amt =
                      double.tryParse(amountCtl.text.trim()) ?? 0;
                  if (labelCtl.text.trim().isEmpty || amt <= 0) return;
                  Navigator.pop(ctx);
                  final entry = _Entry(
                    label: labelCtl.text.trim(),
                    subtitle: subtitleCtl.text.trim(),
                    amount: amt,
                    isDeduction: isDeduction,
                  );
                  entry.ctl.addListener(() => setState(() {}));
                  setState(() {
                    if (isDeduction) {
                      _deductions.add(entry);
                    } else {
                      _earnings.add(entry);
                    }
                  });
                },
                child: Text('Add',
                    style: AppFonts.banglaHeading(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Remove entry ──────────────────────────────────────────────────────────

  void _removeEntry(List<_Entry> list, int index) {
    setState(() {
      list[index].dispose();
      list.removeAt(index);
    });
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void _reset() {
    for (final e in _earnings)   { e.dispose(); }
    for (final d in _deductions) { d.dispose(); }
    _earnings.clear();
    _deductions.clear();
    setState(() => _loading = true);
    _loadData();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final baseSalary = _earnings.isNotEmpty ? _earnings.first.amount : 0.0;
      final bonus = _earnings.length > 1
          ? _earnings.skip(1).fold(0.0, (s, e) => s + e.amount)
          : 0.0;
      final loanDeduction = _deductions
          .where((d) => d.label.toLowerCase().contains('loan'))
          .fold(0.0, (s, e) => s + e.amount);
      final extraDeductions = _deductions
          .where((d) => !d.label.toLowerCase().contains('loan'))
          .map((d) => {
                'label': d.label,
                'subtitle': d.subtitle,
                'amount': d.amount,
              })
          .toList();

      await DB.colSync(widget.cid, C.payrolls)
          .doc(widget.docId)
          .update({
        'grossSalary':     baseSalary,
        'bonus':           bonus,
        'loanDeduction':   loanDeduction,
        'extraDeductions': extraDeductions,
        'netSalary':       _netPay,
        'updatedAt':       FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Payroll record saved successfully.'),
        ]),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: _danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _card,
          foregroundColor: _fg,
          elevation: 0,
          title: Text('Edit Payroll',
              style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
        ),
        body: const Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _card,
          foregroundColor: _fg,
          elevation: 0,
          title: Text('Edit Payroll',
              style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Text('Record not found.',
              style: AppFonts.banglaBody(color: _muted)),
        ),
      );
    }

    final m        = _data!;
    final name     = (m['employeeName'] ?? 'Unknown').toString();
    final dept     = (m['department']   ?? '').toString();
    final status   = (m['status']       ?? 'pending').toString();
    final photo    = (m['profilePhotoUrl'] ?? '').toString();
    final initials = _initials(name);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Payroll',
            style: AppFonts.banglaHeading(
                fontWeight: FontWeight.w700, fontSize: 17, color: _fg)),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text('Reset',
                style: AppFonts.banglaBody(
                    color: _green,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                // ── Employee header ──────────────────────────────────
                _EmployeeHeader(
                  name: name,
                  dept: dept,
                  status: status,
                  photo: photo,
                  initials: initials,
                ),
                const SizedBox(height: 16),

                // ── Summary totals ───────────────────────────────────
                _SummaryTotalsCard(
                  gross: _totalGross,
                  deductions: _totalDeductions,
                  net: _netPay,
                  money: _money,
                ),
                const SizedBox(height: 16),

                // ── Earnings section ─────────────────────────────────
                _SectionCard(
                  title: 'Earnings',
                  child: Column(children: [
                    ..._earnings.asMap().entries.map((e) => _EntryRow(
                          entry: e.value,
                          isDeduction: false,
                          onRemove: e.key > 0
                              ? () => _removeEntry(_earnings, e.key)
                              : null,
                          onChanged: () => setState(() {}),
                        )),
                    const SizedBox(height: 4),
                    _AddRowButton(
                      label: '+ Add Earning',
                      color: _green,
                      onTap: _addEarning,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Deductions section ───────────────────────────────
                _SectionCard(
                  title: 'Deductions & Taxes',
                  child: Column(children: [
                    ..._deductions.asMap().entries.map((e) => _EntryRow(
                          entry: e.value,
                          isDeduction: true,
                          onRemove: () => _removeEntry(_deductions, e.key),
                          onChanged: () => setState(() {}),
                        )),
                    if (_deductions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No deductions',
                            style: AppFonts.banglaBody(
                                color: _muted, fontSize: 13)),
                      ),
                    const SizedBox(height: 4),
                    _AddRowButton(
                      label: 'Add Deduction',
                      color: _danger,
                      onTap: _addDeduction,
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Bottom action bar ────────────────────────────────────────
          _SaveBar(
            netPay: _netPay,
            money: _money,
            saving: _saving,
            onSave: _save,
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ── Employee Header ───────────────────────────────────────────────────────────
class _EmployeeHeader extends StatelessWidget {
  final String name, dept, status, photo, initials;
  const _EmployeeHeader({
    required this.name,
    required this.dept,
    required this.status,
    required this.photo,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status != 'inactive';
    return Column(children: [
      // Avatar
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _greenLt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withValues(alpha: 0.3), width: 2),
        ),
        child: photo.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(photo, fit: BoxFit.cover))
            : Center(
                child: Text(initials,
                    style: AppFonts.banglaHeading(
                        color: _greenDk,
                        fontWeight: FontWeight.w800,
                        fontSize: 22)),
              ),
      ),
      const SizedBox(height: 10),
      Text(name,
          style: AppFonts.banglaHeading(
              fontWeight: FontWeight.w800, fontSize: 18, color: _fg)),
      const SizedBox(height: 2),
      Text(dept.isNotEmpty ? dept : 'Employee',
          style: AppFonts.banglaBody(color: _muted, fontSize: 13)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? _green.withValues(alpha: 0.1)
              : _danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: isActive
                  ? _green.withValues(alpha: 0.3)
                  : _danger.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            isActive
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 13,
            color: isActive ? _green : _danger,
          ),
          const SizedBox(width: 5),
          Text(isActive ? 'Active' : 'Inactive',
              style: AppFonts.banglaHeading(
                  color: isActive ? _green : _danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ]),
      ),
    ]);
  }
}

// ── Summary Totals Card ───────────────────────────────────────────────────────
class _SummaryTotalsCard extends StatelessWidget {
  final double gross, deductions, net;
  final NumberFormat money;
  const _SummaryTotalsCard({
    required this.gross,
    required this.deductions,
    required this.net,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _TotalCell(label: 'GROSS', value: money.format(gross), color: _fg),
        Container(width: 1, height: 36, color: _border),
        _TotalCell(
            label: 'DEDUCTIONS',
            value: deductions > 0 ? '-${money.format(deductions)}' : '৳0',
            color: deductions > 0 ? _danger : _muted),
        Container(width: 1, height: 36, color: _border),
        _TotalCell(label: 'NET', value: money.format(net), color: _green),
      ]),
    );
  }
}

class _TotalCell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TotalCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label,
            style: AppFonts.banglaHeading(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(value,
              style: AppFonts.banglaData(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color)),
        ),
      ]),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title,
                style: AppFonts.banglaHeading(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _fg)),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Entry Row (earning or deduction) ─────────────────────────────────────────
class _EntryRow extends StatelessWidget {
  final _Entry entry;
  final bool isDeduction;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _EntryRow({
    required this.entry,
    required this.isDeduction,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.label,
                  style: AppFonts.banglaHeading(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _fg)),
              if (entry.subtitle.isNotEmpty)
                Text(entry.subtitle,
                    style: AppFonts.banglaBody(
                        color: _muted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Amount prefix
        Text(
          isDeduction ? '-৳' : '৳',
          style: AppFonts.banglaBody(
              color: isDeduction ? _danger : _muted,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        const SizedBox(width: 4),
        // Amount input
        SizedBox(
          width: 90,
          child: TextField(
            controller: entry.ctl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.right,
            style: AppFonts.banglaHeading(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDeduction ? _danger : _fg),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppFonts.banglaBody(color: _muted, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 16, color: _muted),
          ),
        ],
      ]),
    );
  }
}

// ── Add Row Button ────────────────────────────────────────────────────────────
class _AddRowButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AddRowButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(Icons.add_circle_outline_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: AppFonts.banglaBody(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ]),
    );
  }
}

// ── Sheet Field ───────────────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctl;
  final bool numeric;
  const _SheetField({
    required this.label,
    required this.hint,
    required this.ctl,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppFonts.banglaBody(
                fontSize: 12, fontWeight: FontWeight.w600, color: _fg)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          inputFormatters:
              numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: AppFonts.banglaBody(fontSize: 14, color: _fg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppFonts.banglaBody(color: _muted, fontSize: 14),
            filled: true,
            fillColor: _bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

// ── Save Bar ──────────────────────────────────────────────────────────────────
class _SaveBar extends StatelessWidget {
  final double netPay;
  final NumberFormat money;
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({
    required this.netPay,
    required this.money,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Updated Net Pay',
                  style: AppFonts.banglaBody(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(money.format(netPay),
                  style: AppFonts.banglaData(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _fg)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Save Payroll Record',
                      style: AppFonts.banglaHeading(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
