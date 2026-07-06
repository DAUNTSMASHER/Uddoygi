// lib/features/admin/presentation/screens/reports_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────
class _T {
  static const bg          = Color(0xFFF6F7FB);
  static const fg          = Color(0xFF0F1724);
  static const card        = Colors.white;
  static const border      = Color(0x14000000);
  static const primary     = Color(0xFF5B00A1);
  static const primaryFg   = Colors.white;
  static const secondary   = Color(0xFFEEF2FF);
  static const secondaryFg = Color(0xFF3B2766);
  static const mutedFg     = Color(0xFF6B7280);
  static const success     = Color(0xFF1FA807);
  static const successFg   = Colors.white;
  static const accent      = Color(0xFF7C5CFF);
  static const destructive = Color(0xFFFF3838);
  static const destructiveFg = Colors.white;
  static const warning     = Color(0xFFF5E90A);
  static const warningFg   = Color(0xFF111827);

  static const rSm = 4.0;
  static const rMd = 8.0;
  static const rLg = 12.0;
  static const rXl = 16.0;
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
double _n(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
  return 0;
}

String _taka(double v) {
  final a = v.abs();
  if (a >= 10000000) return '৳${(v / 10000000).toStringAsFixed(1)}Cr';
  if (a >= 100000)   return '৳${(v / 100000).toStringAsFixed(1)}L';
  if (a >= 1000)     return '৳${(v / 1000).toStringAsFixed(1)}k';
  return '৳${v.round()}';
}

String _fmtFull(double v) =>
    '৳${NumberFormat('#,##0', 'en_US').format(v.round())}';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime)  return v;
  if (v is String)    return DateTime.tryParse(v.trim());
  return null;
}


bool _inRange(DateTime? d, DateTime from, DateTime to) =>
    d != null && !d.isBefore(from) && d.isBefore(to);

// ─────────────────────────────────────────────────────────────
// PERIOD
// ─────────────────────────────────────────────────────────────
enum _Period { month, quarter, year, allTime }

extension _PeriodX on _Period {
  String get label {
    switch (this) {
      case _Period.month:   return 'Month';
      case _Period.quarter: return 'Quarter';
      case _Period.year:    return 'Year';
      case _Period.allTime: return 'All Time';
    }
  }

  String get fullLabel {
    switch (this) {
      case _Period.month:   return 'Current Month';
      case _Period.quarter: return 'Last 3 Months';
      case _Period.year:    return 'Last Year';
      case _Period.allTime: return 'All Time';
    }
  }

