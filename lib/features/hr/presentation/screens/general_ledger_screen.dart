import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
final _money      = UddoygiDesign.moneyFormat;
final _dateFmt    = DateFormat('d MMM yyyy');

num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
  return 0;
}

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

  const _CreditEntry({required this.id, required this.source, required this.amount, required this.description, required this.account, required this.date, this.reference, this.currency, this.addedBy});
}

// ── Main Screen ─────────────────────────────────────────────────────────────
class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});
  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerCreditsScreenState();
}

class _GeneralLedgerCreditsScreenState extends State<GeneralLedgerScreen> with SingleTickerProviderStateMixin {
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

  Stream<List<_CreditEntry>> _slipCreditsStream() {
    if (_cid.isEmpty) return Stream.value([]);
    return DB.colSync(_cid, C.cashFlow)
        .where('type', isEqualTo: 'cash_in')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final m = d.data();
      final ts = m['createdAt'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      return _CreditEntry(
        id: d.id,
        source: _CreditSource.slip,
        amount: _toNum(m['amount']).toDouble(),
        description: (m['description'] ?? m['notes'] ?? 'Payment received').toString(),
        account: 'Payment Received',
        date: date,
        reference: (m['reference'] ?? m['paymentReference'] ?? '').toString(),
        currency: (m['currency'] ?? 'BDT').toString(),
        addedBy: (m['approvedBy'] ?? m['addedBy'] ?? '').toString(),
      );
    }).toList());
  }

  Stream<List<_CreditEntry>> _manualCreditsStream() {
    if (_cid.isEmpty) return Stream.value([]);
    return DB.colSync(_cid, C.ledger)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
        .where('credit', isGreaterThan: 0)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final m = d.data();
      final ts = m['date'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();
      return _CreditEntry(
        id: d.id,
        source: _CreditSource.manual,
        amount: _toNum(m['credit']).toDouble(),
        description: (m['description'] ?? 'Manual credit').toString(),
        account: (m['account'] ?? 'Other Income').toString(),
        date: date,
        currency: 'BDT',
        addedBy: (m['addedBy'] ?? '').toString(),
      );
    }).toList());
  }

  void _addCredit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddCreditSheet(cid: _cid),
    );
  }

  Future<void> _exportPdf(List<_CreditEntry> slips, List<_CreditEntry> manual) async {
    final all = [...slips, ...manual]..sort((a, b) => b.date.compareTo(a.date));
    final total = all.fold<double>(0, (p, e) => p + e.amount);
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (pw.Context context) => [pw.Text('Credits Report - ৳${_money.format(total)}')]));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [UddoygiDesign.hrBrandGreen, Color(0xFF059669)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('General Ledger', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [Tab(text: 'Current Entries'), Tab(text: 'History')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCredit,
        backgroundColor: UddoygiDesign.hrBrandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Entry', style: AppFonts.banglaHeading(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AllCreditsTab(
            cid: _cid,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
            slipStream: _slipCreditsStream(),
            manualStream: _manualCreditsStream(),
            onExport: _exportPdf,
            onAddCredit: _addCredit,
          ),
          _HistoryTab(cid: _cid),
        ],
      ),
    );
  }
}


class _AllCreditsTab extends StatelessWidget {
  final String cid;
  final DateTime periodStart, periodEnd;
  final Stream<List<_CreditEntry>> slipStream, manualStream;
  final Future<void> Function(List<_CreditEntry>, List<_CreditEntry>) onExport;
  final VoidCallback onAddCredit;

