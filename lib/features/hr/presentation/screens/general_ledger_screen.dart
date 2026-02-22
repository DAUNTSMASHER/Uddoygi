// lib/features/hr/presentation/screens/general_ledger_screen.dart
//
// Credits Screen — shows:
//   • Cash-in entries (from accepted payment slips) — C.cashFlow type=cash_in
//   • Manual ledger credits — C.ledger credit > 0
// Both sources are merged and displayed in a unified, modern UI.
// FAB (+) lets HR add a manual credit entry at any time.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF4F46E5); // indigo-600
const Color _brandLt  = Color(0xFFEEF2FF); // indigo-50
const Color _green    = Color(0xFF065F46);
const Color _greenLt  = Color(0xFFD1FAE5);
const Color _bg       = Color(0xFFF8F9FC);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);

final _dateFmt  = DateFormat('d MMM yyyy');
final _timeFmt  = DateFormat('h:mm a');
final _moneyFmt = NumberFormat('#,##0.00');

num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

// ── Unified credit entry model ────────────────────────────────────────────────
enum _CreditSource { slip, manual }

class _CreditEntry {
  final String         id;
  final _CreditSource  source;
  final double         amount;
  final String         description;
  final String         account;
  final DateTime       date;
  final String?        reference;
  final String?        currency;
  final String?        addedBy;

  const _CreditEntry({
    required this.id,
    required this.source,
    required this.amount,
    required this.description,
    required this.account,
    required this.date,
    this.reference,
    this.currency,
    this.addedBy,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});
  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerCreditsScreenState();
}