  DateTimeRange range(DateTime now) {
    switch (this) {
      case _Period.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end:   DateTime(now.year, now.month + 1, 1),
        );
      case _Period.quarter:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end:   DateTime(now.year, now.month + 1, 1),
        );
      case _Period.year:
        return DateTimeRange(
          start: DateTime(now.year - 1, now.month, 1),
          end:   DateTime(now.year, now.month + 1, 1),
        );
      case _Period.allTime:
        return DateTimeRange(
          start: DateTime(2000),
          end:   now.add(const Duration(days: 1)),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────
class _ReportData {
  final double cashIn;
  final double expense;
  final double profit;
  final double loan;
  final double avgBudget;
  final double avgRoi;
  final int    production;
  final int    stock;
  final int    rndProjects;
  final int    workOrders;
  final int    employees;
  final int    attendance;
  final int    clients;
  final int    campaigns;

  const _ReportData({
    this.cashIn      = 0,
    this.expense     = 0,
    this.profit      = 0,
    this.loan        = 0,
    this.avgBudget   = 0,
    this.avgRoi      = 0,
    this.production  = 0,
    this.stock       = 0,
    this.rndProjects = 0,
    this.workOrders  = 0,
    this.employees   = 0,
    this.attendance  = 0,
    this.clients     = 0,
    this.campaigns   = 0,
  });

  double get profitMargin =>
      cashIn > 0 ? (profit / cashIn) * 100 : 0;
}

// ─────────────────────────────────────────────────────────────
// DATA LOADER (shared logic)
// ─────────────────────────────────────────────────────────────
Future<_ReportData> _loadData(_Period period) async {
  final _cid = await LocalStorageService.getSavedCompanyId() ?? '';
  final now  = DateTime.now();
  final rng  = period.range(now);
  final from = rng.start;
  final to   = rng.end;
  final all  = period == _Period.allTime;

  final res = await Future.wait([
    DB.colSync(_cid, C.expenses).get(),
    DB.colSync(_cid, C.invoices).get(),
    DB.colSync(_cid, C.loans).get(),
    DB.colSync(_cid, C.attendance).get(),
    DB.colSync(_cid, C.dailyProduction).get(),
    DB.colSync(_cid, C.stocks).get(),
    DB.colSync(_cid, C.rndProjects).get(),
    DB.colSync(_cid, C.workOrders).get(),
    DB.colSync(_cid, C.users).get(),
    DB.colSync(_cid, C.campaigns).get(),
    DB.colSync(_cid, C.customers).get(),
  ]);

  // Expenses
  double expense = 0;
  for (final d in res[0].docs) {
    final m  = d.data();
    final dt = _ts(m['dueDate']) ?? _ts(m['createdAt']) ?? _ts(m['timestamp']);
    if (all || _inRange(dt, from, to)) expense += _n(m['amount'] ?? m['total'] ?? 0);
  }

  // Cash In
  double cashIn = 0;
  for (final d in res[1].docs) {
    final m  = d.data();
    final dt = _ts(m['timestamp']) ?? _ts(m['createdAt']) ?? _ts(m['invoiceDate']);
    if (all || _inRange(dt, from, to)) {
      cashIn += _n(m['grandTotal'] ?? m['received'] ?? m['paidAmount']
                ?? m['paid'] ?? m['amount'] ?? m['total'] ?? 0);
    }
  }

  // Loans — show outstanding (disbursed principal minus repaid amounts)
  // Only count disbursed/approved loans; subtract repayments from subcollections.
  double loan = 0;
  for (final d in res[2].docs) {
    final m      = d.data();
    final status = (m['status'] ?? '').toString().toLowerCase();
    // Only count active (approved/disbursed) loans — not pending/rejected/withdrawn/closed
    if (!['approved', 'disbursed'].contains(status)) continue;
    final dt = _ts(m['disbursedAt']) ?? _ts(m['decisionAt']) ?? _ts(m['requestedAt']) ?? _ts(m['createdAt']);
    if (!all && !_inRange(dt, from, to)) continue;
    final principal = _n(m['disbursedAmount'] ?? m['amount'] ?? 0);
    // Fetch repayments for this loan to compute outstanding
    final repaysSnap = await d.reference.collection('repayments').get();
    final repaid = repaysSnap.docs.fold<double>(
        0.0, (sum, r) => sum + _n(r.data()['amount'] ?? 0));
    final outstanding = (principal - repaid).clamp(0.0, double.infinity);
    loan += outstanding;
  }

  // Attendance
  int attend = 0;
  for (final d in res[3].docs) {
    final m  = d.data();
    final dt = _ts(m['date']) ?? _ts(m['timestamp']) ?? _ts(m['createdAt']);
    if (all || _inRange(dt, from, to)) attend++;
  }

  // Production
  int prod = 0;
  for (final d in res[4].docs) {
    final m  = d.data();
    final dt = _ts(m['productionDate']) ?? _ts(m['timestamp']) ?? _ts(m['createdAt']);
    if (all || _inRange(dt, from, to)) prod += _n(m['quantity'] ?? m['qty'] ?? 0).round();
  }

  // Stock (snapshot)
  int stock = 0;
  for (final d in res[5].docs) {
          final m = d.data();
    stock += _n(m['qty'] ?? m['quantity'] ?? m['stock'] ?? 0).round();
  }

  // R&D (running only)
  int rnd = 0;
  for (final d in res[6].docs) {
    final m      = d.data();
    final status = (m['status'] ?? '').toString();
    if (status == 'Completed' || status == 'Cancelled') continue;
    final dt = _ts(m['createdAt']) ?? _ts(m['timestamp']);
    if (all || _inRange(dt, from, to)) rnd++;
  }

  // Work Orders
  int wo = 0;
  for (final d in res[7].docs) {
    final m  = d.data();
    final dt = _ts(m['timestamp']) ?? _ts(m['createdAt']) ?? _ts(m['lastUpdated']);
    if (all || _inRange(dt, from, to)) wo++;
  }

  // Employees
  int emp = 0;
  for (final d in res[8].docs) {
    final m    = d.data();
    final dept = (m['department'] ?? m['role'] ?? '').toString().toLowerCase();
    if (dept != 'admin') emp++;
  }

  // Campaigns + ROI + Budget
  int    camps     = 0;
  double budgetSum = 0, roiSum = 0;
  int    budgetN   = 0, roiN   = 0;
  for (final d in res[9].docs) {
    final m  = d.data();
    final dt = _ts(m['createdAt']) ?? _ts(m['startDate']);
    if (!all && !_inRange(dt, from, to)) continue;
    camps++;
    final bud = _n(m['budget'] ?? 0);
    if (bud > 0) { budgetSum += bud; budgetN++; }
    double roi = _n(m['roi'] ?? m['ROI'] ?? 0);
    if (roi == 0 && bud > 0) {
      final totals = m['totals'];
      if (totals is Map) {
        final rev = _n(totals['revenue'] ?? 0);
        if (rev > 0) roi = ((rev - bud) / bud) * 100;
      }
    }
    if (roi != 0) { roiSum += roi; roiN++; }
  }

  // Clients
  final clientCount = res[10].docs.length;

  return _ReportData(
    cashIn:      cashIn,
    expense:     expense,
    profit:      cashIn - expense,
    loan:        loan,
    avgBudget:   budgetN > 0 ? budgetSum / budgetN : 0,
    avgRoi:      roiN    > 0 ? roiSum    / roiN    : 0,
    production:  prod,
    stock:       stock,
    rndProjects: rnd,
    workOrders:  wo,
    employees:   emp,
    attendance:  attend,
    clients:     clientCount,
    campaigns:   camps,
  );
}

// ─────────────────────────────────────────────────────────────
// PDF BUILDER
// ─────────────────────────────────────────────────────────────
Future<Uint8List> _buildPdf(_ReportData d, _Period period, String company) async {
  final doc       = pw.Document(theme: pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic()));
  final now       = DateTime.now();
  final generated = DateFormat('dd MMM yyyy, hh:mm a').format(now);
  final period_   = period.fullLabel;

  // Gazette-style PDF matching the design reference
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (_) => [
      // ── Decorative header ──
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 16),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 2.5, color: PdfColors.black)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text(company,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Text('Executive Performance Report',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 8),
          pw.Text('Reporting Period: $period_   |   Date of Issue: $generated',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
      ),
      pw.SizedBox(height: 20),

      // ── Section 1: Executive Summary ──
      _pSection('1. Executive Summary'),
      pw.Text(
        'This document serves as the official performance report for $company for the '
        'referenced period. The organization recorded a total Cash In of ${_fmtFull(d.cashIn)} '
        'against an Expense of ${_fmtFull(d.expense)}, resulting in a net Profit of '
        '${_fmtFull(d.profit)}. Overall performance indicates a '
        '${d.profit >= 0 ? 'stable growth trajectory' : 'period requiring cost review'} '
        'with a Profit Margin of ${d.profitMargin.toStringAsFixed(1)}%. Key indicators '
        'across Financials, Operations, HR and Sales '
        '${d.profit >= 0 ? 'remain positive and aligned with corporate targets.' : 'require attention.'}',
        style: pw.TextStyle(fontSize: 11, lineSpacing: 4),
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 20),

      // ── Section 2: Detailed Metrics ──
      _pSection('2. Detailed Metrics'),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.75),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
        },
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _pCell('Indicator', bold: true),
              _pCell('Value',     bold: true, right: true),
            ],
          ),
          // Financials group
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _pCell('Financials', bold: true, span: true),
              _pCell('', span: true),
            ],
          ),
          _pRow('Total Cash In',    _fmtFull(d.cashIn)),
          _pRow('Total Expense',    _fmtFull(d.expense)),
          _pRow('Net Profit',       _fmtFull(d.profit)),
          _pRow('Profit Margin',    '${d.profitMargin.toStringAsFixed(1)}%'),
          _pRow('Avg Campaign Budget', _fmtFull(d.avgBudget)),
          _pRow('Loan Obligations', _fmtFull(d.loan)),
          // Operations group
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
              _pCell('Operations & Factory', bold: true, span: true),
              _pCell('', span: true),
            ],
          ),
          _pRow('Total Production',  '${NumberFormat('#,##0').format(d.production)} units'),
          _pRow('Current Stock',     '${NumberFormat('#,##0').format(d.stock)} units'),
          _pRow('Work Orders',       '${d.workOrders}'),
          _pRow('R&D Projects Running', '${d.rndProjects}'),
          // HR group
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
              _pCell('HR & People', bold: true, span: true),
              _pCell('', span: true),
            ],
          ),
          _pRow('Total Employees', '${d.employees}'),
          _pRow('Attendance Records', '${d.attendance}'),
          // Sales group
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _pCell('Sales & Marketing', bold: true, span: true),
              _pCell('', span: true),
            ],
          ),
          _pRow('Total Clients',    '${NumberFormat('#,##0').format(d.clients)}'),
          _pRow('Active Campaigns', '${d.campaigns}'),
          _pRow('Avg ROI',          '${d.avgRoi.toStringAsFixed(1)}%'),
        ],
      ),
      pw.SizedBox(height: 20),

      // ── Section 3: Conclusion ──
      _pSection('3. Conclusion & Recommendations'),
      pw.Text(
        d.profit >= 0
            ? 'The overall financial health remains robust. The positive trend in Cash In '
              'and Profit Margin suggests effective operational controls and steady market demand.\n\n'
              'Action Items: Future efforts should prioritize reducing Loan Obligations and '
              'aggressively expanding the active client base. Special focus is required on '
              'operational efficiency to maximize the Return on Investment (ROI) across '
              'ongoing internal projects.'
            : 'The period shows a net loss requiring immediate review of expense categories. '
              'Priority actions include cost reduction initiatives, loan restructuring, and '
              'accelerating revenue-generating activities across all departments.',
        style: pw.TextStyle(fontSize: 11, lineSpacing: 4),
        textAlign: pw.TextAlign.justify,
      ),
      pw.SizedBox(height: 48),

      // ── Signature block ──
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
          pw.Column(children: [
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dashed))),
              child: pw.SizedBox(height: 24),
            ),
            pw.SizedBox(height: 4),
            pw.Text('PREPARED BY',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5)),
          ]),
          pw.Column(children: [
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(style: pw.BorderStyle.dashed))),
              child: pw.SizedBox(height: 24),
            ),
            pw.SizedBox(height: 4),
            pw.Text('AUTHORIZED SIGNATORY',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5)),
          ]),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 4),
      pw.Text('$company  —  Confidential  |  Generated by Uddyogi ERP  |  $generated',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    ],
  ));

  return doc.save();
}

