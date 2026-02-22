// lib/features/hr/presentation/screens/tax_screen.dart
//
// Bangladesh HR Tax Management
// Covers: Employee TDS, Tax Challan, Annual Filing, TIN Registry, Slab Calculator
//
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'tax_calculation.dart';

// ── Brand ────────────────────────────────────────────────────────────────────
const Color _navy   = Color(0xFF0B3552);
const Color _navyL  = Color(0xFF1B5E8B);
const Color _green  = Color(0xFF065F46);
const Color _amber  = Color(0xFFF59E0B);
const Color _red    = Color(0xFFDC2626);
const Color _surf   = Color(0xFFF1F5F9);

// ── BD Tax slabs FY 2024-25 (individual) ─────────────────────────────────────
// Threshold: ৳3,50,000 (male), ৳4,00,000 (female/senior), ৳4,75,000 (disabled)
const _kMaleThreshold     = 350000.0;
const _kFemaleThreshold   = 400000.0;
const _kDisabledThreshold = 475000.0;

double _calcIndividualTax(double income, double threshold) {
  if (income <= threshold) return 0;
  double taxable = income - threshold;
  double tax = 0;
  final slabs = [100000.0, 400000.0, 500000.0, 500000.0]; // slab sizes
  final rates = [0.05,      0.10,     0.15,     0.20];
  for (int i = 0; i < slabs.length; i++) {
    if (taxable <= 0) break;
    final chunk = taxable.clamp(0, slabs[i]);
    tax += chunk * rates[i];
    taxable -= chunk;
  }
  if (taxable > 0) tax += taxable * 0.25;
  return tax;
}

double _calcCompanyTax(double income, String companyType) {
  switch (companyType) {
    case 'Public (Listed)':  return income * 0.225;
    case 'OPC':              return income * 0.25;
    case 'Non-listed':       return income * 0.275;
    default:                 return income * 0.275;
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────
final _fmt = NumberFormat('#,##,##0', 'en_IN');
String _money(double n) => '৳${_fmt.format(n)}';

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class TaxScreen extends StatefulWidget {
  const TaxScreen({Key? key}) : super(key: key);
  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> with SingleTickerProviderStateMixin {
  String _cid = '';
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surf,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Tax Management',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TaxCalculationPage())),
            icon: const Icon(Icons.calculate_outlined, color: Colors.white70, size: 18),
            label: const Text('Slab Calc',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'TDS / Employee'),
            Tab(text: 'Challan'),
            Tab(text: 'Annual Filing'),
            Tab(text: 'TIN Registry'),
          ],
        ),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _TdsTab(cid: _cid),
                _ChallanTab(cid: _cid),
                _FilingTab(cid: _cid),
                _TinTab(cid: _cid),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — TDS / Employee Tax Deduction at Source
// ─────────────────────────────────────────────────────────────────────────────
class _TdsTab extends StatefulWidget {
  final String cid;
  const _TdsTab({required this.cid});
  @override
  State<_TdsTab> createState() => _TdsTabState();
}

class _TdsTabState extends State<_TdsTab> {
  String _search = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      DB.colSync(widget.cid, C.taxes)
          .where('category', isEqualTo: 'tds')
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary + Add button
        _SummaryHeader(
          cid: widget.cid,
          category: 'tds',
          title: 'TDS Deductions',
          subtitle: 'Monthly salary tax deducted at source',
          onAdd: () => _showTdsForm(context, widget.cid),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SearchBar(onChanged: (v) => setState(() => _search = v)),
        ),

        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data();
                final q = _search.toLowerCase();
                return q.isEmpty ||
                    (data['employeeName'] ?? '').toString().toLowerCase().contains(q) ||
                    (data['month'] ?? '').toString().toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  label: 'No TDS records yet',
                  sub: 'Add monthly salary tax deductions',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = filtered[i].data();
                  final docId = filtered[i].id;
                  return _TdsCard(data: d, docId: docId, cid: widget.cid);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTdsForm(BuildContext ctx, String cid) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TdsFormSheet(cid: cid),
    );
  }
}