class _GeneralLedgerCreditsScreenState extends State<GeneralLedgerScreen>
    with SingleTickerProviderStateMixin {
  String   _cid = '';
  late DateTime _periodStart;
  late DateTime _periodEnd;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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

  // ── Streams ─────────────────────────────────────────────────────────────────

  Stream<List<_CreditEntry>> _slipCreditsStream() {
    if (_cid.isEmpty) return Stream.value([]);
    return DB.colSync(_cid, C.cashFlow)
        .where('type', isEqualTo: 'cash_in')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              final ts = m['createdAt'];
              final date = ts is Timestamp
                  ? ts.toDate()
                  : DateTime.now();
              return _CreditEntry(
                id:          d.id,
                source:      _CreditSource.slip,
                amount:      _toNum(m['amount']).toDouble(),
                description: (m['description'] ?? m['notes'] ?? 'Payment received').toString(),
                account:     'Payment Received',
                date:        date,
                reference:   (m['reference'] ?? m['paymentReference'] ?? '').toString(),
                currency:    (m['currency'] ?? 'BDT').toString(),
                addedBy:     (m['approvedBy'] ?? m['addedBy'] ?? '').toString(),
              );
            }).toList());
  }

  Stream<List<_CreditEntry>> _manualCreditsStream() {
    if (_cid.isEmpty) return Stream.value([]);
    return DB.colSync(_cid, C.ledger)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .where('credit', isGreaterThan: 0)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              final ts = m['date'];
              final date = ts is Timestamp ? ts.toDate() : DateTime.now();
              return _CreditEntry(
                id:          d.id,
                source:      _CreditSource.manual,
                amount:      _toNum(m['credit']).toDouble(),
                description: (m['description'] ?? 'Manual credit').toString(),
                account:     (m['account'] ?? 'Other Income').toString(),
                date:        date,
                currency:    'BDT',
                addedBy:     (m['addedBy'] ?? '').toString(),
              );
            }).toList());
  }

  // ── Period picker ────────────────────────────────────────────────────────────
  Future<void> _pickPeriod() async {
    final now      = DateTime.now();
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Select Period',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            for (final opt in [
              ('This Month', thisStart,
                  DateTime(thisStart.year, thisStart.month + 1, 0, 23, 59, 59),
                  Icons.today_rounded),
              ('Last Month', lastStart, lastEnd, Icons.history_rounded),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: _border)),
                  leading: Icon(opt.$4, color: _brand),
                  title: Text(opt.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                setState(() {
                      _periodStart = opt.$2;
                      _periodEnd   = opt.$3;
                });
                Navigator.pop(context);
              },
            ),
              ),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _border)),
              leading: const Icon(Icons.date_range_rounded, color: _brand),
              title: const Text('Custom Range',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                Navigator.pop(context);
                final s = await showDatePicker(
                  context: context,
                  initialDate: _periodStart,
                  firstDate: DateTime(2020),
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
          ]),
        ),
      ),
    );
  }

  // ── Add manual credit ────────────────────────────────────────────────────────
  void _addCredit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddCreditSheet(cid: _cid),
    );
  }

  // ── PDF export ───────────────────────────────────────────────────────────────
  Future<void> _exportPdf(
      List<_CreditEntry> slips, List<_CreditEntry> manual) async {
    final all = [...slips, ...manual]
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = all.fold<double>(0, (p, e) => p + e.amount);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.times(),
        bold: pw.Font.timesBold(),
      ),
    );

    pdf.addPage(pw.MultiPage(
      pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(24)),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Credits Report',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              '${_dateFmt.format(_periodStart)} – ${_dateFmt.format(_periodEnd)}',
              style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.Divider(),
        ],
      ),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Description', 'Account', 'Source', 'Amount (BDT)'],
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo100),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          border: pw.TableBorder.all(color: PdfColors.grey300),
          data: all.map((e) => [
                _dateFmt.format(e.date),
                e.description,
                e.account,
                e.source == _CreditSource.slip ? 'Slip' : 'Manual',
                '৳${_moneyFmt.format(e.amount)}',
              ]).toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              border: pw.Border.all(color: PdfColors.indigo),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text('TOTAL CREDITS: ৳${_moneyFmt.format(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _fg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Credits',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          // Period selector
          GestureDetector(
            onTap: _pickPeriod,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _brandLt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _brand.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 14, color: _brand),
                const SizedBox(width: 4),
                Text(
                  _periodStart.month == _periodEnd.month &&
                          _periodStart.year == _periodEnd.year
                      ? DateFormat('MMM yyyy').format(_periodStart)
                      : '${DateFormat('d MMM').format(_periodStart)} – ${DateFormat('d MMM').format(_periodEnd)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _brand),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down_rounded,
                    size: 16, color: _brand),
          ]),
        ),
      ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _brand,
          unselectedLabelColor: _muted,
          indicatorColor: _brand,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'All Credits'),
            Tab(text: 'History'),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCredit,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Credit',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),

      body: TabBarView(
        controller: _tabs,
        children: [
          _AllCreditsTab(
            cid:          _cid,
            periodStart:  _periodStart,
            periodEnd:    _periodEnd,
            slipStream:   _slipCreditsStream(),
            manualStream: _manualCreditsStream(),
            onExport:     _exportPdf,
            onAddCredit:  _addCredit,
          ),
          _HistoryTab(cid: _cid),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL CREDITS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AllCreditsTab extends StatelessWidget {
  final String                    cid;
  final DateTime                  periodStart;
  final DateTime                  periodEnd;
  final Stream<List<_CreditEntry>> slipStream;
  final Stream<List<_CreditEntry>> manualStream;
  final Future<void> Function(
      List<_CreditEntry>, List<_CreditEntry>)     onExport;
  final VoidCallback              onAddCredit;

  const _AllCreditsTab({
    required this.cid,
    required this.periodStart,
    required this.periodEnd,
    required this.slipStream,
    required this.manualStream,
    required this.onExport,
    required this.onAddCredit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_CreditEntry>>(
      stream: slipStream,
      builder: (ctx, slipSnap) {
        return StreamBuilder<List<_CreditEntry>>(
          stream: manualStream,
          builder: (ctx2, manSnap) {
            final slips  = slipSnap.data  ?? [];
            final manual = manSnap.data   ?? [];
            final all    = [...slips, ...manual]
              ..sort((a, b) => b.date.compareTo(a.date));

            final totalSlip   = slips.fold<double>(0, (p, e) => p + e.amount);
            final totalManual = manual.fold<double>(0, (p, e) => p + e.amount);
            final totalAll    = totalSlip + totalManual;

            final loading = slipSnap.connectionState == ConnectionState.waiting ||
                manSnap.connectionState == ConnectionState.waiting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ── Hero summary card ──────────────────────────────────────
                _HeroCard(
                  total:       totalAll,
                  slipTotal:   totalSlip,
                  manualTotal: totalManual,
                  count:       all.length,
                  onExport:    () => onExport(slips, manual),
                ),
                const SizedBox(height: 16),

                if (loading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: _brand),
                  ))
                else if (all.isEmpty)
                  _EmptyState(onAdd: onAddCredit)
                else ...[
                  // Section label
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      const Text('All Entries',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _fg)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${all.length}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _brand)),
                      ),
                    ]),
                  ),
                  ...all.map((e) => _CreditCard(entry: e)),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TAB — last 12 months drillable
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends StatefulWidget {
  final String cid;
  const _HistoryTab({required this.cid});
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  static List<DateTime> _months(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => DateTime(now.year, now.month - i, 1));
  }

  @override
  Widget build(BuildContext context) {
    final months = _months(12);
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
          final start = months[i];
        final end   = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
          final label = DateFormat('MMMM yyyy').format(start);
        return _MonthHistoryTile(
            cid: widget.cid, start: start, end: end, label: label);
      },
    );
  }
}

