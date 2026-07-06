// lib/features/hr/presentation/screens/balance_update_screen.dart
//
// HR Balance & Cash-Flow Screen
// ─────────────────────────────────────────────────────────────────────────────
// Three live data sources (all via StreamBuilder):
//
//  1. company_profile/main  → cashIn, cashOut  (running totals)
//     Balance = cashIn − cashOut
//
//  2. cash_flow             → individual cash-in / cash-out / reversal entries
//     Created by:
//       • HR slip approval  → type: 'cash_in'
//       • Payroll payment   → type: 'cash_out'
//       • Payroll reversal  → type: 'reversal'
//       • Procurement       → type: 'cash_out'
//
//  3. ledger + expenses     → kept for the period-scoped Credit/Expense charts
//
// Currency:
//   • All running totals are stored in BDT (company base currency).
//   • Foreign-currency slips are converted at the live rate before approval;
//     the confirmed BDT amount is what gets written to cashIn.
//   • Each cash_flow entry stores its original currency + converted BDT amount.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/document_extractor/currency_converter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand   = Color(0xFF065F46); // HR Green
const Color _mid     = Color(0xFF059669); // Emerald
const Color _surface = Color(0xFFF8FAFC); // Slate 50
const Color _cashIn  = Color(0xFF16A34A); // Success
const Color _cashOut = Color(0xFFDC2626); // Danger
const Color _neutral = Color(0xFF0891B2); // Cyan
const Color _warn    = Color(0xFFEA580C); // Orange


class BalanceUpdateScreen extends StatefulWidget {
  const BalanceUpdateScreen({super.key});

  @override
  State<BalanceUpdateScreen> createState() => _BalanceUpdateScreenState();
}