pw.Widget _pSection(String title) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5)),
    pw.Divider(color: PdfColors.black, thickness: 0.75),
    pw.SizedBox(height: 8),
  ],
);

pw.Widget _pCell(String t,
    {bool bold = false, bool right = false, bool span = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    child: pw.Text(t,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        )),
  );
}

pw.TableRow _pRow(String label, String value) => pw.TableRow(children: [
  _pCell(label),
  _pCell(value, right: true, bold: true),
]);

// ─────────────────────────────────────────────────────────────
// SAVE PDF TO DEVICE
// ─────────────────────────────────────────────────────────────
Future<File> _savePdfToDevice(Uint8List bytes, String company) async {
  final dir      = await getApplicationDocumentsDirectory();
  final filename = '${company.replaceAll(' ', '_')}_Report_'
      '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file;
}

// ─────────────────────────────────────────────────────────────
// MAIN REPORT SCREEN  (Dashboard)
// ─────────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _company = 'Wig Bangladesh';

  _Period     _period  = _Period.month;
  bool        _loading = false;
  _ReportData _data    = const _ReportData();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await _loadData(_period);
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data load failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
      child: Column(
        children: [
            // ── Header ──
            _DashHeader(company: _company, onBack: () => Navigator.maybePop(context)),
            // ── Period Selector ──
            _PeriodSelector(
              selected: _period,
              onChanged: (p) { setState(() => _period = p); _load(); },
            ),
            // ── Scrollable body ──
                    Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _T.primary))
                  : RefreshIndicator(
                      color: _T.primary,
                      onRefresh: _load,
                      child: _DashBody(
                        data: _data,
                        company: _company,
                        period: _period,
                        onViewFullReport: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => _FullReportScreen(
                            data: _data, period: _period, company: _company))),
                        onExportPdf: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => _PdfPreviewScreen(
                            data: _data, period: _period, company: _company))),
                      ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

