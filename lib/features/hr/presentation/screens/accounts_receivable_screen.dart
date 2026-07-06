// lib/features/hr/presentation/screens/accounts_receivable_screen.dart
//
// Expenses Screen — full CRUD + PDF export
//  • Add, Edit, Delete expense entries
//  • Filter by period (this month / last month / custom range) and category
//  • Download PDF report for any date range
//  • History: last 12 months, drillable
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF065F46); // HR Green
const Color _brandMid = Color(0xFF059669); // Emerald
const Color _surface  = Color(0xFFF8FAFC); // Slate 50
const Color _red      = Color(0xFFDC2626);


const _categories = <String>[
  'Rent', 'Utilities', 'Payroll', 'Supplies',
  'Maintenance', 'Transport', 'Marketing', 'Other',
];

const _costCenters = <String>['HR', 'Factory', 'Marketing', 'Accounts', 'R&D'];

// ── Category icon + colour map ────────────────────────────────────────────────
IconData _catIcon(String cat) {
  switch (cat) {
    case 'Rent':        return Icons.home_work_rounded;
    case 'Utilities':   return Icons.bolt_rounded;
    case 'Payroll':     return Icons.people_rounded;
    case 'Supplies':    return Icons.inventory_2_rounded;
    case 'Maintenance': return Icons.build_rounded;
    case 'Transport':   return Icons.local_shipping_rounded;
    case 'Marketing':   return Icons.campaign_rounded;
    default:            return Icons.receipt_long_rounded;
  }
}

