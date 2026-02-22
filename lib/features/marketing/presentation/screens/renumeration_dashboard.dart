// lib/features/marketing/presentation/screens/renumeration_dashboard.dart
//
// My Compensation — marketing employee view
// Shows: Salary (payrolls), Payslips, Incentives
// Uses same identity-resolution strategy as common/salary_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _green   = Color(0xFF25BC5F);
const Color _greenDk = Color(0xFF065F46);
const Color _greenLt = Color(0xFFD1FAE5);
const Color _blue    = Color(0xFF2563EB);
const Color _blueLt  = Color(0xFFEFF6FF);
const Color _orange  = Color(0xFFF97316);
const Color _red     = Color(0xFFDC2626);
const Color _bg      = Color(0xFFF7F9FC);
const Color _fg      = Color(0xFF0F172A);
const Color _muted   = Color(0xFF94A3B8);

class RenumerationDashboard extends StatefulWidget {
  const RenumerationDashboard({super.key});

  @override
  State<RenumerationDashboard> createState() => _RenumerationDashboardState();
}

class _RenumerationDashboardState extends State<RenumerationDashboard>
    with SingleTickerProviderStateMixin {
  String _cid       = '';
  String _uid       = '';
  String _realEmail = '';
  bool   _loading   = true;
  String? _error;

  late final TabController _tab;
  final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Identity resolution ───────────────────────────────────────────────────
  Future<void> _init() async {
    try {
      final cid     = await LocalStorageService.getSavedCompanyId();
      final session = await LocalStorageService.getSession();
      final user    = FirebaseAuth.instance.currentUser;

      if (cid == null || cid.isEmpty) {
        if (mounted) setState(() { _loading = false; _error = 'Company ID not found.'; });
        return;
      }

      final uid = user?.uid ?? '';
      String realEmail = (session?['email'] as String?)?.trim() ?? '';
      if (realEmail.isEmpty && user?.email != null) {
        realEmail = _stripCid(user!.email!, cid);
      }

      if (mounted) {
        setState(() {
          _cid       = cid;
          _uid       = uid;
          _realEmail = realEmail;
          _loading   = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  static String _stripCid(String authEmail, String cid) {
    final marker = '+$cid@';
    final idx = authEmail.indexOf(marker);
    if (idx < 0) return authEmail;
    return '${authEmail.substring(0, idx)}@${authEmail.substring(idx + marker.length)}';
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    final dt = ts is Timestamp ? ts.toDate() : DateTime.tryParse(ts.toString());
    if (dt == null) return '—';
    return DateFormat('d MMM yyyy').format(dt);
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> _payrollStream() {
    if (_cid.isEmpty) return const Stream.empty();
    if (_uid.isNotEmpty) {
      return DB.colSync(_cid, C.payrolls)
          .where('employeeUid', isEqualTo: _uid)
          .orderBy('generatedAt', descending: true)
          .snapshots();
    }
    if (_realEmail.isNotEmpty) {
      return DB.colSync(_cid, C.payrolls)
          .where('officeEmail', isEqualTo: _realEmail)
          .orderBy('generatedAt', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _payslipStream() {
    if (_cid.isEmpty) return const Stream.empty();
    if (_uid.isNotEmpty) {
      return DB.colSync(_cid, 'payslips')
          .where('employeeUid', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    if (_realEmail.isNotEmpty) {
      return DB.colSync(_cid, 'payslips')
          .where('officeEmail', isEqualTo: _realEmail)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _incentiveStream() {
    if (_cid.isEmpty || _realEmail.isEmpty) return const Stream.empty();
    return DB.colSync(_cid, C.marketingIncentives).snapshots();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('My Compensation',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Payslips'),
            Tab(text: 'Payroll'),
            Tab(text: 'Incentives'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: _red)))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _PayslipsTab(
                      stream: _payslipStream(),
                      money: _money,
                      fmtDate: _fmtDate,
                      num: _num,
                    ),
                    _PayrollTab(
                      stream: _payrollStream(),
                      money: _money,
                      fmtDate: _fmtDate,
                      num: _num,
                    ),
                    _IncentivesTab(
                      stream: _incentiveStream(),
                      realEmail: _realEmail,
                      money: _money,
                      num: _num,
                      fmtDate: _fmtDate,
                    ),
                  ],
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Payslips Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _PayslipsTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final NumberFormat money;
  final String Function(dynamic) fmtDate;
  final double Function(dynamic) num;

  const _PayslipsTab({
    required this.stream,
    required this.money,
    required this.fmtDate,
    required this.num,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('No payslips yet', 'HR will send payslips after payroll is processed.');
        }

        double totalNet = docs.fold(0.0, (s, d) => s + num(d.data()['netSalary']));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroCard(
              label: 'Total Received',
              value: money.format(totalNet),
              icon: Icons.receipt_long_rounded,
              color: _green,
            ),
            const SizedBox(height: 16),
            ...docs.map((d) => _PayslipCard(data: d.data(), money: money, fmtDate: fmtDate, num: num)),
          ],
        );
      },
    );
  }
}

class _PayslipCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final NumberFormat money;
  final String Function(dynamic) fmtDate;
  final double Function(dynamic) num;

  const _PayslipCard({required this.data, required this.money, required this.fmtDate, required this.num});

  @override
  State<_PayslipCard> createState() => _PayslipCardState();
}

class _PayslipCardState extends State<_PayslipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m       = widget.data;
    final period  = (m['period'] ?? m['month'] ?? '').toString();
    final gross   = widget.num(m['grossSalary'] ?? m['basicSalary']);
    final bonus   = widget.num(m['bonus']);
    final loan    = widget.num(m['loanDeduction'] ?? m['deductions']);
    final net     = widget.num(m['netSalary']);
    final sentAt  = m['sentAt'];
    final extras  = (m['extraDeductions'] as List?)?.cast<Map>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _greenLt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(period, style: const TextStyle(color: _greenDk, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const Spacer(),
                Text(widget.money.format(net),
                    style: const TextStyle(color: _green, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: _muted),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _MiniStat('Gross', widget.money.format(gross), _blue),
                const SizedBox(width: 12),
                if (bonus > 0) _MiniStat('Bonus', '+${widget.money.format(bonus)}', _green),
                if (bonus > 0) const SizedBox(width: 12),
                if (loan > 0) _MiniStat('Loan', '-${widget.money.format(loan)}', _red),
              ]),
              if (_expanded) ...[
                const Divider(height: 20),
                _DetailRow('Gross Salary', widget.money.format(gross)),
                if (bonus > 0) _DetailRow('Bonus', '+${widget.money.format(bonus)}', color: _green),
                if (loan > 0) _DetailRow('Loan Deduction', '-${widget.money.format(loan)}', color: _red),
                for (final ex in extras)
                  _DetailRow(ex['label']?.toString() ?? 'Deduction',
                      '-${widget.money.format(widget.num(ex['amount']))}', color: _orange),
                const Divider(height: 16),
                _DetailRow('Net Pay', widget.money.format(net), bold: true, color: _green),
                if (sentAt != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: _muted),
                    const SizedBox(width: 4),
                    Text('Sent ${widget.fmtDate(sentAt)}',
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Payroll Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _PayrollTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final NumberFormat money;
  final String Function(dynamic) fmtDate;
  final double Function(dynamic) num;

  const _PayrollTab({
    required this.stream,
    required this.money,
    required this.fmtDate,
    required this.num,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('No payroll records', 'Your payroll history will appear here.');
        }

        final paid    = docs.where((d) => d.data()['status'] == 'paid').length;
        final pending = docs.length - paid;
        double totalNet = docs.fold(0.0, (s, d) => s + num(d.data()['netSalary']));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroCard(
              label: 'Total Paid',
              value: money.format(totalNet),
              icon: Icons.account_balance_wallet_rounded,
              color: _blue,
              subtitle: '$paid paid · $pending pending',
            ),
            const SizedBox(height: 16),
            ...docs.map((d) => _PayrollCard(data: d.data(), money: money, fmtDate: fmtDate, num: num)),
          ],
        );
      },
    );
  }
}

class _PayrollCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final NumberFormat money;
  final String Function(dynamic) fmtDate;
  final double Function(dynamic) num;

  const _PayrollCard({required this.data, required this.money, required this.fmtDate, required this.num});

  @override
  State<_PayrollCard> createState() => _PayrollCardState();
}

class _PayrollCardState extends State<_PayrollCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m      = widget.data;
    final period = (m['period'] ?? '').toString();
    final gross  = widget.num(m['grossSalary']);
    final bonus  = widget.num(m['bonus']);
    final loan   = widget.num(m['loanDeduction'] ?? m['loanDeductionTotal']);
    final net    = widget.num(m['netSalary']);
    final status = (m['status'] ?? 'pending').toString();
    final method = (m['paymentMethod'] ?? '').toString();
    final extras = (m['extraDeductions'] as List?)?.cast<Map>() ?? [];

    final isPaid     = status == 'paid';
    final isReversed = status == 'reversed';
    final statusColor = isPaid ? _green : isReversed ? _red : _orange;
    final statusLabel = isPaid ? 'Paid' : isReversed ? 'Reversed' : 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blueLt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(period, style: const TextStyle(color: _blue, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                ),
                const Spacer(),
                Text(widget.money.format(net),
                    style: TextStyle(
                        color: isReversed ? _muted : _blue,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        decoration: isReversed ? TextDecoration.lineThrough : null)),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: _muted),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _MiniStat('Gross', widget.money.format(gross), _blue),
                const SizedBox(width: 12),
                if (bonus > 0) _MiniStat('Bonus', '+${widget.money.format(bonus)}', _green),
                if (bonus > 0) const SizedBox(width: 12),
                if (loan > 0) _MiniStat('Loan', '-${widget.money.format(loan)}', _red),
              ]),
              if (_expanded) ...[
                const Divider(height: 20),
                _DetailRow('Gross Salary', widget.money.format(gross)),
                if (bonus > 0) _DetailRow('Bonus', '+${widget.money.format(bonus)}', color: _green),
                if (loan > 0) _DetailRow('Loan Deduction', '-${widget.money.format(loan)}', color: _red),
                for (final ex in extras)
                  _DetailRow(ex['label']?.toString() ?? 'Deduction',
                      '-${widget.money.format(widget.num(ex['amount']))}', color: _orange),
                const Divider(height: 16),
                _DetailRow('Net Pay', widget.money.format(net), bold: true,
                    color: isReversed ? _muted : _blue),
                if (method.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.payment, size: 14, color: _muted),
                    const SizedBox(width: 4),
                    Text(method, style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                ],
                if (m['disbursedAt'] != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today, size: 14, color: _muted),
                    const SizedBox(width: 4),
                    Text('Disbursed ${widget.fmtDate(m['disbursedAt'])}',
                        style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Incentives Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _IncentivesTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String realEmail;
  final NumberFormat money;
  final double Function(dynamic) num;
  final String Function(dynamic) fmtDate;

  const _IncentivesTab({
    required this.stream,
    required this.realEmail,
    required this.money,
    required this.num,
    required this.fmtDate,
  });

  String get _currentMonth => DateFormat('MMMM_yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        final allDocs = snap.data?.docs ?? [];

        // Filter to this user's records (doc ID starts with their email)
        final myDocs = allDocs.where((d) {
          return realEmail.isNotEmpty && d.id.startsWith(realEmail);
        }).toList();

        if (myDocs.isEmpty) {
          return _emptyState('No incentive records', 'Your incentive history will appear here.');
        }

        double allTime     = 0;
        double thisMonth   = 0;
        for (final d in myDocs) {
          final total = num(d.data()['totalIncentive']);
          allTime += total;
          if (d.id.contains(_currentMonth)) thisMonth += total;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: _HeroCard(
                label: 'This Month',
                value: money.format(thisMonth),
                icon: Icons.star_rounded,
                color: _orange,
                small: true,
              )),
              const SizedBox(width: 12),
              Expanded(child: _HeroCard(
                label: 'All Time',
                value: money.format(allTime),
                icon: Icons.emoji_events_rounded,
                color: _green,
                small: true,
              )),
            ]),
            const SizedBox(height: 16),
            ...myDocs.map((d) => _IncentiveCard(
              docId: d.id,
              data: d.data(),
              money: money,
              num: num,
              fmtDate: fmtDate,
              isCurrentMonth: d.id.contains(_currentMonth),
            )),
          ],
        );
      },
    );
  }
}