// ── Dashboard Header ──────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final String company;
  final VoidCallback onBack;
  const _DashHeader({required this.company, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _CircleBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
          const Spacer(),
          Text('Report',
              style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w600,
                  color: _T.fg)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _T.secondary,
              borderRadius: BorderRadius.circular(_T.rXl),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.business_rounded, size: 14, color: _T.secondaryFg),
              const SizedBox(width: 6),
              Text(company,
                  style: AppFonts.banglaBody(fontSize: 13, fontWeight: FontWeight.w600,
                      color: _T.secondaryFg)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Period Selector ───────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
              child: Container(
              padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                color: _T.secondary,
                borderRadius: BorderRadius.circular(_T.rXl),
              ),
              child: Row(
                children: _Period.values.map((p) {
                  final active = p == selected;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? _T.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(_T.rXl),
                          boxShadow: active
                              ? [const BoxShadow(color: Color(0x0D000000),
                                  blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Text(p.label,
                          textAlign: TextAlign.center,
                          style: AppFonts.banglaBody(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                            color: active ? _T.fg : _T.mutedFg,
                ),
              ),
            ),
          ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _T.secondary,
              borderRadius: BorderRadius.circular(_T.rLg),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 18, color: _T.fg),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Body ────────────────────────────────────────────
class _DashBody extends StatelessWidget {
  final _ReportData    data;
  final String         company;
  final _Period        period;
  final VoidCallback   onViewFullReport;
  final VoidCallback   onExportPdf;

  const _DashBody({
    required this.data,
    required this.company,
    required this.period,
    required this.onViewFullReport,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero financial card
        _HeroCard(data: data),
        const SizedBox(height: 24),
        // Quick KPI row (4 items)
        _QuickKpiRow(data: data),
        const SizedBox(height: 24),
        // Category tabs + 2×2 grid
        _CategorySection(data: data),
        const SizedBox(height: 24),
        // Bottom action bar
        _BottomBar(onExport: onExportPdf, onViewFull: onViewFullReport),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final _ReportData data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _T.primary,
        borderRadius: BorderRadius.circular(_T.rXl),
        boxShadow: const [BoxShadow(color: Color(0x14000000),
            blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Financial Summary',
                  style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w600,
                      color: Colors.white)),
                const SizedBox(height: 4),
                Text('Updated just now',
                    style: AppFonts.banglaBody(fontSize: 12,
                        color: Colors.white.withOpacity(0.8))),
              ]),
              // Mini sparkline
              CustomPaint(size: const Size(64, 24), painter: _SparkPainter()),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HeroStat(label: 'Cash In',  value: _taka(data.cashIn),  up: true),
              _Divider(),
              _HeroStat(label: 'Expense',  value: _taka(data.expense), up: false),
              _Divider(),
              _HeroStat(label: 'Profit',   value: _taka(data.profit),
                  up: data.profit >= 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final bool   up;
  const _HeroStat({required this.label, required this.value, required this.up});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppFonts.banglaBody(fontSize: 13,
          color: Colors.white.withOpacity(0.85))),
      const SizedBox(height: 6),
      Text(value, style: AppFonts.banglaData(fontSize: 22, fontWeight: FontWeight.w700,
          color: Colors.white)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(_T.rSm),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: Colors.white),
        ]),
      ),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 44, margin: const EdgeInsets.only(bottom: 6),
    color: Colors.white.withOpacity(0.2),
  );
}

class _SparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pts = [
      Offset(0, size.height * 0.85),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.75),
      Offset(size.width * 0.6, size.height * 0.25),
      Offset(size.width * 0.8, size.height * 0.45),
      Offset(size.width, size.height * 0.08),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── Quick KPI Row (4 items) ───────────────────────────────────
class _QuickKpiRow extends StatelessWidget {
  final _ReportData data;
  const _QuickKpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QKpi(Icons.account_balance_rounded, _taka(data.loan),       'Loan'),
      _QKpi(Icons.pie_chart_rounded,        '${data.avgRoi.toStringAsFixed(0)}%', 'ROI'),
      _QKpi(Icons.how_to_reg_rounded,       '${data.attendance}',  'Attend'),
      _QKpi(Icons.people_rounded,           '${data.clients}',     'Clients'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: items.map((k) => Expanded(child: Padding(
          padding: EdgeInsets.only(
              right: k == items.last ? 0 : 12),
          child: _QuickKpiCard(kpi: k),
        ))).toList(),
      ),
    );
  }
}

