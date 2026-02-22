// lib/features/hr/presentation/screens/budget_table.dart
//
// Budget Table — add/edit expense rows & sales targets for a given month.
//
// FIX: _cid is now passed in directly from BudgetPage (no async race).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdflib;
import 'package:printing/printing.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF065F46);
const Color _brandMid = Color(0xFF059669);
const Color _surface  = Color(0xFFF0FDF4);
const Color _teal     = Color(0xFF0891B2);
const Color _red      = Color(0xFFDC2626);

final _money = NumberFormat('#,##0', 'en');

// ─────────────────────────────────────────────────────────────────────────────
class BudgetTablePage extends StatefulWidget {
  /// Company ID — passed directly so there's no async race on init.
  final String cid;
  final DocumentReference<Map<String, dynamic>>? budgetDoc;

  const BudgetTablePage({super.key, required this.cid, this.budgetDoc});

  @override
  State<BudgetTablePage> createState() => _BudgetTablePageState();
}

class _BudgetTablePageState extends State<BudgetTablePage> {
  final _companyCtl = TextEditingController(text: 'Wig Bangladesh');
  late String _period;
  DateTime? _createdAt;
  DateTime? _editableUntil;

  bool _loading = true;
  bool _saving  = false;

  bool get _locked =>
      _editableUntil != null && DateTime.now().isAfter(_editableUntil!);

  final List<_RowItem> _rows    = [];
  final List<_Target>  _targets = [];

  final List<String>          _agents      = [];
  final Map<String, String> _emailByName = {};

  @override
  void initState() {
    super.initState();
    _period = DateFormat('MMMM yyyy').format(DateTime.now());
    _init();
  }

  @override
  void dispose() {
    _companyCtl.dispose();
    super.dispose();
  }

