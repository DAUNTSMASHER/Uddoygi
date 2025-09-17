import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';

const _green = Color(0xFF065F46);
const _blue  = Color(0xFF0D47A1);
const _teal  = Color(0xFF21C7A8);
const _orange = Color(0xFFFF8A00);

final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

class BudgetTablePage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? budgetDoc; // if null => create/edit this month by key
  const BudgetTablePage({super.key, this.budgetDoc});

  @override
  State<BudgetTablePage> createState() => _BudgetTablePageState();
}

class _BudgetTablePageState extends State<BudgetTablePage> {
  final _companyCtl = TextEditingController(text: 'Wig Bangladesh');
  late String _period; // e.g. "September 2025"
  DateTime? _createdAt;
  DateTime? _editableUntil;

  bool _loading = true;
  bool get _locked => _editableUntil != null && DateTime.now().isAfter(_editableUntil!);

  // Dynamic expenses
  final List<_RowItem> _rows = [];

  // Sales targets
  final List<_Target> _targets = [];

  // Agents for picker
  List<String> _agents = [];
  final Map<String, String> _emailByName = {}; // fullName -> email

  @override
  void initState() {
    super.initState();
    _period = DateFormat('MMMM yyyy').format(DateTime.now());
    _init();
  }

  // --------------------- helpers --------------------- //