class _BalanceUpdateScreenState extends State<BalanceUpdateScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  late TabController _tabs;

  final _money   = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('d MMM yyyy');

  // Period filter (for ledger/expense charts)
  late DateTime _periodStart;
  late DateTime _periodEnd;

  // Colour palette for charts
  static const List<Color> _palette = [
    Color(0xFF065F46), Color(0xFF2563EB), Color(0xFFEA580C),
    Color(0xFF7C3AED), Color(0xFF0369A1), Color(0xFF16A34A),
    Color(0xFFDC2626), Color(0xFFD97706), Color(0xFF0891B2),
    Color(0xFF9333EA), Color(0xFF15803D), Color(0xFF1D4ED8),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Queries ───────────────────────────────────────────────────────────────
  Stream<DocumentSnapshot> get _profileStream =>
      DB.colSync(_cid, C.companyProfile).doc('main').snapshots();

  Stream<QuerySnapshot> get _cashFlowStream =>
      DB.colSync(_cid, C.cashFlow)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots();

  Query _ledgerQuery() => DB.colSync(_cid, C.ledger)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
      .orderBy('date', descending: true);

  Query _expensesQuery() => DB.colSync(_cid, C.expenses)
      .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
      .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
      .orderBy('dueDate', descending: true);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
        appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _mid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text('Balance & Cash Flow',
            style: AppFonts.banglaHeading(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Credits'),
            Tab(text: 'Transactions'),
            Tab(text: 'Analytics'),
          ],
        ),

      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : TabBarView(
              controller: _tabs,
                children: [
                _OverviewTab(
                  cid:          _cid,
                  profileStream: _profileStream,
                  cashFlowStream: _cashFlowStream,
                  money:        _money,
                  dateFmt:      _dateFmt,
                ),
                _CreditsTab(
                  cid:    _cid,
                  money:  _money,
                  dateFmt: _dateFmt,
                ),
                _TransactionsTab(
                  cashFlowStream: _cashFlowStream,
                  money:          _money,
                  dateFmt:        _dateFmt,
                ),
                _AnalyticsTab(
                  cid:          _cid,
                  periodStart:  _periodStart,
                  periodEnd:    _periodEnd,
                  ledgerQuery:  _ledgerQuery,
                  expensesQuery: _expensesQuery,
                  money:        _money,
                  palette:      _palette,
                  onPickPeriod: _pickPeriod,
                ),
              ],
            ),
    );
  }

  // ── Period picker ─────────────────────────────────────────────────────────
  Future<void> _pickPeriod() async {
    final now       = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd   = DateTime(now.year, now.month, 0, 23, 59, 59);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),

      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Choose Period',
                style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _PeriodOption(icon: Icons.today, label: 'This Month', onTap: () {
                setState(() {
                  _periodStart = thisStart;
                _periodEnd   = DateTime(
                    thisStart.year, thisStart.month + 1, 0, 23, 59, 59);
                });
                Navigator.pop(context);
            }),
            const SizedBox(height: 8),
            _PeriodOption(icon: Icons.history, label: 'Last Month', onTap: () {
                setState(() {
                  _periodStart = lastStart;
                _periodEnd   = lastEnd;
                });
                Navigator.pop(context);
            }),
            const SizedBox(height: 8),
            _PeriodOption(
              icon: Icons.calendar_month_outlined,
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

  // ── PDF export ────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    final profileSnap  = await DB.colSync(_cid, C.companyProfile).doc('main').get();
    final cashFlowSnap = await DB.colSync(_cid, C.cashFlow)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final pd = profileSnap.data() ?? {};
    final cashIn  = _n(pd['cashIn']);
    final cashOut = _n(pd['cashOut']);
    final balance = cashIn - cashOut;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base:       pw.Font.times(),
        bold:       pw.Font.timesBold(),
        italic:     pw.Font.timesItalic(),
        boldItalic: pw.Font.timesBoldItalic(),
      ),
    );

    final now     = DateTime.now();
    final dateFmt = DateFormat('d MMMM yyyy');
    final numFmt  = NumberFormat('#,##0.00');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
      header: (_) => pw.Column(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF065F46)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
              pw.Text('BALANCE & CASH FLOW REPORT',
                  style: pw.TextStyle(
                      font: pw.Font.timesBold(), fontSize: 14,
                      color: PdfColors.white)),
              pw.Text('Generated: ${dateFmt.format(now)}',
                  style: pw.TextStyle(
                      font: pw.Font.times(), fontSize: 9,
                      color: PdfColors.white)),
            ],
          ),
        ),

        pw.SizedBox(height: 12),
      ]),
      build: (_) => [
        // Summary row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _pdfKpi(pw.Font.timesBold(), pw.Font.times(),
                'Cash In (BDT)', numFmt.format(cashIn),
                const PdfColor.fromInt(0xFF16A34A)),
            _pdfKpi(pw.Font.timesBold(), pw.Font.times(),
                'Cash Out (BDT)', numFmt.format(cashOut),
                const PdfColor.fromInt(0xFFDC2626)),
            _pdfKpi(pw.Font.timesBold(), pw.Font.times(),
                'Balance (BDT)', numFmt.format(balance),
                balance >= 0
                    ? const PdfColor.fromInt(0xFF2563EB)
                    : const PdfColor.fromInt(0xFFDC2626)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Transaction History',
            style: pw.TextStyle(
                font: pw.Font.timesBold(), fontSize: 13)),
        pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
          headers: ['Date', 'Type', 'Description', 'Currency', 'Amount (BDT)'],
          headerStyle: pw.TextStyle(
              font: pw.Font.timesBold(), fontSize: 9,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF065F46)),
          cellStyle: pw.TextStyle(font: pw.Font.times(), fontSize: 8),
          data: cashFlowSnap.docs.map((doc) {
            final d    = doc.data();
            final date = d['createdAt'] is Timestamp
                ? dateFmt.format((d['createdAt'] as Timestamp).toDate())
                : '—';
            final type = (d['type'] as String? ?? '').toUpperCase();
            final desc = d['description'] as String? ??
                         d['invoiceNo'] as String? ?? '—';
            final ccy  = d['currency'] as String? ?? 'BDT';
            final amt  = _n(d['amount']);
            return [date, type, desc, ccy, numFmt.format(amt)];
              }).toList(),
            ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }
}