class _IncentiveCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final NumberFormat money;
  final double Function(dynamic) num;
  final String Function(dynamic) fmtDate;
  final bool isCurrentMonth;

  const _IncentiveCard({
    required this.docId,
    required this.data,
    required this.money,
    required this.num,
    required this.fmtDate,
    required this.isCurrentMonth,
  });

  @override
  State<_IncentiveCard> createState() => _IncentiveCardState();
}

class _IncentiveCardState extends State<_IncentiveCard> {
  bool _expanded = false;

  String get _label {
    // doc ID format: email_Month_Year_sales  e.g. john@co.com_July_2025_sales
    final parts = widget.docId.split('_');
    if (parts.length >= 3) {
      return '${parts[parts.length - 3]} ${parts[parts.length - 2]}';
    }
    return widget.docId;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.num(widget.data['totalIncentive']);
    final rows  = (widget.data['rows'] as List?)?.cast<Map>() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isCurrentMonth ? _greenLt : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_label,
                      style: TextStyle(
                          color: widget.isCurrentMonth ? _greenDk : _orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                const Spacer(),
                Text(widget.money.format(total),
                    style: const TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: _muted),
              ]),
              if (_expanded && rows.isNotEmpty) ...[
                const Divider(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 40,
                    headingTextStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 11, color: _fg),
                    dataTextStyle: const TextStyle(fontSize: 11, color: _fg),
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Sell')),
                      DataColumn(label: Text('Cost')),
                      DataColumn(label: Text('Profit')),
                      DataColumn(label: Text('Incentive')),
                    ],
                    rows: rows.map((row) => DataRow(cells: [
                      DataCell(Text(row['productName']?.toString() ?? '')),
                      DataCell(Text(row['quantity']?.toString() ?? '')),
                      DataCell(Text(widget.num(row['sellingPrice']).toStringAsFixed(0))),
                      DataCell(Text(widget.num(row['purchaseCost']).toStringAsFixed(0))),
                      DataCell(Text(widget.num(row['netProfit']).toStringAsFixed(0))),
                      DataCell(Text('৳${widget.num(row['incentive']).toStringAsFixed(0)}')),
                    ])).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool small;

  const _HeroCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(small ? 14 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: small ? 28 : 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: small ? 11 : 13,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: small ? 18 : 24,
                      fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _DetailRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: bold ? _fg : _muted,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: color ?? _fg,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

Widget _emptyState(String title, String subtitle) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inbox_rounded, size: 64, color: _muted),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _fg)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(fontSize: 13, color: _muted),
            textAlign: TextAlign.center),
      ],
    ),
  );
}