  String _periodKeyFromPeriod(String period) {
    // "September 2025" -> "2025-09"
    final parts = period.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final monthName = parts[0].toLowerCase();
      const months = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
      };
      final m = months[monthName] ?? DateTime.now().month;
      final y = int.tryParse(parts[1]) ?? DateTime.now().year;
      return '${y.toString()}-${m.toString().padLeft(2, '0')}';
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
    return 0.0;
  }

  double get _totalNeed => _rows.fold(0.0, (p, e) => p + e.amountNeed);
  double get _totalMin  => _rows.fold(0.0, (p, e) => p + e.minAmount);

  List<String> get _availableAgents {
    final chosen = _targets.map((e) => e.name).toSet();
    return _agents.where((a) => !chosen.contains(a)).toList();
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // --------------------- init/load --------------------- //

  Future<void> _init() async {
    // Load agents (marketing dept) with emails
    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('department', isEqualTo: 'marketing')
        .get();

    _agents.clear();
    _emailByName.clear();
    for (final d in users.docs) {
      final m = d.data();
      final name = (m['fullName'] ?? m['name'] ?? '').toString().trim();
      final email = (m['email'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      _agents.add(name);
      if (email.isNotEmpty) _emailByName[name] = email;
    }
    _agents.sort();

    if (widget.budgetDoc == null) {
      _createdAt = DateTime.now();
      _editableUntil = _createdAt!.add(const Duration(days: 7));
      setState(() => _loading = false);
      return;
    }

    final s = await widget.budgetDoc!.get();
    if (s.exists) {
      final m = s.data()!;
      _companyCtl.text = (m['companyName'] ?? _companyCtl.text).toString();
      _period = (m['period'] ?? _period).toString();
      _createdAt = (m['createdAt'] as Timestamp?)?.toDate();
      _editableUntil = (m['editableUntil'] as Timestamp?)?.toDate();

      final items = (m['items'] as List?) ?? [];
      _rows
        ..clear()
        ..addAll(items.map((r) => _RowItem(
          (r['sl'] ?? (_rows.length + 1)) as int,
          (r['name'] ?? '').toString(),
          amountNeed: _asDouble(r['amountNeed']),
          minAmount: _asDouble(r['minAmount']),
          notes: (r['notes'] as String?)?.toString(),
        )));

      final tgs = (m['salesTargets'] as List?) ?? [];
      _targets
        ..clear()
        ..addAll(tgs.map((t) => _Target(
          name: (t['name'] ?? '').toString(),
          email: (t['email'] ?? '').toString(),
          maxTarget: _asDouble(t['maxTarget']),
          finalTarget: _asDouble(t['finalTarget']),
        )));
    } else {
      _createdAt = DateTime.now();
      _editableUntil = _createdAt!.add(const Duration(days: 7));
    }
    setState(() => _loading = false);
  }

  // --------------------- actions --------------------- //

  Future<void> _save() async {
    if (_locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locked: Budget can only be edited within 7 days of creation.')),
      );
      return;
    }

    // re-number SL in case rows were added/removed
    for (var i = 0; i < _rows.length; i++) {
      _rows[i].sl = i + 1;
    }

    // Build fast lookup for targets (what Sales screen reads first)
    final Map<String, num> idxEmail = {};  // email -> effective
    final Map<String, num> idxLower = {};  // lower(full name) -> effective
    for (final t in _targets) {
      final effective = t.finalTarget > 0 ? t.finalTarget : t.maxTarget;
      if (effective <= 0) continue;
      if ((t.email ?? '').trim().isNotEmpty) {
        idxEmail[(t.email!).toLowerCase()] = effective;
      }
      idxLower[_norm(t.name)] = effective;
    }

    final periodKey = _periodKeyFromPeriod(_period);
    final ref = FirebaseFirestore.instance.collection('budgets').doc(periodKey);

    final data = {
      'periodKey': periodKey,         // deterministic monthly id (Sales screen listens to this doc)
      'period': _period,              // human readable; Sales screen also queries by this
      'companyName': _companyCtl.text.trim(),
      'createdAt': _createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(_createdAt!),
      'editableUntil': _editableUntil == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(_editableUntil!),
      'items': _rows.map((r) => r.toMap()).toList(),
      'salesTargets': _targets.map((t) => t.toMap()).toList(), // <— includes email now
      // fast lookups used by Sales screen:
      'targetsIndexEmail': idxEmail,
      'targetsIndexLower': idxLower,
      'totalNeed': _totalNeed,
      'totalMin': _totalMin,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Upsert to monthly doc id
    await ref.set(data, SetOptions(merge: true));

    // If this is the first save and editableUntil was null -> extend to +7 days from createdAt
    if (_editableUntil == null) {
      final snap = await ref.get();
      final created = (snap.data()?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final until = created.add(const Duration(days: 7));
      await ref.update({'editableUntil': Timestamp.fromDate(until)});
      _editableUntil = until;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved ✅ Targets are live on Sales Dashboard.')),
    );
  }

  Future<void> _downloadPdf() async {
    final pdfDoc = pw.Document();
    final items = [..._rows]..sort((a, b) => a.sl.compareTo(b.sl));
    final targets = _targets;

    pdfDoc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => [
          pw.Center(
            child: pw.Text('Wig Bangladesh',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Center(
            child: pw.Text('Estimated Budget Statement & Sales Target - $_period'),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Company: ${_companyCtl.text}'),
          pw.Text('Created: ${_createdAt == null ? '—' : DateFormat('yMMMd').format(_createdAt!)}'),
          pw.SizedBox(height: 10),

          // Expenses table
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              children: [
                pw.Container(
                  color: pdf.PdfColors.grey300,
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 1, child: pw.Text('SL No')),
                    pw.Expanded(flex: 6, child: pw.Text('Particulars')),
                    pw.Expanded(flex: 3, child: pw.Text('Amount Need To Arrange (Tk)')),
                    pw.Expanded(flex: 3, child: pw.Text('Minimum Amount to pay (tk)')),
                    pw.Expanded(flex: 4, child: pw.Text('Remarks')),
                  ]),
                ),
                ...items.map((r) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 1, child: pw.Text(r.sl.toString())),
                    pw.Expanded(flex: 6, child: pw.Text(r.name)),
                    pw.Expanded(flex: 3, child: pw.Text(_money.format(r.amountNeed))),
                    pw.Expanded(flex: 3, child: pw.Text(_money.format(r.minAmount))),
                    pw.Expanded(flex: 4, child: pw.Text(r.notes ?? '')),
                  ]),
                )),
                pw.Divider(),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Row(children: [
                    pw.Expanded(
                        flex: 7,
                        child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text(_money.format(_totalNeed))),
                    pw.Expanded(flex: 3, child: pw.Text(_money.format(_totalMin))),
                    pw.Expanded(flex: 4, child: pw.Text('')),
                  ]),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Sales Target table
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all()),
            child: pw.Column(
              children: [
                pw.Container(
                  color: pdf.PdfColors.grey300,
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 1, child: pw.Text('SL')),
                    pw.Expanded(flex: 6, child: pw.Text('Name')),
                    pw.Expanded(flex: 4, child: pw.Text('Max Target: As Per System')),
                    pw.Expanded(flex: 4, child: pw.Text('Final Target')),
                  ]),
                ),
                ...List.generate(targets.length, (i) {
                  final t = targets[i];
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: pw.Row(children: [
                      pw.Expanded(flex: 1, child: pw.Text('${i + 1}')),
                      pw.Expanded(flex: 6, child: pw.Text(t.name)),
                      pw.Expanded(flex: 4, child: pw.Text(_money.format(t.maxTarget))),
                      pw.Expanded(flex: 4, child: pw.Text(_money.format(t.finalTarget))),
                    ]),
                  );
                }),
                pw.Divider(),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Row(children: [
                    pw.Expanded(
                        flex: 7,
                        child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text(_money.format(targets.fold(0.0, (p, e) => p + e.maxTarget)))),
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text(_money.format(targets.fold(0.0, (p, e) => p + e.finalTarget)))),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdfDoc.save());
  }

  // --------------------- UI --------------------- //

  @override
  void dispose() {
    _companyCtl.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt ?? now,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year + 5, 12),
      helpText: 'Pick any date in the month',
    );
    if (picked != null) {
      setState(() => _period = DateFormat('MMMM yyyy').format(picked));
    }
  }

  void _addExpenseRow() {
    if (_locked) return;
    setState(() {
      _rows.add(_RowItem(_rows.length + 1, ''));
    });
  }

  void _removeExpenseRow(int index) {
    if (_locked) return;
    setState(() {
      _rows.removeAt(index);
      // re-number
      for (var i = 0; i < _rows.length; i++) {
        _rows[i].sl = i + 1;
      }
    });
  }

  InputDecoration _sectionTitleDeco(String title, Color color, IconData icon) {
    return InputDecoration(
      labelText: title,
      labelStyle: TextStyle(
        color: color.darken(),
        fontWeight: FontWeight.w900,
      ),
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: color.withOpacity(.06),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color.withOpacity(.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color.withOpacity(.7), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _blue,
        title: Text('Budget Table • $_period', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _downloadPdf,
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _save,
          ),
        ],
      ),
      floatingActionButton: _locked
          ? null
          : FloatingActionButton.extended(
        backgroundColor: _green,
        onPressed: _addExpenseRow,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add expense', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FAFF), Color(0xFFF7FFF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
                border: Border.all(color: Colors.black12.withOpacity(.06)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _companyCtl,
                          enabled: !_locked,
                          decoration: const InputDecoration(
                            labelText: 'Company name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _locked ? null : _pickMonth,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_period),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Creation date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_createdAt == null
                              ? DateFormat('yMMMd').format(DateTime.now())
                              : DateFormat('yMMMd').format(_createdAt!)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Editable until',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_editableUntil == null
                              ? '—'
                              : DateFormat('yMMMd').format(_editableUntil!)),
                        ),
                      ),
                    ],
                  ),
                  if (_locked) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.06),
                        border: Border.all(color: Colors.red.withOpacity(.2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'This budget is locked (editable only within 7 days after creation).',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Expenses Section
            TextField(
              enabled: false,
              decoration: _sectionTitleDeco('Expenses / Payments', _green, Icons.payments_rounded),
            ),
            const SizedBox(height: 8),

            if (_rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withOpacity(.03),
                  border: Border.all(color: _green.withOpacity(.15)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('No expense rows yet. Tap “Add expense” to begin.'),
              ),

            ...List.generate(_rows.length, (i) {
              final r = _rows[i];
              return _ExpenseRow(
                key: ValueKey('exp_$i'),
                index: i,
                item: r,
                locked: _locked,
                onChanged: (_) => setState(() {}),
                onRemove: () => _removeExpenseRow(i),
              );
            }),

            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _orange.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withOpacity(.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.summarize_rounded, color: _orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total:  ${_money.format(_totalNeed)}   •   Minimum:  ${_money.format(_totalMin)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: _orange),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Sales Targets Section
            TextField(
              enabled: false,
              decoration: _sectionTitleDeco('Sales Targets (by Agent)', _teal, Icons.flag_rounded),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('agent_picker_${_targets.length}'), // helps reset selection
                    value: null, // always show prompt again after add
                    isExpanded: true,
                    items: _availableAgents
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: _locked
                        ? null
                        : (v) {
                      if (v == null || v.isEmpty) return;
                      setState(() => _targets.add(_Target(
                        name: v,
                        email: _emailByName[v], // auto-fill email
                      )));
                    },
                    decoration: const InputDecoration(
                      labelText: 'Add marketing agent',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tip',
                      border: OutlineInputBorder(),
                    ),
                    child: Text('Pick agent, then fill targets (Max / Final).'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...List.generate(_targets.length, (i) {
              final t = _targets[i];
              return _TargetRow(
                key: ValueKey('tgt_$i'),
                index: i,
                target: t,
                locked: _locked,
                onRemove: () => setState(() => _targets.removeAt(i)),
              );
            }),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF'),
                    onPressed: _downloadPdf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _blue),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Save', style: TextStyle(color: Colors.white)),
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Models & Rows -------------------- */

class _RowItem {
  int sl;
  String name;
  double amountNeed;
  double minAmount;
  String? notes;

  _RowItem(this.sl, this.name, {this.amountNeed = 0.0, this.minAmount = 0.0, this.notes});

  Map<String, dynamic> toMap() => {
    'sl': sl,
    'name': name,
    'amountNeed': amountNeed,
    'minAmount': minAmount,
    'notes': (notes == null || notes!.trim().isEmpty) ? null : notes,
  };
}

class _ExpenseRow extends StatefulWidget {
  final int index;
  final _RowItem item;
  final bool locked;
  final ValueChanged<_RowItem> onChanged;
  final VoidCallback onRemove;

  const _ExpenseRow({
    super.key,
    required this.index,
    required this.item,
    required this.locked,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends State<_ExpenseRow> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _needCtl;
  late final TextEditingController _minCtl;
  late final TextEditingController _notesCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl  = TextEditingController(text: widget.item.name);
    _needCtl  = TextEditingController(text: widget.item.amountNeed == 0 ? '' : widget.item.amountNeed.toString());
    _minCtl   = TextEditingController(text: widget.item.minAmount == 0 ? '' : widget.item.minAmount.toString());
    _notesCtl = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _needCtl.dispose();
    _minCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]+[.]?[0-9]*'))];

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // --- Row 1: SL + Name + Delete
            Row(
              children: [
                Container(
                  width: 28,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withOpacity(.25)),
                  ),
                  child: Text(widget.item.sl.toString(),
                      style: TextStyle(color: _green.darken(), fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameCtl,
                    enabled: !widget.locked,
                    decoration: _dec('Particulars / Name'),
                    onChanged: (v) {
                      widget.item.name = v;
                      widget.onChanged(widget.item);
                    },
                  ),
                ),
                if (!widget.locked) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Remove row',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onRemove,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // --- Row 2: Amounts
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _needCtl,
                    enabled: !widget.locked,
                    inputFormatters: numFmt,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Amount need'),
                    onChanged: (v) {
                      widget.item.amountNeed = double.tryParse(v) ?? 0.0;
                      widget.onChanged(widget.item);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _minCtl,
                    enabled: !widget.locked,
                    inputFormatters: numFmt,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Minimum'),
                    onChanged: (v) {
                      widget.item.minAmount = double.tryParse(v) ?? 0.0;
                      widget.onChanged(widget.item);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Row 3: Notes
            TextField(
              controller: _notesCtl,
              enabled: !widget.locked,
              decoration: _dec('Notes / Remarks (optional)'),
              onChanged: (v) {
                widget.item.notes = v.trim().isEmpty ? null : v.trim();
                widget.onChanged(widget.item);
              },
              maxLines: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Target {
  String name;
  String? email;     // NEW: used by Sales screen for exact match
  double maxTarget;
  double finalTarget;
  _Target({required this.name, this.email, this.maxTarget = 0.0, this.finalTarget = 0.0});

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': (email ?? '').trim(),  // include email in document
    'maxTarget': maxTarget,
    'finalTarget': finalTarget,
  };
}

class _TargetRow extends StatefulWidget {
  final int index;
  final _Target target;
  final bool locked;
  final VoidCallback onRemove;
  const _TargetRow({
    super.key,
    required this.index,
    required this.target,
    required this.locked,
    required this.onRemove,
  });

  @override
  State<_TargetRow> createState() => _TargetRowState();
}

class _TargetRowState extends State<_TargetRow> {
  late final TextEditingController _maxCtl;
  late final TextEditingController _finalCtl;

  @override
  void initState() {
    super.initState();
    _maxCtl = TextEditingController(text: widget.target.maxTarget == 0 ? '' : widget.target.maxTarget.toString());
    _finalCtl = TextEditingController(text: widget.target.finalTarget == 0 ? '' : widget.target.finalTarget.toString());
  }

  @override
  void didUpdateWidget(covariant _TargetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.maxTarget != widget.target.maxTarget) {
      _maxCtl.text = widget.target.maxTarget == 0 ? '' : widget.target.maxTarget.toString();
    }
    if (oldWidget.target.finalTarget != widget.target.finalTarget) {
      _finalCtl.text = widget.target.finalTarget == 0 ? '' : widget.target.finalTarget.toString();
    }
  }

  @override
  void dispose() {
    _maxCtl.dispose();
    _finalCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numFormatter = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]+[.]?[0-9]*'))];

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Agent (name + email chip if present)
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _teal.withOpacity(.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person_pin_circle_rounded, color: _teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.target.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
                    if ((widget.target.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _blue.withOpacity(.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _blue.withOpacity(.25)),
                        ),
                        child: Text(
                          widget.target.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _blue),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Max target
            Expanded(
              flex: 2,
              child: TextField(
                enabled: !widget.locked,
                controller: _maxCtl,
                inputFormatters: numFormatter,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Max Target', border: OutlineInputBorder()),
                onChanged: (v) => widget.target.maxTarget = double.tryParse(v) ?? 0.0,
              ),
            ),
            const SizedBox(width: 8),

            // Final target
            Expanded(
              flex: 2,
              child: TextField(
                enabled: !widget.locked,
                controller: _finalCtl,
                inputFormatters: numFormatter,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Final Target', border: OutlineInputBorder()),
                onChanged: (v) => widget.target.finalTarget = double.tryParse(v) ?? 0.0,
              ),
            ),
            const SizedBox(width: 8),

            if (!widget.locked)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: widget.onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- tiny color helper -------------------- */
extension on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final h = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return h.toColor();
  }
}