  const _AllCreditsTab({required this.cid, required this.periodStart, required this.periodEnd, required this.slipStream, required this.manualStream, required this.onExport, required this.onAddCredit});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_CreditEntry>>(
      stream: slipStream,
      builder: (ctx, slipSnap) {
        return StreamBuilder<List<_CreditEntry>>(
          stream: manualStream,
          builder: (ctx2, manSnap) {
            final slips = slipSnap.data ?? [];
            final manual = manSnap.data ?? [];
            final all = [...slips, ...manual]..sort((a, b) => b.date.compareTo(a.date));
            final totalAll = all.fold<double>(0, (p, e) => p + e.amount);

            return ListView(
              padding: const EdgeInsets.all(UddoygiDesign.space20),
              children: [
                Container(
                  padding: const EdgeInsets.all(UddoygiDesign.space24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [UddoygiDesign.hrBrandGreen, Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(UddoygiDesign.radiusL),
                    boxShadow: [BoxShadow(color: UddoygiDesign.hrBrandGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL CREDITS THIS PERIOD', style: AppFonts.banglaHeading(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Text('৳ ${_money.format(totalAll)}', style: AppFonts.banglaData(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _StatChip(label: 'Total Entries', value: '${all.length}', icon: Icons.receipt_long_rounded),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                            onPressed: () => onExport(slips, manual),
                            tooltip: 'Export Report',
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

                const SizedBox(height: UddoygiDesign.space24),
                if (all.isEmpty)
                  const _EmptyState()
                else
                  ...all.map((e) => _CreditCard(entry: e).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0)),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.white70),
      const SizedBox(width: 6),
      Text(value, style: AppFonts.banglaHeading(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(width: 4),
      Text(label, style: AppFonts.banglaBody(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
    ],
  );
}

class _CreditCard extends StatelessWidget {
  final _CreditEntry entry;
  const _CreditCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isSlip = entry.source == _CreditSource.slip;
    return UCard(
      margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (isSlip ? UddoygiDesign.hrBrandGreen : const Color(0xFF065F46)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSlip ? Icons.account_balance_wallet_rounded : Icons.edit_note_rounded,
              color: isSlip ? UddoygiDesign.hrBrandGreen : const Color(0xFF065F46),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description, style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E0040)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${entry.account} • ${_dateFmt.format(entry.date)}', style: AppFonts.banglaBody(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+৳${_money.format(entry.amount)}', style: AppFonts.banglaData(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
              Text(isSlip ? 'PAYMENT SLIP' : 'MANUAL ENTRY', style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[300])),
            ],
          ),
        ],
      ),
    );
  }
}


class _HistoryTab extends StatelessWidget {
  final String cid;
  const _HistoryTab({required this.cid});

  @override
  Widget build(BuildContext context) {
    final months = List.generate(12, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - i, 1);
    });
    return ListView.builder(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      itemCount: months.length,
      itemBuilder: (ctx, i) {
        final start = months[i];
        final end   = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
        return _MonthHistoryTile(cid: cid, start: start, end: end, label: DateFormat('MMMM yyyy').format(start)).animate().fadeIn(delay: 50.ms * i).slideX(begin: 0.1, end: 0);
      },
    );
  }
}

class _MonthHistoryTile extends StatelessWidget {
  final String cid, label;
  final DateTime start, end;
  const _MonthHistoryTile({required this.cid, required this.label, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return UCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: UddoygiDesign.hrBrandGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.calendar_month_rounded, color: UddoygiDesign.hrBrandGreen, size: 18),
        ),
        title: Text(label, style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {}, // Future: Monthly Detail View
      ),
    );
  }
}


class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.account_balance_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('No ledger entries found', style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _AddCreditSheet extends StatefulWidget {
  final String cid;
  const _AddCreditSheet({required this.cid});
  @override
  State<_AddCreditSheet> createState() => _AddCreditSheetState();
}

class _AddCreditSheetState extends State<_AddCreditSheet> {
  final _amountCtl = TextEditingController();
  final _descCtl   = TextEditingController(text: 'Manual credit entry');
  String _account  = 'Other Income';
  bool _saving     = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Manual Credit', style: AppFonts.banglaHeading(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E0040))),
          const SizedBox(height: 20),
          _Field(controller: _amountCtl, label: 'Credit Amount (BDT)', icon: Icons.attach_money_rounded, keyboard: TextInputType.number),
          const SizedBox(height: 12),
          _Field(controller: _descCtl, label: 'Description', icon: Icons.description_outlined),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonFormField<String>(
              value: _account,
              decoration: InputDecoration(border: InputBorder.none, labelText: 'Target Account', labelStyle: AppFonts.banglaHeading(fontSize: 11, fontWeight: FontWeight.w700), prefixIcon: Icon(Icons.account_tree_outlined, size: 18)),
              items: ['Sales Revenue', 'Other Income', 'Cash', 'Bank', 'Owner\'s Equity'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
              onChanged: (v) => setState(() => _account = v!),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: UddoygiDesign.hrBrandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
                elevation: 0,
              ),
              child: _saving ? CircularProgressIndicator(color: Colors.white) : Text('SAVE CREDIT ENTRY', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _save() async {
    if (_amountCtl.text.isEmpty) return;
    setState(() => _saving = true);
    await DB.colSync(widget.cid, C.ledger).add({
      'account': _account, 'description': _descCtl.text.trim(), 'date': Timestamp.now(), 'debit': 0, 'credit': double.parse(_amountCtl.text), 'createdAt': FieldValue.serverTimestamp(), 'source': 'manual',
    });
    Navigator.pop(context);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboard;
  const _Field({required this.controller, required this.label, required this.icon, this.keyboard = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboard,
    style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: AppFonts.banglaBody(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 20, color: UddoygiDesign.hrBrandGreen),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}

