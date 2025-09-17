import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  /* ===== Theme ===== */
  static const Color _primary = Color(0xFF25BC5F);
  static const Color _primaryDark = Color(0xFF065F46);
  static const Color _surface = Color(0xFFF1F8F4);
  static const Color _cardBorder = Color(0x1A065F46);
  static const _shadow = BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4));

  // Filters
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Month filter like "September 2025"
  String _selectedPeriod = DateFormat('MMMM yyyy').format(DateTime.now());

  final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /* ========================= Helpers ========================= */

  double _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  String _when(dynamic ts) {
    DateTime? t;
    if (ts is Timestamp) t = ts.toDate();
    if (ts is DateTime) t = ts;
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('yMMMd').format(t);
  }

  bool _matchesSearch(Map<String, dynamic> d) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final name = (d['employeeName'] ?? '').toString().toLowerCase();
    final id = (d['employeeId'] ?? '').toString().toLowerCase();
    final dept = (d['department'] ?? '').toString().toLowerCase();
    return name.contains(q) || id.contains(q) || dept.contains(q);
  }

  double _netPay(Map<String, dynamic> d) {
    final gross = _asNum(d['grossSalary']);
    final bonus = _asNum(d['bonus']);
    final loan = _asNum(d['loanDeduction']); // generator writes loanDeduction
    return (gross + bonus - loan).clamp(0, double.infinity);
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 4, 1),
      lastDate: DateTime(now.year + 4, 12),
      helpText: 'Pick any date in the month to view',
    );
    if (picked != null) {
      setState(() => _selectedPeriod = DateFormat('MMMM yyyy').format(picked));
    }
  }

  /// Check if this employee already has a **disbursed** payroll in this period.
  Future<bool> _alreadyDisbursedForPeriod({
    required String period,
    String? employeeUid,
    String? employeeId,
  }) async {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('payrolls')
        .where('period', isEqualTo: period)
        .where('status', isEqualTo: 'disbursed')
        .limit(1);

    if (employeeUid != null && employeeUid.isNotEmpty) {
      q = q.where('employeeUid', isEqualTo: employeeUid);
    } else if (employeeId != null && employeeId.isNotEmpty) {
      q = q.where('employeeId', isEqualTo: employeeId);
    } else {
      return false;
    }

    final snap = await q.get();
    return snap.docs.isNotEmpty;
  }

  /* ========================= Actions ========================= */

  Future<void> _sendDisburseRequest(
      DocumentReference<Map<String, dynamic>> payrollRef,
      Map<String, dynamic> data,
      ) async {
    try {
      final toUid = (data['employeeUid'] ?? '').toString();
      final toEmail = (data['officeEmail'] ?? data['employeeEmail'] ?? '').toString();
      final period = (data['period'] ?? _selectedPeriod).toString();
      final amount = _netPay(data);
      final empId = (data['employeeId'] ?? '').toString();

      // one-per-month guard
      final blocked = await _alreadyDisbursedForPeriod(
        period: period,
        employeeUid: toUid.isNotEmpty ? toUid : null,
        employeeId: toUid.isEmpty ? empId : null,
      );
      if (blocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disbursement already completed for $empId in $period.')),
        );
        return;
      }

      final notifRef = await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'payslip_disbursement',
        'toUid': toUid.isEmpty ? null : toUid,
        'toEmail': toEmail.isEmpty ? null : toEmail,
        'title': 'Salary for $period',
        'body': 'Tap to acknowledge and get your salary. Net: ${_money.format(amount)}',
        'payrollId': payrollRef.id,
        'period': period,
        'amount': amount,
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await payrollRef.update({
        'status': 'requested',
        'requestId': notifRef.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disbursement request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }

  Future<void> _markDisbursed(
      DocumentReference<Map<String, dynamic>> payrollRef,
      Map<String, dynamic> data,
      ) async {
    try {
      final period = (data['period'] ?? _selectedPeriod).toString();
      final empId = (data['employeeId'] ?? '').toString();
      final toUid = (data['employeeUid'] ?? '').toString();

      final blocked = await _alreadyDisbursedForPeriod(
        period: period,
        employeeUid: toUid.isNotEmpty ? toUid : null,
        employeeId: toUid.isEmpty ? empId : null,
      );
      if (blocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disbursement already completed for $empId in $period.')),
        );
        return;
      }

      await payrollRef.update({
        'status': 'disbursed',
        'disbursedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as disbursed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark disbursed: $e')),
      );
    }
  }

  Future<void> _downloadPayslip(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final gross = _asNum(data['grossSalary']);
    final bonus = _asNum(data['bonus']);
    final loan = _asNum(data['loanDeduction']);
    final net = (gross + bonus - loan).clamp(0, double.infinity);

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Payslip', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 16),
            pw.Text('Employee: ${data['employeeName']} (${data['employeeId']})'),
            pw.Text('Department: ${data['department'] ?? ''}'),
            pw.Text('Period: ${data['period']}'),
            pw.SizedBox(height: 10),
            pw.Text('Gross Salary: ৳$gross'),
            pw.Text('Bonuses: ৳$bonus'),
            pw.Text('Loan Deduction: ৳$loan'),
            pw.Divider(),
            pw.Text('Net Pay: ৳$net', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            if (data['status'] != null) pw.SizedBox(height: 6),
            if (data['status'] != null) pw.Text('Status: ${data['status']}'),
            if ((data['rejectionNote'] ?? '').toString().isNotEmpty) pw.SizedBox(height: 6),
            if ((data['rejectionNote'] ?? '').toString().isNotEmpty)
              pw.Text('Last Rejection Note: ${data['rejectionNote']}'),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  /* ========================= UI ========================= */

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('payrolls')
        .where('period', isEqualTo: _selectedPeriod)
        .orderBy('generatedAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text('Payslips', style: TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Change period',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickPeriod,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snap.data!.docs;
          final docs = allDocs.where((d) => _matchesSearch(d.data())).toList();

          // Summary numbers
          final totalEmployees = docs.length;
          int disbursed = 0;
          for (final d in docs) {
            if ((d.data()['status'] ?? 'pending') == 'disbursed') disbursed++;
          }
          final pending = totalEmployees - disbursed;
          double totalSalary = 0;
          for (final d in docs) {
            totalSalary += _netPay(d.data());
          }

          return Column(
            children: [
              _TopFilterBar(
                period: _selectedPeriod,
                onChangePeriod: _pickPeriod,
                searchController: _searchController,
                onSearchChanged: (v) => setState(() => _searchQuery = v.trim()),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),

              _SummaryStrip(
                period: _selectedPeriod,
                totalEmployees: totalEmployees,
                totalSalary: _money.format(totalSalary),
                disbursed: disbursed,
                pending: pending,
              ),

              const SizedBox(height: 6),

              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('No matching payslips found.'))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final netPay = _netPay(data);
                    final status = (data['status'] ?? 'pending') as String;
                    final disbursedAt = data['disbursedAt'];
                    final empId = (data['employeeId'] ?? '').toString();
                    final period = (data['period'] ?? _selectedPeriod).toString();
                    final note = (data['rejectionNote'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _cardBorder),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [_shadow],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: _primary.withOpacity(.12),
                            foregroundColor: _primaryDark,
                            child: Text(
                              (data['employeeName'] ?? data['employeeId'] ?? '??')
                                  .toString()
                                  .characters
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${data['employeeName'] ?? data['employeeId']} (${data['employeeId']})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(status: status),
                            ],
                          ),
                          subtitle: Text(
                            '${_money.format(netPay)} • ${data['period']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            tooltip: 'Download PDF',
                            icon: const Icon(Icons.picture_as_pdf),
                            onPressed: () => _downloadPayslip(data),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [
                            // Compact 3-column breakdown row
                            Row(
                              children: [
                                _kvPill('GROSS', _money.format(_asNum(data['grossSalary'])), Colors.teal),
                                const SizedBox(width: 6),
                                _kvPill('BONUS', _money.format(_asNum(data['bonus'])), Colors.indigo),
                                const SizedBox(width: 6),
                                _kvPill('LOAN', _money.format(_asNum(data['loanDeduction'])), Colors.deepOrange),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (status == 'disbursed')
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Disbursed • ${_when(disbursedAt)}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              ),

                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(.06),
                                  border: Border.all(color: Colors.red.withOpacity(.2)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Last Rejection Note',
                                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(note),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),
                            FutureBuilder<bool>(
                              future: _alreadyDisbursedForPeriod(
                                period: period,
                                employeeUid: (data['employeeUid'] ?? '').toString(),
                                employeeId: (data['employeeUid'] ?? '').toString().isEmpty ? empId : null,
                              ),
                              builder: (ctx, allowSnap) {
                                final blocked = (allowSnap.data ?? false);

                                return Row(
                                  children: [
                                    if (status == 'pending' || status == 'requested') ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.send),
                                          label: Text(
                                            status == 'requested'
                                                ? 'Requested (waiting)'
                                                : 'Send Disburse Request',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: (status == 'requested' || blocked)
                                              ? null
                                              : () => _sendDisburseRequest(doc.reference, data),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.verified),
                                          label: const Text('Mark Disbursed'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryDark,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed:
                                          blocked ? null : () => _markDisbursed(doc.reference, data),
                                        ),
                                      ),
                                    ],
                                    if (status == 'disbursed')
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.verified_user),
                                          label: const Text('Disbursed'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey.shade400,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: null,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),

                            if (note.isNotEmpty && status == 'pending') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Send Again'),
                                      onPressed: () => _sendDisburseRequest(doc.reference, data),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _primaryDark,
                                        side: BorderSide(color: _primaryDark.withOpacity(.4)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _kvPill(String k, String v, Color c) {
    final fg = _darken(c);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: c.withOpacity(.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(.2)),
        ),
        child: Column(
          children: [
            Text(v, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 2),
            Text(k, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Color _darken(Color base) {
    final h = HSLColor.fromColor(base);
    return h.withLightness((h.lightness - 0.25).clamp(0.0, 1.0)).toColor();
  }
}

/* ========================= Top Filter Bar ========================= */

class _TopFilterBar extends StatelessWidget {
  final String period;
  final VoidCallback onChangePeriod;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  const _TopFilterBar({
    required this.period,
    required this.onChangePeriod,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClear,
  });

  static const Color _primary = _PayslipScreenState._primary;
  static const Color _cardBorder = _PayslipScreenState._cardBorder;
  static const _shadow = _PayslipScreenState._shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [_shadow],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Period: $period', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change'),
                style: TextButton.styleFrom(foregroundColor: _primary),
                onPressed: onChangePeriod,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search by name / ID / department',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: (searchController.text.isEmpty)
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
            ),
            onChanged: onSearchChanged,
          ),
        ],
      ),
    );
  }
}

/* ========================= UI bits ========================= */

class _SummaryStrip extends StatelessWidget {
  final String period;
  final int totalEmployees;
  final String totalSalary;
  final int disbursed;
  final int pending;

  const _SummaryStrip({
    required this.period,
    required this.totalEmployees,
    required this.totalSalary,
    required this.disbursed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, {required Color color}) {
      final fg = _darken(color);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(.07),
            border: Border.all(color: color.withOpacity(.18)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary • $period', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              tile('Employees', '$totalEmployees', color: Colors.teal),
              tile('Total Salary', totalSalary, color: Colors.green),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              tile('Disbursed', '$disbursed', color: Colors.indigo),
              tile('Pending', '$pending', color: Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }

  Color _darken(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0)).toColor();
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _fgFrom(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    late Color c;
    late String t;

    switch (status) {
      case 'requested':
        c = Colors.orange;
        t = 'Requested';
        break;
      case 'disbursed':
        c = Colors.green;
        t = 'Disbursed';
        break;
      default:
        c = Colors.grey;
        t = 'Pending';
    }

    final fg = _fgFrom(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(t, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