  // ── Init — uses widget.cid directly (no async race) ──────────────────────
  Future<void> _init() async {
    // 1. Load marketing agents
    try {
      final users = await DB.colSync(widget.cid, C.users)
        .where('department', isEqualTo: 'marketing')
        .get();
    _agents.clear();
    _emailByName.clear();
    for (final d in users.docs) {
        final m     = d.data();
        final name  = (m['fullName'] ?? m['name'] ?? '').toString().trim();
      final email = (m['email'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      _agents.add(name);
      if (email.isNotEmpty) _emailByName[name] = email;
    }
    _agents.sort();
    } catch (_) {
      // non-fatal — agents list stays empty
    }

    // 2. Load existing budget doc (if provided)
    if (widget.budgetDoc != null) {
      try {
    final s = await widget.budgetDoc!.get();
    if (s.exists) {
      final m = s.data()!;
      _companyCtl.text = (m['companyName'] ?? _companyCtl.text).toString();
          _period          = (m['period']      ?? _period).toString();
          _createdAt       = (m['createdAt']   as Timestamp?)?.toDate();
          _editableUntil   = (m['editableUntil'] as Timestamp?)?.toDate();

      final items = (m['items'] as List?) ?? [];
      _rows
        ..clear()
        ..addAll(items.map((r) => _RowItem(
          (r['sl'] ?? (_rows.length + 1)) as int,
          (r['name'] ?? '').toString(),
          amountNeed: _asDouble(r['amountNeed']),
              minAmount:  _asDouble(r['minAmount']),
              notes:      r['notes'] as String?,
        )));

      final tgs = (m['salesTargets'] as List?) ?? [];
      _targets
        ..clear()
        ..addAll(tgs.map((t) => _Target(
              name:        (t['name']  ?? '').toString(),
              email:       t['email'] as String?,
              maxTarget:   _asDouble(t['maxTarget']),
          finalTarget: _asDouble(t['finalTarget']),
        )));
    } else {
          _setDefaults();
        }
      } catch (_) {
        _setDefaults();
      }
    } else {
      _setDefaults();
    }

    if (mounted) setState(() => _loading = false);
  }

  void _setDefaults() {
    _createdAt     = DateTime.now();
    _editableUntil = _createdAt!.add(const Duration(days: 30));
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

  String _periodKey() {
    final parts = _period.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      const months = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4,
        'may': 5, 'june': 6, 'july': 7, 'august': 8,
        'september': 9, 'october': 10, 'november': 11, 'december': 12,
      };
      final m = months[parts[0].toLowerCase()] ?? DateTime.now().month;
      final y = int.tryParse(parts[1]) ?? DateTime.now().year;
      return '$y-${m.toString().padLeft(2, '0')}';
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_locked) {
      _snack('Budget is locked — cannot edit after the editable period.');
      return;
    }
    setState(() => _saving = true);
    try {
    for (var i = 0; i < _rows.length; i++) {
      _rows[i].sl = i + 1;
    }

      final Map<String, num> idxEmail = {};
      final Map<String, num> idxLower = {};
    for (final t in _targets) {
      final effective = t.finalTarget > 0 ? t.finalTarget : t.maxTarget;
      if (effective <= 0) continue;
      if ((t.email ?? '').trim().isNotEmpty) {
          idxEmail[t.email!.toLowerCase()] = effective;
      }
      idxLower[_norm(t.name)] = effective;
    }

      final key = _periodKey();
      final ref = DB.colSync(widget.cid, C.budgets).doc(key);

      await ref.set({
        'periodKey':          key,
        'period':             _period,
        'companyName':        _companyCtl.text.trim(),
        'createdAt':          _createdAt == null
          ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(_createdAt!),
        'editableUntil':      _editableUntil == null
            ? Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)))
          : Timestamp.fromDate(_editableUntil!),
        'items':              _rows.map((r) => r.toMap()).toList(),
        'salesTargets':       _targets.map((t) => t.toMap()).toList(),
        'targetsIndexEmail':  idxEmail,
        'targetsIndexLower':  idxLower,
        'totalNeed':          _totalNeed,
        'totalMin':           _totalMin,
        'updatedAt':          FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _snack('Budget saved ✅  Sales targets are live.');
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _red : _brand,
    ));
  }

  // ── PDF ───────────────────────────────────────────────────────────────────
  Future<void> _downloadPdf() async {
    final items   = [..._rows]..sort((a, b) => a.sl.compareTo(b.sl));
    final targets = _targets;
    final now     = DateTime.now();
    final dateFmt = DateFormat('d MMMM yyyy');

    final headerBg  = const pdflib.PdfColor.fromInt(0xFF065F46);
    final rowAlt    = const pdflib.PdfColor.fromInt(0xFFF0FDF4);
    final lineClr   = const pdflib.PdfColor.fromInt(0xFFD1FAE5);
    final textMuted = const pdflib.PdfColor.fromInt(0xFF6B7280);

    final pdfDoc = pw.Document(
      theme: pw.ThemeData.withFont(
        base:       pw.Font.times(),
        bold:       pw.Font.timesBold(),
        italic:     pw.Font.timesItalic(),
        boldItalic: pw.Font.timesBoldItalic(),
      ),
    );

    pdfDoc.addPage(pw.MultiPage(
      pageFormat: pdflib.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
      header: (ctx) => pw.Column(children: [
          pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: pw.BoxDecoration(color: headerBg),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BUDGET STATEMENT — $_period',
                      style: pw.TextStyle(
                          font: pw.Font.timesBold(),
                          fontSize: 14,
                          color: pdflib.PdfColors.white)),
                  pw.SizedBox(height: 3),
                  pw.Text(_companyCtl.text,
                      style: pw.TextStyle(
                          font: pw.Font.timesItalic(),
                          fontSize: 10,
                          color: pdflib.PdfColors.white)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated: ${dateFmt.format(now)}',
                      style: pw.TextStyle(
                          font: pw.Font.times(),
                          fontSize: 9,
                          color: pdflib.PdfColors.white)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: pw.TextStyle(
                          font: pw.Font.times(),
                          fontSize: 9,
                          color: pdflib.PdfColors.white)),
                ],
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 10),
      ]),
      footer: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: lineClr, width: 0.5))),
        child: pw.Text('Confidential — HR Department',
            style: pw.TextStyle(
                font: pw.Font.timesItalic(),
                fontSize: 8,
                color: textMuted)),
      ),
      build: (_) => [
        // KPI row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _pdfKpi('Total Budget Need', '৳ ${_money.format(_totalNeed)}',
                const pdflib.PdfColor.fromInt(0xFF065F46)),
            _pdfKpi('Minimum Required', '৳ ${_money.format(_totalMin)}',
                const pdflib.PdfColor.fromInt(0xFF0891B2)),
            _pdfKpi('Expense Items', '${items.length}',
                const pdflib.PdfColor.fromInt(0xFFD97706)),
            _pdfKpi('Sales Targets', '${targets.length}',
                const pdflib.PdfColor.fromInt(0xFF7C3AED)),
          ],
        ),
        pw.SizedBox(height: 16),

        // Expenses table
        pw.Text('Expense / Payment Items',
            style: pw.TextStyle(
                font: pw.Font.timesBold(), fontSize: 13,
                color: const pdflib.PdfColor.fromInt(0xFF065F46))),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: lineClr, width: 0.5)),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2.5),
            3: const pw.FlexColumnWidth(2.5),
            4: const pw.FlexColumnWidth(3),
          },
              children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: ['#', 'Particulars', 'Amount Need (৳)', 'Minimum (৳)', 'Remarks']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                font: pw.Font.timesBold(),
                                fontSize: 9,
                                color: pdflib.PdfColors.white)),
                      ))
                  .toList(),
            ),
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? rowAlt : pdflib.PdfColors.white),
                children: [
                  r.sl.toString(),
                  r.name,
                  _money.format(r.amountNeed),
                  _money.format(r.minAmount),
                  r.notes ?? '',
                ]
                    .map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Text(cell,
                              style: pw.TextStyle(
                                  font: pw.Font.times(), fontSize: 8)),
                        ))
                    .toList(),
                  );
                }),
            // Total row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: [
                '',
                'TOTAL',
                _money.format(_totalNeed),
                _money.format(_totalMin),
                '',
              ]
                  .map((cell) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        child: pw.Text(cell,
                            style: pw.TextStyle(
                                font: pw.Font.timesBold(),
                                fontSize: 9,
                                color: pdflib.PdfColors.white)),
                      ))
                  .toList(),
                ),
              ],
            ),
        pw.SizedBox(height: 16),

        // Sales targets table
        if (targets.isNotEmpty) ...[
          pw.Text('Sales Targets by Agent',
              style: pw.TextStyle(
                  font: pw.Font.timesBold(), fontSize: 13,
                  color: const pdflib.PdfColor.fromInt(0xFF0891B2))),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder(
                horizontalInside:
                    pw.BorderSide(color: lineClr, width: 0.5)),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: const pdflib.PdfColor.fromInt(0xFF0891B2)),
                children: ['#', 'Agent Name', 'Max Target (৳)', 'Final Target (৳)']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  font: pw.Font.timesBold(),
                                  fontSize: 9,
                                  color: pdflib.PdfColors.white)),
                        ))
                    .toList(),
              ),
              ...targets.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isOdd ? rowAlt : pdflib.PdfColors.white),
                  children: [
                    '${i + 1}',
                    t.name,
                    _money.format(t.maxTarget),
                    _money.format(t.finalTarget),
                  ]
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            child: pw.Text(cell,
                                style: pw.TextStyle(
                                    font: pw.Font.times(), fontSize: 8)),
                          ))
                      .toList(),
                );
              }),
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: const pdflib.PdfColor.fromInt(0xFF0891B2)),
                children: [
                  '',
                  'TOTAL',
                  _money.format(
                      targets.fold(0.0, (p, t) => p + t.maxTarget)),
                  _money.format(
                      targets.fold(0.0, (p, t) => p + t.finalTarget)),
                ]
                    .map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          child: pw.Text(cell,
                              style: pw.TextStyle(
                                  font: pw.Font.timesBold(),
                                  fontSize: 9,
                                  color: pdflib.PdfColors.white)),
                        ))
                    .toList(),
          ),
        ],
      ),
        ],
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) => pdfDoc.save());
  }

  // ── Period picker ─────────────────────────────────────────────────────────
  Future<void> _pickMonth() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt ?? now,
      firstDate: DateTime(now.year - 5, 1),
      lastDate:  DateTime(now.year + 5, 12),
      helpText:  'Pick any date in the target month',
    );
    if (picked != null) {
      setState(() => _period = DateFormat('MMMM yyyy').format(picked));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _brand)),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _brandMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text('Budget — $_period',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _downloadPdf,
          ),
          if (!_locked)
          IconButton(
            tooltip: 'Save',
              icon: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              onPressed: _saving ? null : _save,
          ),
        ],
      ),

      floatingActionButton: _locked
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => setState(() {
                _rows.add(_RowItem(_rows.length + 1, ''));
              }),
            ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
          // ── Header card ────────────────────────────────────────────────
          _SectionCard(
              child: Column(
                children: [
                Row(children: [
                      Expanded(
                    child: _InputField(
                          controller: _companyCtl,
                      label: 'Company Name',
                      icon: Icons.business_rounded,
                          enabled: !_locked,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                    child: GestureDetector(
                          onTap: _locked ? null : _pickMonth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: _locked
                              ? Colors.black.withValues(alpha: 0.03)
                              : _surface,
                          border: Border.all(
                              color: _brand.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16,
                              color: _locked ? Colors.black26 : _brand),
                          const SizedBox(width: 8),
                      Expanded(
                            child: Text(_period,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _locked
                                        ? Colors.black38
                                        : _brand)),
                          ),
                          if (!_locked)
                            Icon(Icons.arrow_drop_down_rounded,
                                color: _brand),
                        ]),
                      ),
                    ),
                  ),
                ]),
                  if (_locked) ...[
                    const SizedBox(height: 10),
                    Container(
                    padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.06),
                      border: Border.all(
                          color: _red.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    child: Row(children: [
                      const Icon(Icons.lock_rounded,
                          color: _red, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This budget is locked — the editable period has passed.',
                          style: TextStyle(
                              color: _red, fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                    ]),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

          // ── Summary card ───────────────────────────────────────────────
              Container(
            padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brand, _brandMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _brand.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              Expanded(
                child: _SumStat(
                  label: 'Total Need',
                  value: '৳ ${_money.format(_totalNeed)}',
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            Container(
                  width: 1, height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
              Expanded(
                child: _SumStat(
                  label: 'Minimum',
                  value: '৳ ${_money.format(_totalMin)}',
                  icon: Icons.savings_rounded,
                ),
              ),
              Container(
                  width: 1, height: 40,
                  color: Colors.white.withValues(alpha: 0.2)),
                  Expanded(
                child: _SumStat(
                  label: 'Items',
                  value: '${_rows.length}',
                  icon: Icons.list_alt_rounded,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Expense rows section ───────────────────────────────────────
          _SectionHeader(
            icon: Icons.payments_rounded,
            title: 'Expense / Payment Items',
            color: _brand,
            trailing: !_locked
                ? TextButton.icon(
                    onPressed: () => setState(() {
                      _rows.add(_RowItem(_rows.length + 1, ''));
                    }),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(foregroundColor: _brand),
                  )
                : null,
          ),
          const SizedBox(height: 8),

          if (_rows.isEmpty)
            _EmptySection(
              message: 'No expense items yet',
              sub: _locked
                  ? 'Budget is locked'
                  : 'Tap "Add Item" or the button above',
            )
          else
            ...List.generate(_rows.length, (i) => _ExpenseRow(
              key:       ValueKey('exp_$i'),
              index:     i,
              item:      _rows[i],
              locked:    _locked,
              onChanged: (_) => setState(() {}),
              onRemove:  () => setState(() {
                _rows.removeAt(i);
                for (var j = 0; j < _rows.length; j++) {
                  _rows[j].sl = j + 1;
                }
              }),
            )),

          const SizedBox(height: 20),

          // ── Sales targets section ──────────────────────────────────────
          _SectionHeader(
            icon: Icons.flag_rounded,
            title: 'Sales Targets by Agent',
            color: _teal,
            ),
            const SizedBox(height: 8),

          // Agent picker
          if (!_locked && _availableAgents.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.05),
                border: Border.all(color: _teal.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: null,
                    isExpanded: true,
                  hint: const Text('Add marketing agent…',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _teal)),
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: _teal),
                    items: _availableAgents
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(n),
                          ))
                        .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                      setState(() => _targets.add(_Target(
                      name:  v,
                      email: _emailByName[v],
                      )));
                    },
                    ),
                  ),
                ),

          if (_targets.isEmpty)
            _EmptySection(
              message: 'No sales targets set',
              sub: _locked
                  ? 'Budget is locked'
                  : 'Pick an agent from the dropdown above',
            )
          else
            ...List.generate(_targets.length, (i) => _TargetRow(
              key:     ValueKey('tgt_$i'),
              index:   i,
              target:  _targets[i],
              locked:  _locked,
                onRemove: () => setState(() => _targets.removeAt(i)),
            )),

          const SizedBox(height: 24),

          // ── Action buttons ─────────────────────────────────────────────
          Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: const BorderSide(color: _brand),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Download PDF',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: _downloadPdf,
                  ),
                ),
            if (!_locked) ...[
                const SizedBox(width: 12),
                Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save Budget',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPENSE ROW WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _ExpenseRow extends StatefulWidget {
  final int      index;
  final _RowItem item;
  final bool     locked;
  final ValueChanged<_RowItem> onChanged;
  final VoidCallback           onRemove;

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
    _needCtl  = TextEditingController(
        text: widget.item.amountNeed == 0 ? '' : widget.item.amountNeed.toString());
    _minCtl   = TextEditingController(
        text: widget.item.minAmount == 0 ? '' : widget.item.minAmount.toString());
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

  @override
  Widget build(BuildContext context) {
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]+[.]?[0-9]*'))];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
      color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brand.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
        child: Column(
          children: [
          // Row 1: SL + Name + Delete
          Row(children: [
                Container(
              width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${widget.item.sl}',
                  style: const TextStyle(
                      color: _brand, fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
            const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtl,
                    enabled: !widget.locked,
                decoration: _dec('Particulars / Description'),
                    onChanged: (v) {
                      widget.item.name = v;
                      widget.onChanged(widget.item);
                    },
                  ),
                ),
                if (!widget.locked) ...[
                  const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: _red, size: 16),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 10),

          // Row 2: Amounts
          Row(children: [
                Expanded(
                  child: TextField(
                    controller: _needCtl,
                    enabled: !widget.locked,
                    inputFormatters: numFmt,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec('Amount Need (৳)'),
                    onChanged: (v) {
                      widget.item.amountNeed = double.tryParse(v) ?? 0.0;
                      widget.onChanged(widget.item);
                    },
                  ),
                ),
            const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _minCtl,
                    enabled: !widget.locked,
                    inputFormatters: numFmt,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec('Minimum (৳)'),
                    onChanged: (v) {
                      widget.item.minAmount = double.tryParse(v) ?? 0.0;
                      widget.onChanged(widget.item);
                    },
                  ),
                ),
          ]),
          const SizedBox(height: 10),

          // Row 3: Notes
            TextField(
              controller: _notesCtl,
              enabled: !widget.locked,
            decoration: _dec('Remarks (optional)'),
              onChanged: (v) {
                widget.item.notes = v.trim().isEmpty ? null : v.trim();
                widget.onChanged(widget.item);
              },
              maxLines: null,
            ),
          ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TARGET ROW WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _TargetRow extends StatefulWidget {
  final int      index;
  final _Target  target;
  final bool     locked;
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
    _maxCtl   = TextEditingController(
        text: widget.target.maxTarget == 0 ? '' : widget.target.maxTarget.toString());
    _finalCtl = TextEditingController(
        text: widget.target.finalTarget == 0 ? '' : widget.target.finalTarget.toString());
  }

  @override
  void dispose() {
    _maxCtl.dispose();
    _finalCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]+[.]?[0-9]*'))];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
      color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Agent info
            Expanded(
              flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                Container(
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${widget.index + 1}',
                      style: const TextStyle(
                          color: _teal, fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
                      const SizedBox(width: 8),
                      Expanded(
                  child: Text(widget.target.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ]),
                    if ((widget.target.email ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const SizedBox(width: 38),
                  Expanded(
                    child: Text(widget.target.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black38)),
                        ),
                ]),
                    ],
                  ],
                ),
              ),
        const SizedBox(width: 10),

            // Max target
            Expanded(
              flex: 2,
              child: TextField(
                enabled: !widget.locked,
                controller: _maxCtl,
            inputFormatters: numFmt,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Max (৳)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
            ),
            onChanged: (v) =>
                widget.target.maxTarget = double.tryParse(v) ?? 0.0,
              ),
            ),
            const SizedBox(width: 8),

            // Final target
            Expanded(
              flex: 2,
              child: TextField(
                enabled: !widget.locked,
                controller: _finalCtl,
            inputFormatters: numFmt,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Final (৳)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
            ),
            onChanged: (v) =>
                widget.target.finalTarget = double.tryParse(v) ?? 0.0,
              ),
            ),
            const SizedBox(width: 8),

            if (!widget.locked)
          GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  color: _red, size: 16),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _RowItem {
  int     sl;
  String  name;
  double  amountNeed;
  double  minAmount;
  String? notes;

  _RowItem(this.sl, this.name,
      {this.amountNeed = 0.0, this.minAmount = 0.0, this.notes});

  Map<String, dynamic> toMap() => {
        'sl':         sl,
        'name':       name,
        'amountNeed': amountNeed,
        'minAmount':  minAmount,
        'notes': (notes == null || notes!.trim().isEmpty) ? null : notes,
      };
}