class _TdsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String cid;
  const _TdsCard({required this.data, required this.docId, required this.cid});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final statusColor = status == 'deducted' ? _green : status == 'overdue' ? _red : _amber;
    final gross  = (data['grossSalary'] ?? 0.0) as num;
    final tds    = (data['tdsAmount']   ?? 0.0) as num;
    final month  = data['month'] ?? '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(data['employeeName'] ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                ),
                _StatusChip(label: status, color: statusColor),
                const SizedBox(width: 8),
                _PopMenu(items: [
                  _PopItem('Mark Deducted', Icons.check_circle_outline, () =>
                      DB.colSync(cid, C.taxes).doc(docId).update({'status': 'deducted'})),
                  _PopItem('Delete', Icons.delete_outline, () =>
                      DB.colSync(cid, C.taxes).doc(docId).delete(), isRed: true),
                ]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(Icons.calendar_today_outlined, month),
                const SizedBox(width: 8),
                _InfoChip(Icons.work_outline, data['designation'] ?? '—'),
                const SizedBox(width: 8),
                _InfoChip(Icons.business_outlined, data['department'] ?? '—'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _AmountBox('Gross Salary', _money(gross.toDouble()), Colors.blue.shade50, _navy)),
                const SizedBox(width: 8),
                Expanded(child: _AmountBox('TDS Amount', _money(tds.toDouble()), Colors.red.shade50, _red)),
                const SizedBox(width: 8),
                Expanded(child: _AmountBox('Net Salary', _money((gross - tds).toDouble()), Colors.green.shade50, _green)),
              ],
            ),
            if ((data['tin'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.fingerprint, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('TIN: ${data['tin']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Tax Challan (Treasury Deposit)
// ─────────────────────────────────────────────────────────────────────────────
class _ChallanTab extends StatefulWidget {
  final String cid;
  const _ChallanTab({required this.cid});
  @override
  State<_ChallanTab> createState() => _ChallanTabState();
}

class _ChallanTabState extends State<_ChallanTab> {
  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      DB.colSync(widget.cid, C.taxes)
          .where('category', isEqualTo: 'challan')
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryHeader(
          cid: widget.cid,
          category: 'challan',
          title: 'Tax Challans',
          subtitle: 'NBR treasury deposit records (Form IT-10BB)',
          onAdd: () => _showForm(context),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.receipt_outlined,
                  label: 'No challans recorded',
                  sub: 'Record NBR treasury deposits here',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final docId = docs[i].id;
                  return _ChallanCard(data: d, docId: docId, cid: widget.cid);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showForm(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChallanFormSheet(cid: widget.cid),
    );
  }
}

class _ChallanCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String cid;
  const _ChallanCard({required this.data, required this.docId, required this.cid});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final paid   = status == 'paid';
    final amount = (data['amount'] ?? 0.0) as num;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: paid ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: paid ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(paid ? Icons.check_circle_rounded : Icons.pending_outlined,
                      color: paid ? _green : _amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['challanNo'] ?? 'Challan',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                      Text('${data['taxType'] ?? '—'} · ${data['taxYear'] ?? '—'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_money(amount.toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _navy)),
                    _StatusChip(label: status, color: paid ? _green : _amber),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(Icons.account_balance_outlined, data['bankName'] ?? 'Bank'),
                const SizedBox(width: 8),
                _InfoChip(Icons.calendar_today_outlined, data['depositDate'] ?? '—'),
                const Spacer(),
                _PopMenu(items: [
                  if (!paid) _PopItem('Mark Paid', Icons.check_circle_outline, () =>
                      DB.colSync(cid, C.taxes).doc(docId).update({'status': 'paid'})),
                  _PopItem('Delete', Icons.delete_outline, () =>
                      DB.colSync(cid, C.taxes).doc(docId).delete(), isRed: true),
                ]),
              ],
            ),
            if ((data['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(data['notes'],
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — Annual Tax Filing (Return Submission)
// ─────────────────────────────────────────────────────────────────────────────
class _FilingTab extends StatefulWidget {
  final String cid;
  const _FilingTab({required this.cid});
  @override
  State<_FilingTab> createState() => _FilingTabState();
}

class _FilingTabState extends State<_FilingTab> {
  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      DB.colSync(widget.cid, C.taxes)
          .where('category', isEqualTo: 'filing')
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryHeader(
          cid: widget.cid,
          category: 'filing',
          title: 'Annual Tax Returns',
          subtitle: 'NBR income tax return submissions (IT-11)',
          onAdd: () => _showForm(context),
        ),

        // BD Filing deadline reminder
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _amber, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BD NBR Deadline: 30 November each year. File IT-11GA/IT-11UMA for individuals.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.assignment_outlined,
                  label: 'No filing records',
                  sub: 'Track annual tax return submissions',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final docId = docs[i].id;
                  return _FilingCard(data: d, docId: docId, cid: widget.cid);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showForm(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilingFormSheet(cid: widget.cid),
    );
  }
}

class _FilingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String cid;
  const _FilingCard({required this.data, required this.docId, required this.cid});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final Color statusColor = status == 'submitted' ? _green
        : status == 'overdue' ? _red : _amber;
    final taxPayable = (data['taxPayable'] ?? 0.0) as num;
    final totalIncome = (data['totalIncome'] ?? 0.0) as num;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['employeeName'] ?? data['entityName'] ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                      Text('FY ${data['taxYear'] ?? '—'} · ${data['returnForm'] ?? 'IT-11'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _StatusChip(label: status, color: statusColor),
                const SizedBox(width: 6),
                _PopMenu(items: [
                  if (status != 'submitted')
                    _PopItem('Mark Submitted', Icons.check_circle_outline, () =>
                        DB.colSync(cid, C.taxes).doc(docId).update({'status': 'submitted'})),
                  _PopItem('Delete', Icons.delete_outline, () =>
                      DB.colSync(cid, C.taxes).doc(docId).delete(), isRed: true),
                ]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _AmountBox('Total Income', _money(totalIncome.toDouble()), Colors.blue.shade50, _navy)),
                const SizedBox(width: 8),
                Expanded(child: _AmountBox('Tax Payable', _money(taxPayable.toDouble()), Colors.red.shade50, _red)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(Icons.calendar_today_outlined, 'Filed: ${data['filingDate'] ?? '—'}'),
                const SizedBox(width: 8),
                if ((data['acknowledgementNo'] ?? '').toString().isNotEmpty)
                  _InfoChip(Icons.confirmation_number_outlined, 'Ack: ${data['acknowledgementNo']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — TIN Registry
// ─────────────────────────────────────────────────────────────────────────────
class _TinTab extends StatefulWidget {
  final String cid;
  const _TinTab({required this.cid});
  @override
  State<_TinTab> createState() => _TinTabState();
}

class _TinTabState extends State<_TinTab> {
  String _search = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      DB.colSync(widget.cid, C.taxes)
          .where('category', isEqualTo: 'tin')
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryHeader(
          cid: widget.cid,
          category: 'tin',
          title: 'TIN Registry',
          subtitle: 'Employee Tax Identification Numbers',
          onAdd: () => _showForm(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SearchBar(onChanged: (v) => setState(() => _search = v)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data();
                final q = _search.toLowerCase();
                return q.isEmpty ||
                    (data['employeeName'] ?? '').toString().toLowerCase().contains(q) ||
                    (data['tin'] ?? '').toString().toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.fingerprint,
                  label: 'No TIN records',
                  sub: 'Register employee TINs for compliance',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = filtered[i].data();
                  final docId = filtered[i].id;
                  return _TinCard(data: d, docId: docId, cid: widget.cid);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showForm(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TinFormSheet(cid: widget.cid),
    );
  }
}

class _TinCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String cid;
  const _TinCard({required this.data, required this.docId, required this.cid});

  @override
  Widget build(BuildContext context) {
    final hasTin = (data['tin'] ?? '').toString().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasTin ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasTin ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.fingerprint,
                  color: hasTin ? _green : _amber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['employeeName'] ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                  Text(data['designation'] ?? data['department'] ?? '—',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  if (hasTin)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: data['tin']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('TIN copied'), duration: Duration(seconds: 1)));
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.copy_outlined, size: 12, color: _navyL),
                          const SizedBox(width: 4),
                          Text(data['tin'],
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: _navyL, letterSpacing: 1.5)),
                        ],
                      ),
                    )
                  else
                    const Text('TIN not registered',
                        style: TextStyle(fontSize: 12, color: _amber, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            _PopMenu(items: [
              _PopItem('Delete', Icons.delete_outline, () =>
                  DB.colSync(cid, C.taxes).doc(docId).delete(), isRed: true),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary header with stats
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryHeader extends StatelessWidget {
  final String cid;
  final String category;
  final String title;
  final String subtitle;
  final VoidCallback onAdd;
  const _SummaryHeader({
    required this.cid, required this.category,
    required this.title, required this.subtitle, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(cid, C.taxes)
          .where('category', isEqualTo: category)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.fold<double>(0, (s, d) {
          final v = d.data()['amount'] ?? d.data()['tdsAmount'] ?? d.data()['taxPayable'] ?? 0;
          return s + (v is num ? v.toDouble() : 0);
        });
        final pending = docs.where((d) =>
            (d.data()['status'] ?? 'pending').toString().toLowerCase() == 'pending').length;
        final done = docs.length - pending;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_navy, _navyL], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                        Text(subtitle,
                            style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StatPill('Total', category == 'tin' ? '${docs.length}' : _money(total), Colors.white),
                  const SizedBox(width: 10),
                  _StatPill('Done', '$done', Colors.green.shade200),
                  const SizedBox(width: 10),
                  _StatPill('Pending', '$pending', Colors.orange.shade200),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form sheets
// ─────────────────────────────────────────────────────────────────────────────

// TDS Form
class _TdsFormSheet extends StatefulWidget {
  final String cid;
  const _TdsFormSheet({required this.cid});
  @override
  State<_TdsFormSheet> createState() => _TdsFormSheetState();
}

class _TdsFormSheetState extends State<_TdsFormSheet> {
  final _name   = TextEditingController();
  final _desig  = TextEditingController();
  final _dept   = TextEditingController();
  final _tin    = TextEditingController();
  final _gross  = TextEditingController();
  final _tds    = TextEditingController();
  String _month = DateFormat('MMMM yyyy').format(DateTime.now());
  String _gender = 'Male';
  bool _saving = false;

  void _autoCalc() {
    final gross = double.tryParse(_gross.text.trim()) ?? 0;
    if (gross <= 0) return;
    final annualGross = gross * 12;
    final threshold = _gender == 'Female' ? _kFemaleThreshold
        : _gender == 'Disabled' ? _kDisabledThreshold : _kMaleThreshold;
    final annualTax = _calcIndividualTax(annualGross, threshold);
    final monthly = annualTax / 12;
    _tds.text = monthly.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await DB.colSync(widget.cid, C.taxes).add({
        'category':    'tds',
        'employeeName': _name.text.trim(),
        'designation': _desig.text.trim(),
        'department':  _dept.text.trim(),
        'tin':         _tin.text.trim(),
        'grossSalary': double.tryParse(_gross.text.trim()) ?? 0,
        'tdsAmount':   double.tryParse(_tds.text.trim()) ?? 0,
        'month':       _month,
        'gender':      _gender,
        'status':      'pending',
        'createdAt':   FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: 'Add TDS Record',
      saving: _saving,
      onSave: _save,
      children: [
        _FormField('Employee Name', _name, hint: 'Full name'),
        _FormField('Designation', _desig, hint: 'e.g. Software Engineer'),
        _FormField('Department', _dept, hint: 'e.g. IT'),
        _FormField('TIN (12-digit)', _tin, hint: '000000000000', keyboardType: TextInputType.number),
        _DropdownField('Gender / Category', _gender, ['Male', 'Female', 'Disabled'],
            (v) => setState(() { _gender = v!; _autoCalc(); })),
        _FormField('Month', TextEditingController(text: _month),
            hint: 'e.g. January 2025',
            onChanged: (v) => _month = v),
        Row(
          children: [
            Expanded(child: _FormField('Gross Salary (৳)', _gross,
                keyboardType: TextInputType.number,
                onChanged: (_) => _autoCalc())),
            const SizedBox(width: 12),
            Expanded(child: _FormField('TDS Amount (৳)', _tds,
                keyboardType: TextInputType.number,
                suffix: IconButton(
                  icon: const Icon(Icons.calculate_outlined, size: 18, color: _navy),
                  onPressed: _autoCalc,
                  tooltip: 'Auto-calculate',
                ))),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'TDS is auto-calculated using BD FY 2024-25 slabs:\n'
            'Male: ৳3.5L free · Female: ৳4L free · Disabled: ৳4.75L free\n'
            'Then 5% / 10% / 15% / 20% / 25% on successive slabs.',
            style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
          ),
        ),
      ],
    );
  }
}

// Challan Form
class _ChallanFormSheet extends StatefulWidget {
  final String cid;
  const _ChallanFormSheet({required this.cid});
  @override
  State<_ChallanFormSheet> createState() => _ChallanFormSheetState();
}

class _ChallanFormSheetState extends State<_ChallanFormSheet> {
  final _challanNo = TextEditingController();
  final _amount    = TextEditingController();
  final _bank      = TextEditingController();
  final _notes     = TextEditingController();
  String _taxType  = 'Income Tax (IT)';
  String _taxYear  = '2024-25';
  String _depositDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool _saving = false;

  Future<void> _save() async {
    if (_amount.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await DB.colSync(widget.cid, C.taxes).add({
        'category':    'challan',
        'challanNo':   _challanNo.text.trim(),
        'taxType':     _taxType,
        'taxYear':     _taxYear,
        'amount':      double.tryParse(_amount.text.trim()) ?? 0,
        'bankName':    _bank.text.trim(),
        'depositDate': _depositDate,
        'notes':       _notes.text.trim(),
        'status':      'pending',
        'createdAt':   FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: 'Add Tax Challan',
      saving: _saving,
      onSave: _save,
      children: [
        _FormField('Challan Number', _challanNo, hint: 'NBR challan no.'),
        _DropdownField('Tax Type', _taxType,
            ['Income Tax (IT)', 'VAT', 'Advance Tax', 'Withholding Tax', 'Corporate Tax'],
            (v) => setState(() => _taxType = v!)),
        _DropdownField('Tax Year', _taxYear,
            ['2022-23', '2023-24', '2024-25', '2025-26'],
            (v) => setState(() => _taxYear = v!)),
        _FormField('Amount (৳)', _amount, keyboardType: TextInputType.number),
        _FormField('Bank Name', _bank, hint: 'e.g. Sonali Bank, DBBL'),
        _FormField('Deposit Date', TextEditingController(text: _depositDate),
            hint: 'YYYY-MM-DD', onChanged: (v) => _depositDate = v),
        _FormField('Notes', _notes, hint: 'Optional remarks', maxLines: 2),
      ],
    );
  }
}

// Filing Form
class _FilingFormSheet extends StatefulWidget {
  final String cid;
  const _FilingFormSheet({required this.cid});
  @override
  State<_FilingFormSheet> createState() => _FilingFormSheetState();
}

class _FilingFormSheetState extends State<_FilingFormSheet> {
  final _name    = TextEditingController();
  final _tin     = TextEditingController();
  final _income  = TextEditingController();
  final _taxable = TextEditingController();
  final _tax     = TextEditingController();
  final _ackNo   = TextEditingController();
  String _taxYear    = '2024-25';
  String _returnForm = 'IT-11GA';
  String _filingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _gender     = 'Male';
  bool _saving = false;

  void _autoCalc() {
    final income = double.tryParse(_income.text.trim()) ?? 0;
    if (income <= 0) return;
    final threshold = _gender == 'Female' ? _kFemaleThreshold
        : _gender == 'Disabled' ? _kDisabledThreshold : _kMaleThreshold;
    final tax = _calcIndividualTax(income, threshold);
    _tax.text = tax.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await DB.colSync(widget.cid, C.taxes).add({
        'category':          'filing',
        'employeeName':      _name.text.trim(),
        'tin':               _tin.text.trim(),
        'taxYear':           _taxYear,
        'returnForm':        _returnForm,
        'totalIncome':       double.tryParse(_income.text.trim()) ?? 0,
        'taxableIncome':     double.tryParse(_taxable.text.trim()) ?? 0,
        'taxPayable':        double.tryParse(_tax.text.trim()) ?? 0,
        'filingDate':        _filingDate,
        'acknowledgementNo': _ackNo.text.trim(),
        'gender':            _gender,
        'status':            'pending',
        'createdAt':         FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: 'Add Tax Return Filing',
      saving: _saving,
      onSave: _save,
      children: [
        _FormField('Employee / Entity Name', _name),
        _FormField('TIN (12-digit)', _tin, keyboardType: TextInputType.number),
        Row(children: [
          Expanded(child: _DropdownField('Tax Year', _taxYear,
              ['2022-23', '2023-24', '2024-25', '2025-26'],
              (v) => setState(() => _taxYear = v!))),
          const SizedBox(width: 12),
          Expanded(child: _DropdownField('Return Form', _returnForm,
              ['IT-11GA', 'IT-11UMA', 'IT-11CHA', 'IT-11GHA'],
              (v) => setState(() => _returnForm = v!))),
        ]),
        _DropdownField('Gender / Category', _gender, ['Male', 'Female', 'Disabled'],
            (v) => setState(() { _gender = v!; _autoCalc(); })),
        Row(children: [
          Expanded(child: _FormField('Total Income (৳)', _income,
              keyboardType: TextInputType.number,
              onChanged: (_) => _autoCalc())),
          const SizedBox(width: 12),
          Expanded(child: _FormField('Taxable Income (৳)', _taxable,
              keyboardType: TextInputType.number)),
        ]),
        _FormField('Tax Payable (৳)', _tax,
            keyboardType: TextInputType.number,
            suffix: IconButton(
              icon: const Icon(Icons.calculate_outlined, size: 18, color: _navy),
              onPressed: _autoCalc,
              tooltip: 'Auto-calculate',
            )),
        _FormField('Filing Date', TextEditingController(text: _filingDate),
            hint: 'YYYY-MM-DD', onChanged: (v) => _filingDate = v),
        _FormField('Acknowledgement No.', _ackNo, hint: 'NBR ack number after submission'),
      ],
    );
  }
}

// TIN Form
class _TinFormSheet extends StatefulWidget {
  final String cid;
  const _TinFormSheet({required this.cid});
  @override
  State<_TinFormSheet> createState() => _TinFormSheetState();
}

class _TinFormSheetState extends State<_TinFormSheet> {
  final _name  = TextEditingController();
  final _desig = TextEditingController();
  final _dept  = TextEditingController();
  final _tin   = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _tin.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await DB.colSync(widget.cid, C.taxes).add({
        'category':    'tin',
        'employeeName': _name.text.trim(),
        'designation': _desig.text.trim(),
        'department':  _dept.text.trim(),
        'tin':         _tin.text.trim(),
        'email':       _email.text.trim(),
        'status':      'registered',
        'createdAt':   FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: 'Register TIN',
      saving: _saving,
      onSave: _save,
      children: [
        _FormField('Employee Name', _name),
        _FormField('Designation', _desig),
        _FormField('Department', _dept),
        _FormField('TIN (12-digit)', _tin,
            hint: '000000000000',
            keyboardType: TextInputType.number,
            maxLength: 12),
        _FormField('Email', _email, keyboardType: TextInputType.emailAddress),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FormSheet extends StatelessWidget {
  final String title;
  final bool saving;
  final VoidCallback onSave;
  final List<Widget> children;
  const _FormSheet({required this.title, required this.saving, required this.onSave, required this.children});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _navy))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const Divider(),
            // Fields
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Record', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _FormField(
  String label,
  TextEditingController ctrl, {
  String? hint,
  TextInputType? keyboardType,
  int maxLines = 1,
  int? maxLength,
  Widget? suffix,
  ValueChanged<String>? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _navy, letterSpacing: 0.3)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          suffixIcon: suffix,
          filled: true,
          fillColor: _surf,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _navy)),
          counterText: '',
        ),
      ),
    ],
  );
}

Widget _DropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: _navy, letterSpacing: 0.3)),
      const SizedBox(height: 5),
      DropdownButtonFormField<String>(
        value: value,
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: _surf,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _navy)),
        ),
      ),
    ],
  );
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search…',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AmountBox extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color textColor;
  const _AmountBox(this.label, this.value, this.bg, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PopItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isRed;
  const _PopItem(this.label, this.icon, this.onTap, {this.isRed = false});
}

class _PopMenu extends StatelessWidget {
  final List<_PopItem> items;
  const _PopMenu({required this.items});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => items.asMap().entries.map((e) => PopupMenuItem(
        value: e.key,
        child: Row(
          children: [
            Icon(e.value.icon, size: 16, color: e.value.isRed ? _red : _navy),
            const SizedBox(width: 8),
            Text(e.value.label,
                style: TextStyle(fontSize: 13, color: e.value.isRed ? _red : _navy,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      )).toList(),
      onSelected: (i) => items[i].onTap(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _EmptyState({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.grey.shade400, size: 28),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