class _QKpi {
  final IconData icon;
  final String   value, label;
  const _QKpi(this.icon, this.value, this.label);
}

class _QuickKpiCard extends StatelessWidget {
  final _QKpi kpi;
  const _QuickKpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.rLg),
      ),
      child: Column(children: [
        Icon(kpi.icon, size: 20, color: _T.primary),
        const SizedBox(height: 6),
        Text(kpi.value,
            style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w700,
                color: _T.fg),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(kpi.label,
            style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w500,
                color: _T.mutedFg)),
      ]),
    );
  }
}

// ── Category Section ──────────────────────────────────────────
enum _Cat { finance, operations, hr, sales }

class _CategorySection extends StatefulWidget {
  final _ReportData data;
  const _CategorySection({required this.data});
  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  _Cat _cat = _Cat.finance;

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Category tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: _Cat.values.map((c) {
              final active = c == _cat;
              final labels = {
                _Cat.finance:    'Finance',
                _Cat.operations: 'Operations',
                _Cat.hr:         'HR',
                _Cat.sales:      'Sales',
              };
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _cat = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                      color: active ? _T.primary : _T.secondary,
                      borderRadius: BorderRadius.circular(_T.rXl),
                    ),
                    child: Text(labels[c]!,
                        style: AppFonts.banglaBody(
                    fontSize: 14,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? _T.primaryFg : _T.secondaryFg,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        // 2×2 grid for selected category
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _CatGrid(cat: _cat, data: widget.data),
        ),
      ],
    );
  }
}

class _CatGrid extends StatelessWidget {
  final _Cat        cat;
  final _ReportData data;
  const _CatGrid({required this.cat, required this.data});