pw.Widget _pdfKpi(pw.Font bold, pw.Font regular,
    String label, String value, PdfColor color) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: regular, fontSize: 8,
                  color: const PdfColor.fromInt(0xFF64748B))),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(font: bold, fontSize: 14, color: color)),
        ],
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — OVERVIEW
// Hero balance card + last 5 cash-in and cash-out entries
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final String                   cid;
  final Stream<DocumentSnapshot> profileStream;
  final Stream<QuerySnapshot>    cashFlowStream;
  final NumberFormat             money;
  final DateFormat               dateFmt;

  const _OverviewTab({
    required this.cid,
    required this.profileStream,
    required this.cashFlowStream,
    required this.money,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: profileStream,
      builder: (ctx, profileSnap) {
        final pd      = profileSnap.data?.data() as Map<String, dynamic>? ?? {};
        final cashIn  = _n(pd['cashIn']);
        final cashOut = _n(pd['cashOut']);
        final balance = cashIn - cashOut;
        final isPos   = balance >= 0;

        return StreamBuilder<QuerySnapshot>(
          stream: cashFlowStream,
          builder: (ctx2, cfSnap) {
            final cfDocs = cfSnap.data?.docs ?? [];

            // Period-scoped totals from cash_flow
            final now   = DateTime.now();
            final mStart = DateTime(now.year, now.month, 1);
            double monthIn  = 0;
            double monthOut = 0;
            for (final d in cfDocs) {
              final m  = d.data() as Map<String, dynamic>;
              
              // Real-life accuracy: Ignore voided entries in totals
              if ((m['status'] ?? '') == 'voided') continue;
              
              final ts = m['createdAt'];
              if (ts is! Timestamp) continue;
              final dt = ts.toDate();
              if (dt.isBefore(mStart)) continue;
              final amt = _n(m['amount']).toDouble();
              final t   = m['type'] as String? ?? '';
              if (t == 'cash_in') {
                monthIn += amt;
              } else if (t == 'cash_out') {
                monthOut += amt;
              } else if (t == 'reversal') {
                monthOut -= amt; // reversal reduces cash_out
              }
            }


            // Last payment slip approval
            final lastSlip = cfDocs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['type'] == 'cash_in')
                .firstOrNull;
            final lastSlipData =
                lastSlip?.data() as Map<String, dynamic>? ?? {};

            return RefreshIndicator(
              color: _brand,
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Hero balance card ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPos
                            ? [const Color(0xFF065F46), const Color(0xFF059669)]
                            : [const Color(0xFF991B1B), const Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: (isPos ? _brand : _cashOut)
                                .withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                        ],
      ),
      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                        Row(children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text('Current Balance',
                              style: AppFonts.banglaBody(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isPos ? 'Positive' : 'Negative',
                              style: AppFonts.banglaHeading(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          'BDT ${money.format(balance)}',
                          style: AppFonts.banglaData(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cash In − Cash Out',
                          style: AppFonts.banglaBody(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        // Cash-in / Cash-out sub-row
                        Row(children: [
                          Expanded(
                            child: _HeroSubStat(
                              label: 'Total Cash In',
                              value: 'BDT ${money.format(cashIn)}',
                              icon: Icons.arrow_downward_rounded,
                              color: const Color(0xFF86EFAC),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroSubStat(
                              label: 'Total Cash Out',
                              value: 'BDT ${money.format(cashOut)}',
                              icon: Icons.arrow_upward_rounded,
                              color: const Color(0xFFFCA5A5),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── This month mini-cards ────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _MiniStatCard(
                        label: 'This Month In',
                        value: 'BDT ${money.format(monthIn)}',
                        icon: Icons.south_west_rounded,
                        color: _cashIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStatCard(
                        label: 'This Month Out',
                        value: 'BDT ${money.format(monthOut)}',
                        icon: Icons.north_east_rounded,
                        color: _cashOut,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Last approved slip ───────────────────────────────────
                  if (lastSlipData.isNotEmpty) ...[
                    _SectionHeader('Last Payment Received'),
          const SizedBox(height: 8),
                    _LastSlipCard(data: lastSlipData, money: money, dateFmt: dateFmt),
                    const SizedBox(height: 20),
                  ],

                  // ── Recent cash-in entries ───────────────────────────────
                  _SectionHeader('Recent Cash In'),
                  const SizedBox(height: 8),
                  ...cfDocs
                      .where((d) =>
                          (d.data() as Map<String, dynamic>)['type'] ==
                          'cash_in')
                      .take(5)
                      .map((d) => _CfTile(
                            data:   d.data() as Map<String, dynamic>,
                            money:  money,
                            dateFmt: dateFmt,
                          )),

                  const SizedBox(height: 20),

                  // ── Recent cash-out entries ──────────────────────────────
                  _SectionHeader('Recent Cash Out'),
                  const SizedBox(height: 8),
                  ...cfDocs
                      .where((d) {
                        final t = (d.data() as Map<String, dynamic>)['type']
                            as String? ?? '';
                        return t == 'cash_out' || t == 'reversal';
                      })
                      .take(5)
                      .map((d) => _CfTile(
                            data:   d.data() as Map<String, dynamic>,
                            money:  money,
                            dateFmt: dateFmt,
                          )),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — TRANSACTIONS (full cash_flow feed)
// ─────────────────────────────────────────────────────────────────────────────
class _TransactionsTab extends StatefulWidget {
  final Stream<QuerySnapshot> cashFlowStream;
  final NumberFormat          money;
  final DateFormat            dateFmt;

  const _TransactionsTab({
    required this.cashFlowStream,
    required this.money,
    required this.dateFmt,
  });

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  String _filter = 'all'; // all | cash_in | cash_out | reversal

  @override
  Widget build(BuildContext context) {
    return Column(
          children: [
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip('All',      'all',      _filter, (v) => setState(() => _filter = v)),
              const SizedBox(width: 8),
              _FilterChip('Cash In',  'cash_in',  _filter, (v) => setState(() => _filter = v)),
              const SizedBox(width: 8),
              _FilterChip('Cash Out', 'cash_out', _filter, (v) => setState(() => _filter = v)),
              const SizedBox(width: 8),
              _FilterChip('Reversal', 'reversal', _filter, (v) => setState(() => _filter = v)),
            ]),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.cashFlowStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _brand));
              }
              var docs = snap.data?.docs ?? [];
              
              // Real-life accuracy: exclude voided entries from history
              docs = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] != 'voided').toList();

              if (_filter != 'all') {
                docs = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['type'] == _filter)
                    .toList();
              }

              if (docs.isEmpty) {
                return Center(
        child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
          children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 56, color: Colors.black12),
            const SizedBox(height: 12),
                      Text(
                        _filter == 'all'
                            ? 'No transactions yet'
                            : 'No ${_filter.replaceAll('_', ' ')} transactions',
                        style: AppFonts.banglaHeading(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black38),
            ),
          ],
        ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CfTile(
                  data:    docs[i].data() as Map<String, dynamic>,
                  money:   widget.money,
                  dateFmt: widget.dateFmt,
                  expanded: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — CREDITS  (all cash_in entries with live USD→BDT conversion)
// ─────────────────────────────────────────────────────────────────────────────
class _CreditsTab extends StatefulWidget {
  final String     cid;
  final NumberFormat money;
  final DateFormat   dateFmt;
  const _CreditsTab({
    required this.cid,
    required this.money,
    required this.dateFmt,
  });
  @override
  State<_CreditsTab> createState() => _CreditsTabState();
}

class _CreditsTabState extends State<_CreditsTab> {
  // Converted BDT amounts keyed by doc-id
  final Map<String, double> _bdtAmounts = {};
  final Map<String, bool>   _converting = {};

  Future<void> _ensureConverted(String docId, double amount, String currency) async {
    if (currency.toUpperCase() == 'BDT') {
      if (_bdtAmounts[docId] != amount) {
        if (mounted) setState(() => _bdtAmounts[docId] = amount);
      }
      return;
    }
    if (_bdtAmounts.containsKey(docId) || (_converting[docId] ?? false)) return;
    if (mounted) setState(() => _converting[docId] = true);
    try {
      final result = await CurrencyConverter.convert(
        amount: amount,
        from:   currency,
        to:     'BDT',
      );
      if (mounted) {
        setState(() {
          _bdtAmounts[docId] = result.convertedAmount;
          _converting[docId] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _converting[docId] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditsStream = DB.colSync(widget.cid, C.cashFlow)
        .where('type', isEqualTo: 'cash_in')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: creditsStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _brand));
        }
        final docs = snap.data?.docs ?? [];

        // Trigger conversions for any non-BDT entries
        for (final doc in docs) {
          final d   = doc.data() as Map<String, dynamic>;
          final amt = _n(d['amount']).toDouble();
          final ccy = (d['currency'] as String? ?? 'BDT').toUpperCase();
          _ensureConverted(doc.id, amt, ccy);
        }

        // Compute total credits in BDT
        double totalBdt = 0;
        for (final doc in docs) {
          final d   = doc.data() as Map<String, dynamic>;
          final amt = _n(d['amount']).toDouble();
          final ccy = (d['currency'] as String? ?? 'BDT').toUpperCase();
          if (ccy == 'BDT') {
            totalBdt += amt;
          } else {
            totalBdt += _bdtAmounts[doc.id] ?? 0;
          }
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 64, color: _brand.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text('No credits yet',
                    style: AppFonts.banglaHeading(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black38)),
                const SizedBox(height: 6),
                Text('Approved payment slips will appear here',
                    style: AppFonts.banglaBody(fontSize: 12, color: Colors.black26)),
              ],
        ),
      );
    }

    return Column(
      children: [
            // ── Summary hero ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _brand.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.trending_up_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
        Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Credits (BDT)',
                          style: AppFonts.banglaBody(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '৳ ${widget.money.format(totalBdt)}',
                        style: AppFonts.banglaData(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
        Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${docs.length}',
                        style: AppFonts.banglaData(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    Text('entries',
                        style: AppFonts.banglaBody(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final doc  = docs[i];
            final d    = doc.data() as Map<String, dynamic>;
                  final amt  = _n(d['amount']).toDouble();
                  final ccy  = (d['currency'] as String? ?? 'BDT').toUpperCase();
                  final bdtAmt = _bdtAmounts[doc.id];
                  final converting = _converting[doc.id] ?? false;
                  return _CreditEntryCard(
                    data:       d,
                    money:      widget.money,
                    dateFmt:    widget.dateFmt,
                    originalAmt: amt,
                    originalCcy: ccy,
                    bdtAmount:   bdtAmt,
                    converting:  converting,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Credit entry card (rich display with BDT conversion) ──────────────────────
class _CreditEntryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat         money;
  final DateFormat           dateFmt;
  final double               originalAmt;
  final String               originalCcy;
  final double?              bdtAmount;
  final bool                 converting;

  const _CreditEntryCard({
    required this.data,
    required this.money,
    required this.dateFmt,
    required this.originalAmt,
    required this.originalCcy,
    required this.bdtAmount,
    required this.converting,
  });

  @override
  Widget build(BuildContext context) {
    final invoiceNo  = data['invoiceNo']  as String? ?? '';
    final desc       = data['description'] as String? ?? '';
    final approvedBy = data['approvedByName'] as String? ??
                       data['approvedBy']     as String? ?? '';
    final edited     = data['amountEdited'] as bool? ?? false;
    final date       = data['createdAt'] is Timestamp
        ? dateFmt.format((data['createdAt'] as Timestamp).toDate())
        : '—';
    final isForeign  = originalCcy != 'BDT';
    final displayBdt = bdtAmount ?? (isForeign ? null : originalAmt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cashIn.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(children: [
            // Icon
        Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.south_west_rounded,
                  color: _cashIn, size: 20),
            ),
            const SizedBox(width: 12),
            // Title
        Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Cash In',
                        style: AppFonts.banglaHeading(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _cashIn)),
                    if (edited) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _warn.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('HR edited',
                            style: AppFonts.banglaHeading(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _warn)),
                      ),
                    ],
                    if (isForeign) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _neutral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('$originalCcy→BDT',
                            style: AppFonts.banglaHeading(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _neutral)),
                      ),
                    ],
                  ]),
                  if (invoiceNo.isNotEmpty)
                    Text('Invoice #$invoiceNo',
                        style: AppFonts.banglaHeading(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  if (desc.isNotEmpty)
                    Text(desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
                        style: AppFonts.banglaBody(
                            fontSize: 11, color: Colors.black45)),
                  Text(
                    approvedBy.isNotEmpty
                        ? 'By $approvedBy  •  $date'
                        : date,
                    style: AppFonts.banglaBody(
                        fontSize: 10, color: Colors.black38),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // BDT amount (primary)
                if (converting)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _brand),
                  )
                else if (displayBdt != null)
                  Text(
                    '৳ ${money.format(displayBdt)}',
                    style: AppFonts.banglaData(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _cashIn),
                  )
                else
                  Text(
                    '$originalCcy ${money.format(originalAmt)}',
                    style: AppFonts.banglaData(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _cashIn),
                  ),
                // Original foreign amount (secondary)
                if (isForeign && displayBdt != null)
                  Text(
                    '$originalCcy ${money.format(originalAmt)}',
                    style: AppFonts.banglaBody(
                        fontSize: 10, color: Colors.black38),
                  ),
              ],
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — TRANSACTIONS (full cash_flow feed)  [was TAB 2]
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — ANALYTICS (ledger + expenses charts, period-scoped)
// ─────────────────────────────────────────────────────────────────────────────
class _AnalyticsTab extends StatelessWidget {
  final String       cid;
  final DateTime     periodStart;
  final DateTime     periodEnd;
  final Query Function() ledgerQuery;
  final Query Function() expensesQuery;
  final NumberFormat money;
  final List<Color>  palette;
  final VoidCallback onPickPeriod;

  const _AnalyticsTab({
    required this.cid,
    required this.periodStart,
    required this.periodEnd,
    required this.ledgerQuery,
    required this.expensesQuery,
    required this.money,
    required this.palette,
    required this.onPickPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: ledgerQuery().snapshots(),
      builder: (ctx, ledgerSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: expensesQuery().snapshots(),
          builder: (ctx2, expSnap) {
            if (ledgerSnap.connectionState == ConnectionState.waiting ||
                expSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _brand));
            }

            final ledgerDocs  = ledgerSnap.data?.docs ?? [];
            final expenseDocs = expSnap.data?.docs ?? [];

            num totalCredit = 0;
            final Map<String, num> creditByAccount = {};
            for (final d in ledgerDocs) {
              final m = d.data() as Map<String, dynamic>;
              final c = _n(m['credit']);
              totalCredit += c;
              final acc = (m['account'] as String?)?.trim().isNotEmpty == true
                  ? m['account'] as String
                  : 'Other';
              creditByAccount[acc] = (creditByAccount[acc] ?? 0) + c;
            }

            num totalExpense = 0;
            final Map<String, num> expenseByCategory = {};
            for (final d in expenseDocs) {
              final m = d.data() as Map<String, dynamic>;
              final amt = _n(m['amount']);
              totalExpense += amt;
              final cat = (m['category'] as String?)?.trim().isNotEmpty == true
                  ? m['category'] as String
                  : 'Other';
              expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + amt;
            }

            final profit = totalCredit - totalExpense;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period picker
                GestureDetector(
                  onTap: onPickPeriod,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: _brand, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                    child: Text(
                          'Period: ${DateFormat('MMM yyyy').format(periodStart)}',
                          style: AppFonts.banglaHeading(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded,
                          color: _brand),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Summary row
                Row(children: [
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Ledger Credit',
                      value: money.format(totalCredit),
                      icon: Icons.trending_up_rounded,
                      color: _cashIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Expenses',
                      value: money.format(totalExpense),
                      icon: Icons.trending_down_rounded,
                      color: _cashOut,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _MiniStatCard(
                  label: 'Profit (Credit − Expense)',
                  value: money.format(profit),
                  icon: profit >= 0
                      ? Icons.arrow_circle_up_rounded
                      : Icons.arrow_circle_down_rounded,
                  color: profit >= 0 ? _cashIn : _cashOut,
                ),
                const SizedBox(height: 16),

                if (creditByAccount.isNotEmpty) ...[
                  _ChartCard(
                    title: 'Credit by Account',
                    child: _PieCard(
                        data: creditByAccount,
                        total: totalCredit.toDouble(),
                        palette: palette,
                        money: money),
                  ),
                  const SizedBox(height: 12),
                ],

                if (expenseByCategory.isNotEmpty) ...[
                  _ChartCard(
                    title: 'Expense by Category',
                    child: _PieCard(
                        data: expenseByCategory,
                        total: totalExpense.toDouble(),
                        palette: palette,
                        money: money),
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: 'Expense Breakdown (Bar)',
                    child: _BarCard(
                        data: expenseByCategory,
                        palette: palette,
                        money: money),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSubStat extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _HeroSubStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppFonts.banglaBody(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: AppFonts.banglaData(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

class _MiniStatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  const _MiniStatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Text(label,
                    style: AppFonts.banglaBody(
                        fontSize: 11,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    style: AppFonts.banglaData(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

class _LastSlipCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat         money;
  final DateFormat           dateFmt;
  const _LastSlipCard(
      {required this.data, required this.money, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final amount   = _n(data['amount']).toDouble();
    final currency = data['currency'] as String? ?? 'BDT';
    final invoiceNo = data['invoiceNo'] as String? ?? '—';
    final approvedBy = data['approvedByName'] as String? ??
        data['approvedBy'] as String? ?? '—';
    final date = data['createdAt'] is Timestamp
        ? dateFmt.format((data['createdAt'] as Timestamp).toDate())
        : '—';
    final edited = data['amountEdited'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cashIn.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: _cashIn.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _cashIn.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: _cashIn, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice #$invoiceNo',
                  style: AppFonts.banglaHeading(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              Text('$date  •  Approved by $approvedBy',
                  style: AppFonts.banglaBody(
                      fontSize: 11, color: Colors.black45)),
              if (edited)
                Text('Amount adjusted by HR',
                    style: AppFonts.banglaBody(
                        fontSize: 10, color: _warn,
                        fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$currency ${money.format(amount)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _cashIn)),
            const Text('Cash In',
                style: TextStyle(fontSize: 10, color: Colors.black38)),
          ],
        ),
      ]),
    );
  }
}

// ── Cash-flow tile ────────────────────────────────────────────────────────────
class _CfTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat         money;
  final DateFormat           dateFmt;
  final bool                 expanded;
  const _CfTile({
    required this.data,
    required this.money,
    required this.dateFmt,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final type      = data['type'] as String? ?? '';
    final amount    = _n(data['amount']).toDouble();
    final currency  = data['currency'] as String? ?? 'BDT';
    final desc      = data['description'] as String? ?? '';
    final invoiceNo = data['invoiceNo'] as String? ?? '';
    final date      = data['createdAt'] is Timestamp
        ? dateFmt.format((data['createdAt'] as Timestamp).toDate())
        : '—';
    final edited    = data['amountEdited'] as bool? ?? false;
    final approvedBy = data['approvedByName'] as String? ??
        data['approvedBy'] as String? ?? '';

    Color   tileColor;
    Color   iconBg;
    IconData icon;
    String  typeLabel;

    switch (type) {
      case 'cash_in':
        tileColor = _cashIn;
        iconBg    = const Color(0xFFDCFCE7);
        icon      = Icons.south_west_rounded;
        typeLabel = 'Cash In';
        break;
      case 'reversal':
        tileColor = _neutral;
        iconBg    = const Color(0xFFDBEAFE);
        icon      = Icons.undo_rounded;
        typeLabel = 'Reversal';
        break;
      default: // cash_out
        tileColor = _cashOut;
        iconBg    = const Color(0xFFFEE2E2);
        icon      = Icons.north_east_rounded;
        typeLabel = 'Cash Out';
    }

        return Container(
      padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tileColor.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: tileColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(typeLabel,
                    style: AppFonts.banglaHeading(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tileColor)),
                if (edited) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _warn.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('HR edited',
                        style: AppFonts.banglaHeading(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _warn)),
                  ),
                ],
              ]),
              if (invoiceNo.isNotEmpty)
                Text('Invoice #$invoiceNo',
                    style: AppFonts.banglaHeading(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              if (desc.isNotEmpty)
                Text(desc,
                    style: AppFonts.banglaBody(
                        fontSize: 11, color: Colors.black45),
                    maxLines: expanded ? 3 : 1,
                    overflow: TextOverflow.ellipsis),
              if (expanded && approvedBy.isNotEmpty)
                Text('By $approvedBy  •  $date',
                    style: AppFonts.banglaBody(
                        fontSize: 10, color: Colors.black38)),
              if (!expanded)
                Text(date,
                    style: AppFonts.banglaBody(
                        fontSize: 10, color: Colors.black38)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${type == 'cash_in' ? '+' : type == 'reversal' ? '±' : '−'}'
              '$currency ${money.format(amount)}',
              style: AppFonts.banglaData(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: tileColor),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String   label;
  final String   value;
  final String   selected;
  final void Function(String) onSelect;
  const _FilterChip(this.label, this.value, this.selected, this.onSelect);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _brand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? _brand : Colors.black12),
        ),
        child: Text(label,
            style: AppFonts.banglaHeading(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black54)),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppFonts.banglaHeading(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
          letterSpacing: 0.3));
}

// ── Chart card wrapper ────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppFonts.banglaHeading(
                    fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 12),
            AspectRatio(aspectRatio: 0.9, child: child),
          ],
        ),
      );
}

// ── Pie chart ─────────────────────────────────────────────────────────────────
class _PieCard extends StatelessWidget {
  final Map<String, num> data;
  final double           total;
  final List<Color>      palette;
  final NumberFormat     money;
  const _PieCard(
      {required this.data,
      required this.total,
      required this.palette,
      required this.money});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || total <= 0) {
      return const Center(child: Text('No data'));
    }
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final v   = entries[i].value.toDouble();
      final pct = v / total * 100;
      final col = palette[i % palette.length];
      sections.add(PieChartSectionData(
        value: v,
        color: col,
        radius: 80,
        title: pct >= 6 ? '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%' : '',
        titlePositionPercentageOffset: 0.58,
        titleStyle: AppFonts.banglaBody(
            fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
      ));
    }
    return Column(children: [
      Expanded(
        child: PieChart(PieChartData(
            sections: sections,
            sectionsSpace: 2,
            centerSpaceRadius: 0,
            startDegreeOffset: 270)),
      ),
      const SizedBox(height: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(entries.length, (i) {
          final label = entries[i].key;
          final v     = entries[i].value.toDouble();
          final pct   = v / total * 100;
          final col   = palette[i % palette.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: col, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$label  •  ${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%  (${money.format(v)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.banglaBody(fontSize: 11),
                ),
              ),
            ]),
          );
        }),
      ),
    ]);
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────
class _BarCard extends StatelessWidget {
  final Map<String, num> data;
  final List<Color>      palette;
  final NumberFormat     money;
  const _BarCard(
      {required this.data, required this.palette, required this.money});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries
        .map((e) => e.value.toDouble())
        .fold<double>(0, (p, n) => n > p ? n : p);
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: entries[i].value.toDouble(),
            width: 18,
            borderRadius: BorderRadius.circular(6),
            color: palette[i % palette.length],
          ),
        ],
      ));
    }
    return BarChart(BarChartData(
      maxY: (maxY * 1.2).clamp(1, double.infinity),
      gridData: FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barGroups: groups,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, _) {
              String l;
              if (v >= 1e7) l = '${(v / 1e7).toStringAsFixed(1)}cr';
              else if (v >= 1e5) l = '${(v / 1e5).toStringAsFixed(1)}L';
              else if (v >= 1e3) l = '${(v / 1e3).toStringAsFixed(0)}k';
              else l = v.toStringAsFixed(0);
              return Text(l, style: AppFonts.banglaBody(fontSize: 10));
            },
          ),
        ),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= entries.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 64,
                  child: Text(entries[i].key,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: AppFonts.banglaBody(
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '${entries[group.x].key}\n${money.format(rod.toY)}',
            AppFonts.banglaBody(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ));
  }
}

// ── Period option ─────────────────────────────────────────────────────────────
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
        title:
            Text(label, style: AppFonts.banglaHeading(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
    );
  }

// ── Shared helpers ────────────────────────────────────────────────────────────
num _n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}