Color _catColor(String cat) {
  switch (cat) {
    case 'Rent':        return const Color(0xFF7C3AED);
    case 'Utilities':   return const Color(0xFF0891B2);
    case 'Payroll':     return const Color(0xFF065F46);
    case 'Supplies':    return const Color(0xFFD97706);
    case 'Maintenance': return const Color(0xFFDC2626);
    case 'Transport':   return const Color(0xFF2563EB);
    case 'Marketing':   return const Color(0xFFDB2777);
    default:            return _brand;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _cid = '';
  final _money   = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('d MMM yyyy');

  late DateTime _periodStart;
  late DateTime _periodEnd;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  Query _query() => DB.colSync(_cid, C.expenses)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .orderBy('dueDate');

  // ── PDF export ──────────────────────────────────────────────────────────────
  Future<void> _exportPdf(List<QueryDocumentSnapshot> docs) async {
    final numFmt  = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');
    final now     = DateTime.now();

    num total = 0;
    for (final d in docs) {
      total += _n((d.data() as Map<String, dynamic>)['amount']);
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base:       pw.Font.times(),
        bold:       pw.Font.timesBold(),
        italic:     pw.Font.timesItalic(),
        boldItalic: pw.Font.timesBoldItalic(),
      ),
    );

    final headerBg  = const PdfColor.fromInt(0xFF065F46);
    final rowAlt    = const PdfColor.fromInt(0xFFF0FDF4);
    final lineClr   = const PdfColor.fromInt(0xFFDCFCE7);
    final textDark  = const PdfColor.fromInt(0xFF064E3B);
    final textMuted = const PdfColor.fromInt(0xFF6B7280);


    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
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
                  pw.Text('EXPENSE REPORT',
                      style: pw.TextStyle(
                          font: pw.Font.timesBold(),
                          fontSize: 16,
                          color: PdfColors.white,
                          letterSpacing: 0.5)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Period: ${dateFmt.format(_periodStart)} — ${dateFmt.format(_periodEnd)}',
                    style: pw.TextStyle(
                        font: pw.Font.times(),
                        fontSize: 9,
                        color: PdfColors.white)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated: ${dateFmt.format(now)}',
                      style: pw.TextStyle(
                          font: pw.Font.times(),
                          fontSize: 9,
                          color: PdfColors.white)),
                  pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: pw.TextStyle(
                          font: pw.Font.times(),
                          fontSize: 9,
                          color: PdfColors.white)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
      ]),
      footer: (ctx) => pw.Container(
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
      build: (ctx) => [
        // ── KPI row ────────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _pdfKpi('Total Expenses', '৳ ${numFmt.format(total)}',
                const PdfColor.fromInt(0xFF065F46)),
            _pdfKpi('Entries', '${docs.length}',
                const PdfColor.fromInt(0xFF0891B2)),
            _pdfKpi('Category Filter', _categoryFilter ?? 'All',
                const PdfColor.fromInt(0xFF065F46)),

          ],
        ),
        pw.SizedBox(height: 16),

        // ── Table ──────────────────────────────────────────────────────────
        pw.Text('Expense Details',
            style: pw.TextStyle(
                font: pw.Font.timesBold(),
                fontSize: 13,
                color: textDark)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: lineClr, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2), // Vendor
            1: const pw.FlexColumnWidth(1.5), // Category
            2: const pw.FlexColumnWidth(1.5), // Due Date
            3: const pw.FlexColumnWidth(1.2), // Cost Center
            4: const pw.FlexColumnWidth(1.6), // Amount
            5: const pw.FlexColumnWidth(1.0), // Status
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: [
                'Vendor', 'Category', 'Due Date', 'Cost Center', 'Amount (৳)', 'Status',
              ].map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(h,
                    style: pw.TextStyle(
                        font: pw.Font.timesBold(),
                        fontSize: 9,
                        color: PdfColors.white)),
              )).toList(),
            ),
            // Data rows
            ...docs.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value.data() as Map<String, dynamic>;
              final vendor   = d['vendor']     as String? ?? '—';
              final cat      = d['category']   as String? ?? '—';
              final due      = d['dueDate'] is Timestamp
                  ? dateFmt.format((d['dueDate'] as Timestamp).toDate())
                  : '—';
              final cc       = d['costCenter'] as String? ?? '—';
              final amt      = _n(d['amount']);
              final status   = (d['status']   as String? ?? 'planned').toUpperCase();
              final rowColor = i.isOdd ? rowAlt : PdfColors.white;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: rowColor),
                children: [vendor, cat, due, cc, numFmt.format(amt), status]
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
          ],
        ),
        pw.SizedBox(height: 8),

        // ── Total row ──────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(color: headerBg),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('TOTAL:  ',
                  style: pw.TextStyle(
                      font: pw.Font.timesBold(),
                      fontSize: 11,
                      color: PdfColors.white)),
              pw.Text('৳ ${numFmt.format(total)}',
                  style: pw.TextStyle(
                      font: pw.Font.timesBold(),
                      fontSize: 13,
                      color: PdfColors.white)),
            ],
          ),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
        title: Text('Expenses',
            style: AppFonts.banglaHeading(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),

          actions: [
            IconButton(
              tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ExpensesHistoryScreen()),
              ),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Expense',
            style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
        onPressed: () => _openExpenseDialog(context),
      ),

      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : StreamBuilder<QuerySnapshot>(
            stream: _query().snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _brand));
              }
              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final m = d.data() as Map<String, dynamic>;
                
                // Real-life accuracy: exclude voided records from current totals/list
                if ((m['status'] ?? '') == 'voided') return false;
                
                // Apply category filter if set
                if (_categoryFilter != null && m['category'] != _categoryFilter) return false;
                
                return true;
              }).toList();

              num total = 0;
              for (final d in filtered) {
                  total += _n((d.data() as Map<String, dynamic>)['amount']);
              }


              return Column(
                children: [
                    // ── Controls bar ────────────────────────────────────────
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                    children: [
                          Row(children: [
                      Expanded(
                              child: _PeriodButton(
                                label: _periodLabel(),
                                onTap: _pickPeriod,
                              ),
                            ),
                            const SizedBox(width: 10),
                      Expanded(
                              child: _CategoryDropdown(
                          value: _categoryFilter,
                                onChanged: (v) =>
                                    setState(() => _categoryFilter = v),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const Divider(height: 1),


                    // ── Summary hero ─────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_brand, _brandMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: _brand.withValues(alpha: 0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Expenses',
                                  style: AppFonts.banglaBody(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                '৳ ${_money.format(total)}',
                                style: AppFonts.banglaData(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _periodLabel(),
                                style: AppFonts.banglaBody(
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${filtered.length}',
                                style: AppFonts.banglaData(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900)),
                            Text('entries',
                                style: AppFonts.banglaBody(
                                    color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 8),
                            // PDF download button
                            GestureDetector(
                              onTap: filtered.isEmpty
                                  ? null
                                  : () => _exportPdf(
                                      filtered.cast<QueryDocumentSnapshot>()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 5),
                                    Text('PDF',
                                        style: AppFonts.banglaHeading(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]),
                    ),

                  const SizedBox(height: 14),

                    // ── Category chips ───────────────────────────────────────
                    SizedBox(
                      height: 36,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                    children: [
                          _CatChip(
                            label: 'All',
                            selected: _categoryFilter == null,
                            color: _brand,
                            onTap: () =>
                                setState(() => _categoryFilter = null),
                          ),
                          ...(_categories.map((cat) => _CatChip(
                                label: cat,
                                selected: _categoryFilter == cat,
                                color: _catColor(cat),
                                onTap: () => setState(
                                    () => _categoryFilter = cat),
                              ))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── List ─────────────────────────────────────────────────
                  Expanded(
                    child: filtered.isEmpty
                          ? _EmptyState(
                              message: _categoryFilter == null
                                  ? 'No expenses in this period'
                                  : 'No $_categoryFilter expenses',
                            )
                        : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 0, 16, 100),
                      itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = filtered[i];
                                final d = doc.data()
                                    as Map<String, dynamic>;
                                return _ExpenseTile(
                                  doc:    doc,
                                  data:   d,
                                  money:  _money,
                                  dateFmt: _dateFmt,
                                  onEdit: () =>
                                      _openExpenseDialog(context, doc: doc),
                                  onDelete: () =>
                                      _confirmDelete(context, doc),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _periodLabel() {
    final now = DateTime.now();
    final thisM = DateTime(now.year, now.month, 1);
    final lastM = DateTime(now.year, now.month - 1, 1);
    if (_periodStart == thisM) return 'This Month';
    if (_periodStart == lastM) return 'Last Month';
    return '${DateFormat('d MMM').format(_periodStart)} – '
        '${DateFormat('d MMM yyyy').format(_periodEnd)}';
  }

  Future<void> _pickPeriod() async {
    final now       = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd   = DateTime(now.year, now.month, 0, 23, 59, 59);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Choose Period',
                style: AppFonts.banglaHeading(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _PeriodOption(
              icon: Icons.today_rounded,
              label: 'This Month',
              onTap: () {
                setState(() {
                  _periodStart = thisStart;
                  _periodEnd = DateTime(
                      thisStart.year, thisStart.month + 1, 0, 23, 59, 59);
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _PeriodOption(
              icon: Icons.history_rounded,
              label: 'Last Month',
              onTap: () {
                setState(() {
                  _periodStart = lastStart;
                  _periodEnd   = lastEnd;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _PeriodOption(
              icon: Icons.date_range_rounded,
              label: 'Custom Range',
              onTap: () async {
                Navigator.pop(context);
                final s = await showDatePicker(
                  context: context,
                  initialDate: _periodStart,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (s == null || !mounted) return;
                final e = await showDatePicker(
                  context: context,
                  initialDate: _periodEnd,
                  firstDate: s,
                  lastDate: DateTime.now(),
                );
                if (e == null) return;
                setState(() {
                  _periodStart = DateTime(s.year, s.month, s.day);
                  _periodEnd   = DateTime(e.year, e.month, e.day, 23, 59, 59);
                });
              },
            ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  void _openExpenseDialog(BuildContext context,
      {QueryDocumentSnapshot? doc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExpenseFormSheet(cid: _cid, doc: doc),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, QueryDocumentSnapshot doc) async {
    await _deleteExpenseWithSync(context: context, cid: _cid, doc: doc);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPENSE TILE — swipe-to-reveal edit/delete
// ─────────────────────────────────────────────────────────────────────────────
class _ExpenseTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic>  data;
  final NumberFormat          money;
  final DateFormat            dateFmt;
  final VoidCallback          onEdit;
  final VoidCallback          onDelete;

  const _ExpenseTile({
    required this.doc,
    required this.data,
    required this.money,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final vendor   = data['vendor']     as String? ?? 'Vendor';
    final category = data['category']   as String? ?? 'Other';
    final amt      = _n(data['amount']);
    final notes    = data['notes']      as String? ?? '';
    final cc       = data['costCenter'] as String? ?? '';
    final status   = data['status']     as String? ?? 'planned';
    final due      = data['dueDate'] is Timestamp
        ? (data['dueDate'] as Timestamp).toDate()
        : DateTime.now();
    final isOverdue = due.isBefore(DateTime.now()) && status != 'paid';
    final catColor  = _catColor(category);

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
          color: _red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text('Delete',
                style: AppFonts.banglaHeading(
        color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // let _confirmDelete handle actual deletion
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isOverdue
                  ? _red.withValues(alpha: 0.3)
                  : catColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
      ),
      child: Column(
        children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(children: [
                // Category icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_catIcon(category), color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor,
                          style: AppFonts.banglaHeading(
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(children: [
                        _Chip(label: category, color: catColor),
                        if (cc.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Chip(label: cc, color: Colors.black38),
                        ],
                        if (isOverdue) ...[
                          const SizedBox(width: 6),
                          _Chip(label: 'Overdue', color: _red),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        'Due: ${dateFmt.format(due)}',
                        style: AppFonts.banglaBody(
                            fontSize: 11,
                            color: isOverdue ? _red : Colors.black45),
                      ),
                    ],
                  ),
                ),
                // Amount + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳ ${money.format(amt)}',
                      style: AppFonts.banglaData(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isOverdue ? _red : _brand),
                    ),
          const SizedBox(height: 6),
                    Row(children: [
                      _IconBtn(
                          icon: Icons.edit_rounded,
                          color: _brand,
                          onTap: onEdit),
                      const SizedBox(width: 4),
                      _IconBtn(
                          icon: Icons.delete_rounded,
                          color: _red,
                          onTap: onDelete),
                    ]),
                  ],
                ),
              ]),
            ),
            // Notes row (if any)
            if (notes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.banglaBody(
                      fontSize: 11, color: Colors.black45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT FORM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ExpenseFormSheet extends StatefulWidget {
  final String                   cid;
  final QueryDocumentSnapshot?   doc; // null = add, non-null = edit
  const _ExpenseFormSheet({required this.cid, this.doc});
  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _vendor  = TextEditingController();
  final _amount  = TextEditingController();
  final _notes   = TextEditingController();
  String  _category  = 'Other';
  String? _costCenter;
  String  _status    = 'planned';
  DateTime _dueDate  = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  static const _statuses = ['planned', 'paid', 'overdue', 'cancelled'];

  @override
  void initState() {
    super.initState();
    if (widget.doc != null) {
      final d = widget.doc!.data() as Map<String, dynamic>;
      _vendor.text  = d['vendor']   as String? ?? '';
      _amount.text  = _n(d['amount']).toStringAsFixed(2);
      _notes.text   = d['notes']    as String? ?? '';
      _category     = d['category'] as String? ?? 'Other';
      _costCenter   = d['costCenter'] as String?;
      _status       = d['status']   as String? ?? 'planned';
      if (d['dueDate'] is Timestamp) {
        _dueDate = (d['dueDate'] as Timestamp).toDate();
      }
    }
  }

  @override
  void dispose() {
    _vendor.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.doc != null;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
        child: Form(
          key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit Expense' : 'New Expense',
              style: AppFonts.banglaHeading(
                  fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // Vendor
            _FormField(
              controller: _vendor,
              label: 'Vendor / Description',
              icon: Icons.store_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter vendor' : null,
            ),
            const SizedBox(height: 12),

            // Amount
            _FormField(
              controller: _amount,
              label: 'Amount (BDT)',
              icon: Icons.currency_exchange_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter amount',
            ),
            const SizedBox(height: 12),

            // Category + Cost Center row
            Row(children: [
              Expanded(
                child: _DropField<String>(
                  label: 'Category',
              value: _category,
                  items: _categories,
              onChanged: (v) => setState(() => _category = v ?? 'Other'),
            ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DropField<String?>(
                  label: 'Cost Center',
              value: _costCenter,
                  items: const [null, ..._costCenters],
                  itemLabel: (v) => v ?? 'None',
              onChanged: (v) => setState(() => _costCenter = v),
            ),
              ),
            ]),
            const SizedBox(height: 12),

            // Status + Due Date row
            Row(children: [
              Expanded(
                child: _DropField<String>(
                  label: 'Status',
                  value: _status,
                  items: _statuses,
                  itemLabel: (v) =>
                      v[0].toUpperCase() + v.substring(1),
                  onChanged: (v) =>
                      setState(() => _status = v ?? 'planned'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: _brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('d MMM yyyy').format(_dueDate),
                          style: AppFonts.banglaBody(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon:
                    const Icon(Icons.notes_rounded, color: _brand),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(_isEdit
                        ? Icons.save_rounded
                        : Icons.add_rounded),
                label: Text(
                  _isEdit ? 'Save Changes' : 'Add Expense',
                  style: AppFonts.banglaHeading(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'vendor':     _vendor.text.trim(),
        'category':   _category,
        'amount':     double.parse(_amount.text.trim()),
        'dueDate':    Timestamp.fromDate(
            DateTime(_dueDate.year, _dueDate.month, _dueDate.day)),
        'status':     _status,
      'costCenter': _costCenter,
        'notes':      _notes.text.trim(),
      };

      if (_isEdit) {
        await DB.colSync(widget.cid, C.expenses)
            .doc(widget.doc!.id)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await DB.colSync(widget.cid, C.expenses).add(data);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY SCREEN (last 12 months, drillable)
// ─────────────────────────────────────────────────────────────────────────────
class ExpensesHistoryScreen extends StatelessWidget {
  const ExpensesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final months = _lastMonths(12);
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
        title: Text('Expense History',
            style: AppFonts.banglaHeading(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final start = months[i];
          final end   = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
          return _MonthTile(
              label: DateFormat('MMMM yyyy').format(start),
              start: start,
              end:   end);
        },
      ),
    );
  }

  static List<DateTime> _lastMonths(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => DateTime(now.year, now.month - i, 1));
  }
}

class _MonthTile extends StatefulWidget {
  final String   label;
  final DateTime start;
  final DateTime end;
  const _MonthTile(
      {required this.label, required this.start, required this.end});
  @override
  State<_MonthTile> createState() => _MonthTileState();
}

class _MonthTileState extends State<_MonthTile> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId()
        .then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    final q = DB.colSync(_cid, C.expenses)
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(widget.start))
        .where('dueDate',
            isLessThanOrEqualTo: Timestamp.fromDate(widget.end))
        .orderBy('dueDate');

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        num total = 0;
        int count = 0;
        if (snap.hasData) {
          count = snap.data!.docs.length;
          for (final d in snap.data!.docs) {
            total += _n((d.data() as Map<String, dynamic>)['amount']);
          }
        }
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _MonthDetailPage(
                  start: widget.start,
                  end:   widget.end,
                  label: widget.label),
            )),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: _brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                          style: AppFonts.banglaHeading(
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      Text('$count entries',
                          style: AppFonts.banglaBody(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('৳ ${money.format(total)}',
                        style: AppFonts.banglaData(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _brand)),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.black26, size: 18),
                  ],
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTH DETAIL PAGE — full list with edit/delete + PDF export
// ─────────────────────────────────────────────────────────────────────────────
class _MonthDetailPage extends StatefulWidget {
  final DateTime start, end;
  final String   label;
  const _MonthDetailPage(
      {required this.start, required this.end, required this.label});
  @override
  State<_MonthDetailPage> createState() => _MonthDetailPageState();
}

class _MonthDetailPageState extends State<_MonthDetailPage> {
  String _cid = '';
  final _money   = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId()
        .then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  @override
  Widget build(BuildContext context) {
    final q = DB.colSync(_cid, C.expenses)
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(widget.start))
        .where('dueDate',
            isLessThanOrEqualTo: Timestamp.fromDate(widget.end))
        .orderBy('dueDate');

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
        title: Text(widget.label,
            style: AppFonts.banglaHeading(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }
          final docs = snap.data!.docs;
          num total = 0;
          for (final d in docs) {
            total += _n((d.data() as Map<String, dynamic>)['amount']);
          }

          return Column(
            children: [
              // Summary hero
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brand, _brandMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: _brand.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(children: [
              Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.label,
                            style: AppFonts.banglaBody(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('৳ ${_money.format(total)}',
                            style: AppFonts.banglaData(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${docs.length}',
                          style: AppFonts.banglaData(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                      Text('entries',
                          style: AppFonts.banglaBody(
                              color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: docs.isEmpty
                            ? null
                            : () => _exportPdf(
                                docs.cast<QueryDocumentSnapshot>()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: 0.4)),
                          ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 5),
                                    Text('PDF',
                                        style: AppFonts.banglaHeading(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: docs.isEmpty
                    ? const _EmptyState(message: 'No expenses this month')
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final d = doc.data() as Map<String, dynamic>;
                          return _ExpenseTile(
                            doc:     doc,
                            data:    d,
                            money:   _money,
                            dateFmt: _dateFmt,
                            onEdit:  () => _openEdit(context, doc),
                            onDelete: () => _confirmDelete(context, doc),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEdit(BuildContext context, QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExpenseFormSheet(cid: _cid, doc: doc),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, QueryDocumentSnapshot doc) async {
    await _deleteExpenseWithSync(context: context, cid: _cid, doc: doc);
  }

  Future<void> _exportPdf(List<QueryDocumentSnapshot> docs) async {
    final numFmt  = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');
    final now     = DateTime.now();
    num total = 0;
    for (final d in docs) {
      total += _n((d.data() as Map<String, dynamic>)['amount']);
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base:       pw.Font.times(),
        bold:       pw.Font.timesBold(),
        italic:     pw.Font.timesItalic(),
        boldItalic: pw.Font.timesBoldItalic(),
      ),
    );

    final headerBg = const PdfColor.fromInt(0xFF4F46E5);
    final rowAlt   = const PdfColor.fromInt(0xFFF5F3FF);
    final lineClr  = const PdfColor.fromInt(0xFFE0E7FF);
    final textMuted = const PdfColor.fromInt(0xFF6B7280);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
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
                  pw.Text('EXPENSE REPORT — ${widget.label}',
                      style: pw.TextStyle(
                          font: pw.Font.timesBold(),
                          fontSize: 14,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 3),
                  pw.Text('Generated: ${dateFmt.format(now)}',
                      style: pw.TextStyle(
                          font: pw.Font.times(),
                          fontSize: 9,
                          color: PdfColors.white)),
                ],
              ),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: pw.Font.times(),
                      fontSize: 9,
                      color: PdfColors.white)),
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
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _pdfKpi('Total', '৳ ${numFmt.format(total)}',
                const PdfColor.fromInt(0xFF4F46E5)),
            _pdfKpi('Entries', '${docs.length}',
                const PdfColor.fromInt(0xFF0891B2)),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside:
                pw.BorderSide(color: lineClr, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.8),
            4: const pw.FlexColumnWidth(1.0),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: ['Vendor', 'Category', 'Due Date', 'Amount (৳)', 'Status']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                font: pw.Font.timesBold(),
                                fontSize: 9,
                                color: PdfColors.white)),
                      ))
                  .toList(),
            ),
            ...docs.asMap().entries.map((e) {
              final i = e.key;
              final d = e.value.data() as Map<String, dynamic>;
              final vendor = d['vendor']   as String? ?? '—';
              final cat    = d['category'] as String? ?? '—';
              final due    = d['dueDate'] is Timestamp
                  ? dateFmt.format((d['dueDate'] as Timestamp).toDate())
                  : '—';
              final amt    = _n(d['amount']);
              final status = (d['status'] as String? ?? 'planned')
                  .toUpperCase();
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? rowAlt : PdfColors.white),
                children: [vendor, cat, due, numFmt.format(amt), status]
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
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(color: headerBg),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('TOTAL:  ',
                  style: pw.TextStyle(
                      font: pw.Font.timesBold(),
                      fontSize: 11,
                      color: PdfColors.white)),
              pw.Text('৳ ${numFmt.format(total)}',
                  style: pw.TextStyle(
                      font: pw.Font.timesBold(),
                      fontSize: 13,
                      color: PdfColors.white)),
            ],
          ),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED: Smart expense deletion — auto-reverses linked payroll if present
// ─────────────────────────────────────────────────────────────────────────────

/// Deletes an expense doc. If the expense was created by a payroll disbursement
/// (i.e. it has a `_payrollDocId` field), the function also:
///   1. Resets the linked payroll record back to `pending` (unpaid).
///   2. Deletes the linked cash-flow doc that was created at disbursement.
///   3. Writes a `reversal` audit entry in cash-flow for traceability.
///   4. Decrements the company `cashOut` total.
///
/// All Firestore writes are done in a single batch (atomic).
Future<void> _deleteExpenseWithSync({
  required BuildContext context,
  required String       cid,
  required QueryDocumentSnapshot doc,
}) async {
  final d          = doc.data() as Map<String, dynamic>;
  final name       = (d['vendor'] as String?)?.trim() ?? 'this expense';
  final payrollId  = (d['_payrollDocId']  as String?)?.trim() ?? '';
  final cfId       = (d['_cashFlowDocId'] as String?)?.trim() ?? '';
  final isLinked   = payrollId.isNotEmpty;
  final amount     = (d['amount'] is num)
      ? (d['amount'] as num).toDouble()
      : double.tryParse(d['amount']?.toString() ?? '') ?? 0.0;
  final empName    = (d['item'] as String?)?.trim() ?? name;

  // ── Confirmation dialog ──────────────────────────────────────────────────
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(
          isLinked ? Icons.sync_problem_rounded : Icons.delete_rounded,
          color: _red, size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          isLinked ? 'Delete & Reverse Payroll' : 'Delete Expense',
          style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delete "$name"?',
              style: AppFonts.banglaBody(fontWeight: FontWeight.w600)),
          if (isLinked) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFD97706), size: 14),
                    const SizedBox(width: 6),
                    Text('Payroll Linked',
                        style: AppFonts.banglaHeading(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFFD97706))),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'This expense was created by a payroll disbursement. '
                    'Deleting it will automatically:',
                    style: AppFonts.banglaBody(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 6),
                  for (final bullet in [
                    '• Reset the payroll record to Unpaid',
                    '• Remove the cash-out entry from cash flow',
                    '• Add a reversal audit record',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(bullet,
                          style: AppFonts.banglaBody(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E))),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text('This cannot be undone.',
                style: AppFonts.banglaBody(color: Colors.black54, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _red),
          onPressed: () => Navigator.pop(context, true),
          child: Text(isLinked ? 'Delete & Reverse' : 'Delete'),
        ),
      ],
    ),
  );

  if (ok != true) return;

  // ── Atomic Firestore batch ───────────────────────────────────────────────
  final batch = DB.firestore.batch();

  // 1. Delete the expense doc
  batch.delete(DB.colSync(cid, C.expenses).doc(doc.id));

  if (isLinked) {
    // 2. Reset linked payroll → pending (unpaid)
    batch.update(DB.colSync(cid, C.payrolls).doc(payrollId), {
      'status':           'pending',
      'disbursedAt':      FieldValue.delete(),
      'paymentMethod':    FieldValue.delete(),
      'paymentReference': FieldValue.delete(),
      '_expenseDocId':    FieldValue.delete(),
      '_cashFlowDocId':   FieldValue.delete(),
      '_paidBy':          FieldValue.delete(),
      '_reversedAt':      FieldValue.serverTimestamp(),
      '_reversedBy':      'expense_delete',
    });

    // 3. Delete the original cash-flow doc (the cash-out entry)
    if (cfId.isNotEmpty) {
      batch.delete(DB.colSync(cid, C.cashFlow).doc(cfId));
    }

    // 4. Write a reversal audit entry in cash-flow
    batch.set(DB.colSync(cid, C.cashFlow).doc(), {
      'type':                   'reversal',
      'amount':                 amount,
      'currency':               'BDT',
      'description':            'Payroll reversal via expense delete – $empName',
      'category':               'Payroll',
      'originalPayrollDocId':   payrollId,
      'reversedBy':             'expense_delete',
      'createdAt':              FieldValue.serverTimestamp(),
    });

    // 5. Decrement company cashOut
    DB.colSync(cid, C.companyProfile).doc('main').update({
      'cashOut': FieldValue.increment(-amount),
    });
  }

  await batch.commit();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isLinked
            ? 'Expense deleted — payroll reset to unpaid'
            : 'Expense deleted'),
        backgroundColor: isLinked ? const Color(0xFFD97706) : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _PeriodButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _brand.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: _brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: AppFonts.banglaHeading(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _brand)),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: _brand),
          ]),
        ),
      );
}

class _CategoryDropdown extends StatelessWidget {
  final String?              value;
  final ValueChanged<String?> onChanged;
  const _CategoryDropdown(
      {required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _brand.withValues(alpha: 0.3)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            isExpanded: true,
            hint: Text('All Categories',
                style: AppFonts.banglaBody(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _brand)),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: _brand),
            style: AppFonts.banglaBody(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _brand),
            items: [null, ..._categories]
                .map((e) => DropdownMenuItem<String?>(
                      value: e,
                      child: Text(e ?? 'All'),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}

class _CatChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        color;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : Colors.black12),
          ),
          child: Text(label,
              style: AppFonts.banglaHeading(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black54)),
        ),
      );
}

class _PeriodOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _PeriodOption(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black12)),
        leading: Icon(icon, color: _brand),
        title: Text(label,
            style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 64, color: _brand.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(message,
                style: AppFonts.banglaHeading(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black38)),
            const SizedBox(height: 6),
            Text('Tap + to add a new expense',
                style: AppFonts.banglaBody(fontSize: 12, color: Colors.black26)),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppFonts.banglaHeading(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final TextInputType?        keyboardType;
  final String? Function(String?)? validator;
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
        controller:   controller,
        keyboardType: keyboardType,
        validator:    validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _brand, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      );
}

class _DropField<T> extends StatelessWidget {
  final String           label;
  final T                value;
  final List<T>          items;
  final String Function(T)? itemLabel;
  final ValueChanged<T?> onChanged;
  const _DropField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(itemLabel != null
                      ? itemLabel!(e)
                      : e?.toString() ?? 'None'),
                ))
            .toList(),
        onChanged: onChanged,
      );
}

// ── PDF KPI box ───────────────────────────────────────────────────────────────
pw.Widget _pdfKpi(String label, String value, PdfColor color) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFE0E7FF), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: pw.Font.times(),
                  fontSize: 8,
                  color: const PdfColor.fromInt(0xFF6B7280))),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  font: pw.Font.timesBold(), fontSize: 14, color: color)),
        ],
      ),
    );

// ── Shared helper ─────────────────────────────────────────────────────────────
num _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}