  List<_GridCard> _cards() {
    switch (cat) {
      case _Cat.finance:
        return [
          _GridCard(Icons.account_balance_wallet_rounded, 'Budget',
              _taka(data.avgBudget), true),
          _GridCard(Icons.credit_card_rounded, 'Loan',
              _taka(data.loan), data.loan == 0),
          _GridCard(Icons.percent_rounded, 'Profit Margin',
              '${data.profitMargin.toStringAsFixed(1)}%', data.profit >= 0),
          _GridCard(Icons.bar_chart_rounded, 'Avg ROI',
              '${data.avgRoi.toStringAsFixed(1)}%', data.avgRoi >= 0),
        ];
      case _Cat.operations:
        return [
          _GridCard(Icons.factory_rounded, 'Production',
              '${NumberFormat('#,##0').format(data.production)}', true),
          _GridCard(Icons.inventory_2_rounded, 'Stock',
              '${NumberFormat('#,##0').format(data.stock)}', data.stock > 0),
          _GridCard(Icons.science_rounded, 'R&D Running',
              '${data.rndProjects}', true),
          _GridCard(Icons.assignment_rounded, 'Work Orders',
              '${data.workOrders}', true),
        ];
      case _Cat.hr:
        return [
          _GridCard(Icons.people_rounded, 'Employees',
              '${data.employees}', true),
          _GridCard(Icons.how_to_reg_rounded, 'Attendance',
              '${data.attendance}', data.attendance > 0),
          _GridCard(Icons.trending_up_rounded, 'Avg ROI',
              '${data.avgRoi.toStringAsFixed(1)}%', data.avgRoi >= 0),
          _GridCard(Icons.account_balance_rounded, 'Loan',
              _taka(data.loan), data.loan == 0),
        ];
      case _Cat.sales:
        return [
          _GridCard(Icons.business_center_rounded, 'Clients',
              '${NumberFormat('#,##0').format(data.clients)}', true),
          _GridCard(Icons.campaign_rounded, 'Campaigns',
              '${data.campaigns}', true),
          _GridCard(Icons.pie_chart_rounded, 'Avg Budget',
              _taka(data.avgBudget), true),
          _GridCard(Icons.bar_chart_rounded, 'Avg ROI',
              '${data.avgRoi.toStringAsFixed(1)}%', data.avgRoi >= 0),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: cards.map((c) => _GridCardWidget(card: c)).toList(),
    );
  }
}

class _GridCard {
  final IconData icon;
  final String   label, value;
  final bool     positive;
  const _GridCard(this.icon, this.label, this.value, this.positive);
}

class _GridCardWidget extends StatelessWidget {
  final _GridCard card;
  const _GridCardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    final badge = card.positive ? _T.success : _T.destructive;
    final badgeFg = card.positive ? _T.successFg : _T.destructiveFg;
    final trendIcon = card.positive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _T.secondary,
                  borderRadius: BorderRadius.circular(_T.rMd),
                ),
                child: Icon(card.icon, size: 18, color: _T.fg),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badge,
                  borderRadius: BorderRadius.circular(_T.rSm),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(trendIcon, size: 12, color: badgeFg),
                ]),
              ),
            ],
          ),
          const Spacer(),
          Text(card.label,
              style: AppFonts.banglaBody(fontSize: 13, color: _T.mutedFg,
                  fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(card.value,
              style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w700,
                  color: _T.fg),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Bottom Action Bar ─────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final VoidCallback onExport, onViewFull;
  const _BottomBar({required this.onExport, required this.onViewFull});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _T.border)),
      ),
      child: Row(children: [
        Expanded(
          child: _ActionBtn(
            label: 'Export PDF',
            bg: _T.secondary, fg: _T.secondaryFg,
            onTap: onExport,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionBtn(
            label: 'View Full Report',
            bg: _T.primary, fg: _T.primaryFg,
            onTap: onViewFull,
          ),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color  bg, fg;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.bg,
      required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_T.rMd),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: AppFonts.banglaBody(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FULL REPORT SCREEN
// ─────────────────────────────────────────────────────────────
class _FullReportScreen extends StatelessWidget {
  final _ReportData data;
  final _Period     period;
  final String      company;

  const _FullReportScreen({
    required this.data,
    required this.period,
    required this.company,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _T.border))),
              child: Row(children: [
                _CircleBtn(icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context)),
                const Spacer(),
              Text('Full Report',
                  style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w600,
                      color: _T.fg)),
                const Spacer(),
                _CircleBtn(
                  icon: Icons.share_rounded,
                  onTap: () async {
                    final bytes = await _buildPdf(data, period, company);
                    final file  = await _savePdfToDevice(bytes, company);
                    await Share.shareXFiles([XFile(file.path)],
                        text: '$company Report');
                  },
                ),
              ]),
            ),
            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Context row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(spacing: 8, children: [
                        _Badge(Icons.business_rounded, company, _T.secondary, _T.secondaryFg),
                        _Badge(Icons.calendar_month_rounded, period.fullLabel,
                            _T.card, _T.mutedFg, border: true),
                      ]),
                      Text('Updated just now',
                          style: AppFonts.banglaBody(fontSize: 11, color: _T.mutedFg)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Executive Full Report',
                      style: AppFonts.banglaData(fontSize: 20, fontWeight: FontWeight.w700,
                          color: _T.fg)),
                  const SizedBox(height: 24),

                  // Executive Summary card
                  _InsightCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Executive Summary',
                    badge: data.profit >= 0 ? 'Overall: Healthy' : 'Needs Review',
                    badgeColor: data.profit >= 0 ? _T.success : _T.destructive,
                    badgeFg: data.profit >= 0 ? _T.successFg : _T.destructiveFg,
                    bullets: [
                      _Bullet(_T.success,
                          'Profit for the period is ${_fmtFull(data.profit)}'
                          '${data.profit >= 0 ? ', indicating positive performance.' : ', indicating a net loss.'}'),
                      _Bullet(_T.primary,
                          'Cash In reached ${_fmtFull(data.cashIn)} while Expense was '
                          '${_fmtFull(data.expense)}, giving a margin of '
                          '${data.profitMargin.toStringAsFixed(1)}%.'),
                      _Bullet(_T.warning,
                          'ROI sits at ${data.avgRoi.toStringAsFixed(1)}% and '
                          'Attendance records at ${data.attendance}, supporting '
                          'financial and HR performance.'),
                      _Bullet(_T.accent,
                          'Client base stands at '
                          '${NumberFormat('#,##0').format(data.clients)} with '
                          '${data.campaigns} active campaigns.'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Growth & Trend
                  _SectionCard(
                    icon: Icons.trending_up_rounded,
                    title: 'Growth & Trend Overview',
                    subtitle: 'vs previous period',
                    child: Column(children: [
                      _TrendRow('Revenue & Cash In', _fmtFull(data.cashIn), true),
                      const SizedBox(height: 8),
                      _TrendRow('Profitability', '${_fmtFull(data.profit)} profit',
                          data.profit >= 0),
                      const SizedBox(height: 8),
                      _TrendRow('Cost Efficiency', '${_fmtFull(data.expense)} expense',
                          data.expense < data.cashIn),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Key Focus Areas
                  _FocusAreas(data: data),
                  const SizedBox(height: 16),

                  // Risks & Opportunities
                  _RisksCard(data: data),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _T.border))),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _PdfPreviewScreen(
                      data: data, period: period, company: company))),
                  icon: const Icon(Icons.cloud_download_rounded, size: 20),
                  label: Text('Download PDF Document',
                      style: AppFonts.banglaBody(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.primary, foregroundColor: _T.primaryFg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_T.rMd)),
                    elevation: 2,
                  ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Full Report sub-widgets ───────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    bg, fg;
  final bool     border;
  const _Badge(this.icon, this.label, this.bg, this.fg, {this.border = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: border ? Border.all(color: _T.border) : null,
        borderRadius: BorderRadius.circular(_T.rSm),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 6),
        Text(label, style: AppFonts.banglaBody(fontSize: 12, fontWeight: FontWeight.w600,
            color: fg)),
      ]),
    );
  }
}