class _Target {
  String  name;
  String? email;
  double  maxTarget;
  double  finalTarget;

  _Target({
    required this.name,
    this.email,
    this.maxTarget   = 0.0,
    this.finalTarget = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'name':        name,
        'email':       (email ?? '').trim(),
        'maxTarget':   maxTarget,
        'finalTarget': finalTarget,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  final IconData   icon;
  final String     title;
  final Color      color;
  final Widget?    trailing;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ),
        if (trailing != null) trailing!,
      ]);
}

class _SumStat extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  const _SumStat(
      {required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10)),
        ],
      );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final bool                  enabled;
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled:    enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _brand, size: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      );
}

class _EmptySection extends StatelessWidget {
  final String message;
  final String sub;
  const _EmptySection({required this.message, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            const Icon(Icons.inbox_rounded,
                size: 40, color: Colors.black12),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black38)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black26)),
          ],
        ),
      );
}

// ── PDF KPI box ───────────────────────────────────────────────────────────────
pw.Widget _pdfKpi(String label, String value, pdflib.PdfColor color) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
            color: const pdflib.PdfColor.fromInt(0xFFD1FAE5), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: pw.Font.times(),
                  fontSize: 8,
                  color: const pdflib.PdfColor.fromInt(0xFF6B7280))),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  font: pw.Font.timesBold(), fontSize: 13, color: color)),
        ],
      ),
    );