class _MonthHistoryTile extends StatelessWidget {
  final String   cid;
  final DateTime start, end;
  final String   label;
  const _MonthHistoryTile(
      {required this.cid,
      required this.start,
      required this.end,
      required this.label});

  Future<void> _print(BuildContext context) async {
    // Fetch both sources
    final cfSnap = await DB.colSync(cid, C.cashFlow)
        .where('type', isEqualTo: 'cash_in')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt')
        .get();
    final ldSnap = await DB.colSync(cid, C.ledger)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('credit', isGreaterThan: 0)
          .orderBy('date')
          .get();
  
    if (cfSnap.docs.isEmpty && ldSnap.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No credits for $label')),
          );
        }
        return;
      }
  
    final rows = <List<String>>[];
    double total = 0;

    for (final d in cfSnap.docs) {
      final m    = d.data();
      final ts   = m['createdAt'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      final amt  = _toNum(m['amount']).toDouble();
      total += amt;
      rows.add([
        _dateFmt.format(date),
        (m['description'] ?? m['notes'] ?? 'Payment received').toString(),
        'Payment Received',
        'Slip',
        '৳${_moneyFmt.format(amt)}',
      ]);
    }
    for (final d in ldSnap.docs) {
      final m    = d.data();
      final ts   = m['date'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      final amt  = _toNum(m['credit']).toDouble();
      total += amt;
      rows.add([
        _dateFmt.format(date),
        (m['description'] ?? 'Manual credit').toString(),
        (m['account'] ?? 'Other Income').toString(),
        'Manual',
        '৳${_moneyFmt.format(amt)}',
      ]);
    }

    final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
            base: pw.Font.times(), bold: pw.Font.timesBold()));
    pdf.addPage(pw.MultiPage(
      pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(24)),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
          pw.Text('Credits Report – $label',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
            ],
          ),
      build: (_) => [
                pw.TableHelper.fromTextArray(
          headers: ['Date', 'Description', 'Account', 'Source', 'Amount'],
          headerDecoration:
              const pw.BoxDecoration(color: PdfColors.indigo100),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          border: pw.TableBorder.all(color: PdfColors.grey300),
          data: rows,
        ),
        pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    border: pw.Border.all(color: PdfColors.indigo),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
            child: pw.Text('TOTAL: ৳${_moneyFmt.format(total)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    // Quick total stream (both sources)
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.cashFlow)
          .where('type', isEqualTo: 'cash_in')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .snapshots(),
      builder: (ctx, cfSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DB.colSync(cid, C.ledger)
              .where('date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
              .where('credit', isGreaterThan: 0)
              .snapshots(),
          builder: (ctx2, ldSnap) {
            double total = 0;
            for (final d in cfSnap.data?.docs ?? []) {
              total += _toNum(d.data()['amount']).toDouble();
            }
            for (final d in ldSnap.data?.docs ?? []) {
              total += _toNum(d.data()['credit']).toDouble();
            }
            final count = (cfSnap.data?.docs.length ?? 0) +
                (ldSnap.data?.docs.length ?? 0);

            return Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _brandLt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: _brand, size: 20),
                ),
                title: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('$count entries',
                    style: const TextStyle(
                        color: _muted, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total > 0 ? '৳${_moneyFmt.format(total)}' : '—',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: total > 0 ? _green : _muted),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _print(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _brandLt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.print_rounded,
                            size: 16, color: _brand),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD CREDIT BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
const _kAccounts = <String>[
  'Sales Revenue',
  'Other Income',
  'Cash',
  'Bank',
  'VAT/Tax Payable',
  "Owner's Equity",
];

class _AddCreditSheet extends StatefulWidget {
  final String cid;
  const _AddCreditSheet({required this.cid});
  @override
  State<_AddCreditSheet> createState() => _AddCreditSheetState();
}

class _AddCreditSheetState extends State<_AddCreditSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtl  = TextEditingController();
  final _descCtl    = TextEditingController(text: 'Manual credit entry');
  String _account   = 'Other Income';
  DateTime _date    = DateTime.now();
  bool _saving      = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountCtl.text.trim());
      final ts     = Timestamp.fromDate(
          DateTime(_date.year, _date.month, _date.day));
      await DB.colSync(widget.cid, C.ledger).add({
        'account':     _account,
        'description': _descCtl.text.trim(),
        'date':        ts,
        'debit':       0,
        'credit':      amount,
        'createdAt':   FieldValue.serverTimestamp(),
        'source':      'manual',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 4),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add Manual Credit',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: _fg)),
          const SizedBox(height: 16),

          // Amount
          TextFormField(
            controller: _amountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Amount (BDT)', Icons.currency_exchange_rounded),
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter a valid amount',
          ),
          const SizedBox(height: 12),

          // Description
          TextFormField(
            controller: _descCtl,
            decoration: _dec('Description', Icons.notes_rounded),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 12),

          // Account dropdown
          DropdownButtonFormField<String>(
            initialValue: _account,
            isExpanded: true,
            decoration: _dec('Account', Icons.account_balance_rounded),
            items: _kAccounts
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _account = v ?? _account),
          ),
          const SizedBox(height: 12),

          // Date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    color: _brand, size: 18),
              const SizedBox(width: 10),
                Text(
                  'Date: ${_dateFmt.format(_date)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _fg),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

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
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Save Credit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _brand, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final double       total;
  final double       slipTotal;
  final double       manualTotal;
  final int          count;
  final VoidCallback onExport;

  const _HeroCard({
    required this.total,
    required this.slipTotal,
    required this.manualTotal,
    required this.count,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brand.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.trending_up_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Total Credits',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: onExport,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.download_rounded,
                    size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text('PDF',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          '৳${_moneyFmt.format(total)}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text('$count entries this period',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        // Breakdown pills
        Row(children: [
          _BreakdownPill(
            label: 'Slip Accepted',
            amount: slipTotal,
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF34D399),
          ),
          const SizedBox(width: 10),
          _BreakdownPill(
            label: 'Manual',
            amount: manualTotal,
            icon: Icons.edit_rounded,
            color: const Color(0xFFA78BFA),
          ),
        ]),
      ]),
    );
  }
}