class _Bullet {
  final Color  dot;
  final String text;
  const _Bullet(this.dot, this.text);
}

class _InsightCard extends StatelessWidget {
  final IconData   icon;
  final String     title, badge;
  final Color      badgeColor, badgeFg;
  final List<_Bullet> bullets;
  const _InsightCard({required this.icon, required this.title,
      required this.badge, required this.badgeColor, required this.badgeFg,
      required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.rLg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: _T.primary),
          const SizedBox(width: 8),
          Text(title, style: AppFonts.banglaBody(fontSize: 14,
              fontWeight: FontWeight.w600, color: _T.fg)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: badgeColor,
                borderRadius: BorderRadius.circular(_T.rSm)),
            child: Text(badge, style: AppFonts.banglaBody(fontSize: 11,
                fontWeight: FontWeight.w600, color: badgeFg)),
          ),
        ]),
        const SizedBox(height: 10),
        ...bullets.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: b.dot, shape: BoxShape.circle)),
            ),
            Expanded(child: Text(b.text,
                style: AppFonts.banglaBody(fontSize: 13, color: _T.mutedFg))),
          ]),
        )),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String   title, subtitle;
  final Widget   child;
  const _SectionCard({required this.icon, required this.title,
      required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.rLg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: _T.primary),
          const SizedBox(width: 8),
          Text(title, style: AppFonts.banglaBody(fontSize: 14,
              fontWeight: FontWeight.w600, color: _T.fg)),
          const Spacer(),
          Text(subtitle, style: AppFonts.banglaBody(fontSize: 11, color: _T.mutedFg)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String label, value;
  final bool   positive;
  const _TrendRow(this.label, this.value, this.positive);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppFonts.banglaBody(fontSize: 12, color: _T.mutedFg)),
          Text(value, style: AppFonts.banglaBody(fontSize: 13,
              fontWeight: FontWeight.w600, color: _T.fg)),
        ]),
            Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
            color: positive ? _T.success : _T.destructive,
            borderRadius: BorderRadius.circular(_T.rSm),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 12,
                color: positive ? _T.successFg : _T.destructiveFg),
            const SizedBox(width: 2),
            Text(positive ? 'Growth' : 'Decline',
                style: AppFonts.banglaBody(fontSize: 11,
                    color: positive ? _T.successFg : _T.destructiveFg)),
          ]),
        ),
      ],
    );
  }
}

class _FocusAreas extends StatelessWidget {
  final _ReportData data;
  const _FocusAreas({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.track_changes_rounded, size: 18, color: _T.primary),
        const SizedBox(width: 8),
        Text('Key Focus Areas',
            style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600, color: _T.fg)),
        const Spacer(),
        Text('Finance · Ops · HR · Sales',
            style: AppFonts.banglaBody(fontSize: 11, color: _T.mutedFg)),
      ]),
      const SizedBox(height: 12),
      _FocusCard(
        icon: Icons.account_balance_rounded,
        title: 'Finance',
        status: data.profit >= 0 ? 'On track' : 'Review needed',
        statusOk: data.profit >= 0,
        body: 'Budget avg ${_taka(data.avgBudget)}, loans ${_taka(data.loan)}, '
            'profit margin ${data.profitMargin.toStringAsFixed(1)}%.',
        suggestion: data.profit >= 0
            ? 'Maintain spending discipline while increasing growth investments.'
            : 'Review expense categories and reduce non-essential spending.',
      ),
      const SizedBox(height: 12),
      _FocusCard(
        icon: Icons.factory_rounded,
        title: 'Operations',
        status: data.stock > 0 ? 'Active' : 'Watch stock',
        statusOk: data.stock > 0,
        body: 'Production ${NumberFormat('#,##0').format(data.production)} units, '
            '${data.workOrders} work orders, stock at '
            '${NumberFormat('#,##0').format(data.stock)} units.',
        suggestion: 'Prioritize replenishment planning and review lead times.',
      ),
      const SizedBox(height: 12),
      _FocusCard(
        icon: Icons.badge_rounded,
        title: 'HR',
        status: data.employees > 0 ? 'Strong' : 'No data',
        statusOk: data.employees > 0,
        body: 'Headcount ${data.employees}, attendance records ${data.attendance}, '
            '${data.rndProjects} R&D projects running.',
        suggestion: 'Focus HR programs on managing leave volumes and sustaining engagement.',
      ),
      const SizedBox(height: 12),
      _FocusCard(
        icon: Icons.shopping_bag_rounded,
        title: 'Sales',
        status: data.clients > 0 ? 'Growing' : 'Build pipeline',
        statusOk: data.clients > 0,
        body: '${NumberFormat('#,##0').format(data.clients)} clients, '
            '${data.campaigns} active campaigns, '
            'avg ROI ${data.avgRoi.toStringAsFixed(1)}%.',
        suggestion: 'Intensify follow-up on open leads to convert momentum into revenue.',
      ),
    ]);
  }
}

class _FocusCard extends StatelessWidget {
  final IconData icon;
  final String   title, status, body, suggestion;
  final bool     statusOk;
  const _FocusCard({required this.icon, required this.title,
      required this.status, required this.statusOk,
      required this.body, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.rMd),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _T.secondary,
              borderRadius: BorderRadius.circular(_T.rMd)),
          child: Icon(icon, size: 18, color: _T.secondaryFg),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: AppFonts.banglaBody(fontSize: 13,
                fontWeight: FontWeight.w600, color: _T.fg)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: statusOk ? _T.success : _T.warning,
                borderRadius: BorderRadius.circular(_T.rSm),
              ),
              child: Text(status,
                  style: AppFonts.banglaBody(fontSize: 11,
                      color: statusOk ? _T.successFg : _T.warningFg)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(body, style: AppFonts.banglaBody(fontSize: 12, color: _T.mutedFg)),
                const SizedBox(height: 2),
          RichText(text: TextSpan(
            style: AppFonts.banglaBody(fontSize: 12, color: _T.mutedFg),
            children: [
              TextSpan(text: 'Suggestion: ',
                  style: AppFonts.banglaBody(fontWeight: FontWeight.w500, color: _T.fg)),
              TextSpan(text: suggestion),
            ],
          )),
        ])),
      ]),
    );
  }
}

class _RisksCard extends StatelessWidget {
  final _ReportData data;
  const _RisksCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
        color: _T.card,
        border: Border.all(color: _T.border),
        borderRadius: BorderRadius.circular(_T.rLg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: _T.warning),
          const SizedBox(width: 8),
          Text('Risks & Opportunities',
              style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600, color: _T.fg)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.trending_down_rounded, size: 14, color: _T.warning),
                    const SizedBox(width: 6),
          Expanded(child: RichText(text: TextSpan(
            style: AppFonts.banglaBody(fontSize: 12, color: _T.mutedFg),
            children: [
              TextSpan(text: 'Risk: ',
                  style: AppFonts.banglaBody(fontWeight: FontWeight.w500, color: _T.fg)),
              TextSpan(text: data.stock < 100
                  ? 'Low stock levels and active loans could impact delivery if demand spikes.'
                  : 'Monitor loan obligations and ensure stock replenishment stays on schedule.'),
            ],
          ))),
        ]),
              const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.trending_up_rounded, size: 14, color: _T.success),
          const SizedBox(width: 6),
          Expanded(child: RichText(text: TextSpan(
            style: AppFonts.banglaBody(fontSize: 12, color: _T.mutedFg),
            children: [
              TextSpan(text: 'Opportunity: ',
                  style: AppFonts.banglaBody(fontWeight: FontWeight.w500, color: _T.fg)),
              TextSpan(text: data.profit >= 0
                  ? 'Strong profit and client growth create room to accelerate investments in Operations and Sales.'
                  : 'Focus on converting existing leads and optimising campaign ROI to return to profitability.'),
            ],
          ))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PDF PREVIEW SCREEN
// ─────────────────────────────────────────────────────────────
class _PdfPreviewScreen extends StatefulWidget {
  final _ReportData data;
  final _Period     period;
  final String      company;
  const _PdfPreviewScreen({required this.data, required this.period,
      required this.company});
  @override
  State<_PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<_PdfPreviewScreen> {
  Uint8List? _bytes;
  bool       _busy = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final b = await _buildPdf(widget.data, widget.period, widget.company);
      if (mounted) setState(() { _bytes = b; _busy = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e')),
        );
      }
    }
  }

  Future<void> _savePdf() async {
    if (_bytes == null) return;
    setState(() => _busy = true);
    try {
      final file = await _savePdfToDevice(_bytes!, widget.company);
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_bytes == null) return;
    setState(() => _busy = true);
    try {
      final file = await _savePdfToDevice(_bytes!, widget.company);
      await Share.shareXFiles([XFile(file.path)],
          text: '${widget.company} Report');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _T.border))),
              child: Row(children: [
                _CircleBtn(icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context)),
                const Spacer(),
              Text('Document Preview',
                  style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w600,
                      color: _T.fg)),
                const Spacer(),
                const SizedBox(width: 36),
              ]),
            ),
            // Preview area
            Expanded(
              child: _busy && _bytes == null
                  ? const Center(child: CircularProgressIndicator(color: _T.primary))
                  : _bytes != null
                      ? PdfPreview(
                          build: (_) async => _bytes!,
                          allowPrinting: true,
                          allowSharing: true,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          pdfFileName:
                              '${widget.company.replaceAll(' ', '_')}_Report.pdf',
                        )
                      : const Center(child: Text('Failed to generate preview')),
            ),
            // Bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _T.border))),
              child: Row(children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Share',
                    bg: _T.secondary, fg: _T.secondaryFg,
                    onTap: _busy ? () {} : _sharePdf,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _busy
                      ? Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: _T.primary,
                            borderRadius: BorderRadius.circular(_T.rMd),
                          ),
                          child: const Center(
                            child: SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                          ),
                        )
                      : _ActionBtn(
                          label: 'Save PDF',
                          bg: _T.primary, fg: _T.primaryFg,
                          onTap: _savePdf,
                        ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED UTILITY WIDGETS
// ─────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(
          color: _T.secondary, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: _T.fg),
      ),
    );
  }
}