class _BreakdownPill extends StatelessWidget {
  final String   label;
  final double   amount;
  final IconData icon;
  final Color    color;
  const _BreakdownPill({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text(
                '৳${_moneyFmt.format(amount)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDIT CARD TILE
// ─────────────────────────────────────────────────────────────────────────────
class _CreditCard extends StatelessWidget {
  final _CreditEntry entry;
  const _CreditCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isSlip = entry.source == _CreditSource.slip;
    final color  = isSlip ? _green : _brand;
    final bgColor = isSlip ? _greenLt : _brandLt;
    final icon   = isSlip
        ? Icons.receipt_long_rounded
        : Icons.edit_note_rounded;
    final sourceLabel = isSlip ? 'Slip Accepted' : 'Manual';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Description + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _fg),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(sourceLabel,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ),
                  const SizedBox(width: 6),
                  Text(entry.account,
                      style: const TextStyle(
                          color: _muted, fontSize: 10)),
                  const SizedBox(width: 6),
                  Text(
                    '${_dateFmt.format(entry.date)} · ${_timeFmt.format(entry.date)}',
                    style: const TextStyle(
                        color: _muted, fontSize: 10),
                  ),
                ]),
                if (entry.reference != null &&
                    entry.reference!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Ref: ${entry.reference}',
                      style: const TextStyle(
                          color: _muted, fontSize: 10)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Text(
            '৳${_moneyFmt.format(entry.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _brandLt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  size: 36, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text('No credits this period',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _fg)),
            const SizedBox(height: 6),
            const Text(
              'Credits appear here when payment slips\nare accepted, or you add them manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Manual Credit',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}
